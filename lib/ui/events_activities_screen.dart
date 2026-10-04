import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_feed_session_cache.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:parentpeak/ui/event_detail_page.dart';
import 'package:parentpeak/ui/event_invitations_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/ui/widgets/native_ad_slot.dart';
import 'package:parentpeak/ui/widgets/event_host_identity.dart';
import 'package:parentpeak/services/events_limit_service.dart';
import 'package:parentpeak/ui/widgets/premium_gate.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/main.dart';

class EventsActivitiesScreen extends StatefulWidget {
  final EventDiscoveryAgent? agent;
  final EventService? eventService;
  final PickedLocation? initialLocation;
  final Future<PickedLocation?> Function()? locationLoader;
  final String? Function()? viewerUserId;
  final EventGeocoder? geocoder;

  const EventsActivitiesScreen({
    super.key,
    this.agent,
    this.eventService,
    this.initialLocation,
    this.locationLoader,
    this.viewerUserId,
    this.geocoder,
  });

  @override
  State<EventsActivitiesScreen> createState() => _EventsActivitiesScreenState();
}

enum _FeedSource { ai, community }

enum _TimeWindowFilter { all, today, weekend }

class _FeedSession {
  final ai = EventFeedSessionCache<List<DiscoveredEvent>>(
    ttl: const Duration(minutes: 10),
  );
  final community = EventFeedSessionCache<List<MeetupEvent>>(
    ttl: const Duration(minutes: 1),
  );
  final invitations = EventFeedSessionCache<List<EventInvitation>>(
    ttl: const Duration(minutes: 1),
  );
  final locations = <String, (PickedLocation, bool)>{};
}

class _EventsActivitiesScreenState extends State<EventsActivitiesScreen> {
  static final _defaultEventService = EventService();
  static final _sessions = Expando<Expando<_FeedSession>>();
  late final EventDiscoveryAgent _agent;
  late final EventService _eventService;
  late final _FeedSession _session;
  int _requestGeneration = 0;
  String? _displayedQuery;
  String? _pendingQuery;
  Future<void>? _pendingRefresh;
  String? _feedUserId;

  String? get _viewerUserId => widget.viewerUserId != null
      ? widget.viewerUserId!()
      : AuthService.instance.currentUser?.uid;

  // Single source of truth for location.
  // null = no location selected yet (bar shows "Standort wählen").
  PickedLocation? _activeLocation;
  // Fallback city for search when no active location (from saved prefs).
  String _fallbackCity = '';
  // True once the user explicitly picked a location — GPS won't auto-override.
  bool _userLockedLocation = false;
  // True once we have a real location (from GPS or manual pick) — not just the Berlin default.
  bool _hasRealLocation = false;

  bool _isLoading = true;
  String? _errorMessage;
  // true, wenn der letzte KI-Discovery-Call fehlschlug (z.B. 401 ohne gültigen
  // Firebase-Token, Timeout oder unparsebare Gemini-Antwort). Steuert einen
  // dezenten, retry-baren Hinweis statt stummer Leere.
  bool _aiFeedFailed = false;
  // true, solange die (langsame) KI-Suche noch läuft. Unabhängig vom globalen
  // _isLoading, damit Community-Angebote sofort erscheinen und die KI-Treffer
  // progressiv nachladen — statt alle hinter einem Spinner zu blockieren.
  bool _aiLoading = false;
  DateTime? _lastFeedSyncAt;
  List<DiscoveredEvent> _aiEvents = const [];
  List<MeetupEvent> _communityEvents = const [];
  List<EventInvitation> _invitations = const [];
  Map<String, String> _eventTitlesById = const {};
  final Set<String> _updatingInvitationIds = {};
  final Set<AgeGroup> _selectedAgeGroups = {};
  final Set<_FeedSource> _activeSources = {
    _FeedSource.ai,
    _FeedSource.community,
  };
  int _radiusKm = 20;
  bool _onlyFree = false;
  bool _onlyNearbyQuick = false;
  _TimeWindowFilter _timeWindowFilter = _TimeWindowFilter.all;

  bool _gpsDetecting = false;

  static const String _savedCityKey = 'events.saved_city';

  @override
  void initState() {
    super.initState();
    _agent = widget.agent ?? EventDiscoveryAgent.instance;
    _eventService = widget.eventService ?? _defaultEventService;
    final services = _sessions[_agent] ??= Expando<_FeedSession>();
    _session = services[_eventService] ??= _FeedSession();
    _feedUserId = _viewerUserId;
    final remembered = _session.locations[_viewerUserId ?? 'guest'];
    _activeLocation = widget.initialLocation ?? remembered?.$1;
    _userLockedLocation =
        widget.initialLocation == null && (remembered?.$2 ?? false);
    if (_activeLocation != null) {
      _hasRealLocation = true;
      _fallbackCity = _activeLocation!.city;
    }
    if (widget.viewerUserId == null) {
      AuthService.instance.addListener(_onAccountChanged);
    }
    languageService.addListener(_onLanguageChanged);
    _loadSavedCityThenDetect();
  }

  void _onAccountChanged() {
    if (!mounted || _feedUserId == _viewerUserId) return;
    _feedUserId = _viewerUserId;
    _displayedQuery = null;
    _pendingQuery = null;
    _requestGeneration++;
    setState(() {
      _aiEvents = const [];
      _communityEvents = const [];
      _invitations = const [];
      _eventTitlesById = const {};
      _lastFeedSyncAt = null;
      _aiFeedFailed = false;
    });
    if (_hasRealLocation) _refreshFeed();
  }

  void _onLanguageChanged() {
    if (mounted && _hasRealLocation) _refreshFeed();
  }

  Future<void> _loadSavedCityThenDetect() async {
    if (_hasRealLocation) {
      _refreshFeed();
      _detectGpsAndRefresh();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getString(_savedCityKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _fallbackCity = saved;
        _hasRealLocation = true; // saved city = previously confirmed location
      });
      _refreshFeed();
      final coords = await (widget.geocoder ?? EventGeocoder.instance).resolve(
        saved,
      );
      if (!mounted) return;
      if (_activeLocation == null && _fallbackCity == saved && coords != null) {
        setState(
          () => _activeLocation = PickedLocation(
            displayName: saved,
            city: saved,
            postcode: '',
            lat: coords.$1,
            lon: coords.$2,
          ),
        );
        _refreshFeed();
      }
    }
    _detectGpsAndRefresh();
  }

  // Search city: active location takes priority, saved city is the fallback.
  String get _searchCity => _activeLocation?.city.isNotEmpty == true
      ? _activeLocation!.city
      : _fallbackCity;

  @override
  void dispose() {
    _requestGeneration++;
    if (widget.viewerUserId == null) {
      AuthService.instance.removeListener(_onAccountChanged);
    }
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  // ─── GPS Standort-Erkennung ───────────────────────────────────────────────

  /// [forceOverride] true wenn Nutzer den GPS-Button manuell drueckt —
  /// dann wird die Stadt immer aktualisiert und gespeichert.
  Future<void> _detectGpsAndRefresh({bool forceOverride = false}) async {
    if (!mounted || _gpsDetecting) return;
    setState(() => _gpsDetecting = true);
    var startingLocation = _activeLocation;
    if (widget.locationLoader != null) {
      try {
        final location = await widget.locationLoader!();
        if (!mounted) return;
        if (location != null &&
            (forceOverride || !_userLockedLocation) &&
            identical(startingLocation, _activeLocation)) {
          setState(() {
            _activeLocation = location;
            _fallbackCity = location.city;
            _hasRealLocation = true;
          });
          _refreshFeed();
        }
      } finally {
        if (mounted) setState(() => _gpsDetecting = false);
      }
      if (mounted) _refreshFeed();
      return;
    }

    // First: use central LocationService if it already has a location (e.g. from onboarding)
    if (!forceOverride &&
        LocationService.instance.hasLocation &&
        !_hasRealLocation) {
      final loc = LocationService.instance;
      final newLocation = PickedLocation(
        displayName: loc.city ?? context.tr('events_my_location'),
        city: loc.city ?? '',
        postcode: '',
        lat: loc.latitude!,
        lon: loc.longitude!,
      );
      if (mounted) {
        setState(() {
          _activeLocation = newLocation;
          _hasRealLocation = true;
          _fallbackCity = loc.city ?? '';
          _gpsDetecting = false;
        });
      }
      _refreshFeed();
      // Still try GPS silently to get a fresher position
      startingLocation = _activeLocation;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        // Fallback: use central LocationService if available
        if (LocationService.instance.hasLocation &&
            !_hasRealLocation &&
            !_userLockedLocation) {
          final loc = LocationService.instance;
          final newLocation = PickedLocation(
            displayName: loc.city ?? context.tr('events_my_location'),
            city: loc.city ?? '',
            postcode: '',
            lat: loc.latitude!,
            lon: loc.longitude!,
          );
          if (mounted) {
            setState(() {
              _activeLocation = newLocation;
              _gpsDetecting = false;
            });
          }
          _refreshFeed();
          return;
        }
        if (mounted) {
          setState(() => _gpsDetecting = false);
          if (!_hasRealLocation) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'events_gps_unavailable',
                  ),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        _refreshFeed();
        return;
      }
      // Web needs more time: browser uses WiFi/IP geolocation
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: kIsWeb ? Duration(seconds: 20) : Duration(seconds: 6),
        ),
      );
      final district = await _reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      // When Nominatim fails, use coordinates as search city so Gemini can locate events
      final coordCity =
          '${pos.latitude.toStringAsFixed(4)},${pos.longitude.toStringAsFixed(4)}';
      final cityLabel = district ?? context.tr('events_current_location');
      final city = district != null
          ? (district.contains(',')
                ? district.split(',').last.trim()
                : district)
          : coordCity; // pass raw coords to agent when city name unknown
      final newLocation = PickedLocation(
        displayName: cityLabel,
        city: city,
        postcode: '',
        lat: pos.latitude,
        lon: pos.longitude,
      );
      if (mounted) {
        final shouldUpdate =
            (forceOverride || !_userLockedLocation) &&
            identical(startingLocation, _activeLocation);
        if (shouldUpdate) {
          final prefs = await SharedPreferences.getInstance();
          if (district != null) await prefs.setString(_savedCityKey, district);
        }
        if (!mounted) return;
        setState(() {
          if (shouldUpdate &&
              (forceOverride || !_userLockedLocation) &&
              identical(startingLocation, _activeLocation)) {
            _activeLocation = newLocation;
            _hasRealLocation = true;
            _fallbackCity = city;
            _userLockedLocation = false;
          }
          _gpsDetecting = false;
        });
      }
    } catch (e) {
      debugPrint('EventsActivitiesScreen: GPS fehlgeschlagen: $e');
      if (mounted) setState(() => _gpsDetecting = false);
    }
    _refreshFeed();
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );
      // User-Agent is a forbidden header in browser Fetch API — skip on web
      final headers = kIsWeb
          ? <String, String>{}
          : {'User-Agent': 'ParentPeak/1.0 (family app)'};
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final suburb =
            address?['suburb'] as String? ??
            address?['quarter'] as String? ??
            address?['neighbourhood'] as String?;
        final cityName =
            address?['city'] as String? ??
            address?['town'] as String? ??
            address?['village'] as String?;
        if (suburb != null && cityName != null) return '$suburb, $cityName';
        if (cityName != null) return cityName;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _refreshFeed({
    bool force = false,
    bool communityChanged = false,
    bool invitationsOnly = false,
  }) {
    if (!mounted) return Future.value();
    final city = _searchCity;
    final viewerUserId = _viewerUserId;
    final coords = _originCoords;
    final ages = _selectedAgeGroups.toList()
      ..sort((first, second) => first.index.compareTo(second.index));
    final radius = _radiusKm;
    final onlyFree = _onlyFree;
    final nearbyOnly = _onlyNearbyQuick;
    final timeWindow = _timeWindowFilter.name;
    final aiKey = jsonEncode([
      viewerUserId,
      languageService.currentLanguage,
      city.trim().toLowerCase(),
      coords.$1.toStringAsFixed(4),
      coords.$2.toStringAsFixed(4),
      radius,
      ages.map((age) => age.name).toList(),
    ]);
    final key = jsonEncode([aiKey, onlyFree, nearbyOnly, timeWindow]);
    if (communityChanged) {
      _session.community.clear();
      _session.invitations.clear();
    }
    if (!force &&
        !communityChanged &&
        !invitationsOnly &&
        _pendingQuery == key &&
        _pendingRefresh != null) {
      return _pendingRefresh!;
    }
    if (_activeLocation != null) {
      _session.locations[viewerUserId ?? 'guest'] = (
        _activeLocation!,
        _userLockedLocation,
      );
      if (_session.locations.length > 32) {
        _session.locations.remove(_session.locations.keys.first);
      }
    }
    final generation = ++_requestGeneration;
    bool isCurrent() =>
        mounted &&
        generation == _requestGeneration &&
        viewerUserId == _viewerUserId;
    final sameQuery = _displayedQuery == key;
    final aiCached = _session.ai.peek(aiKey);
    final communityCached = _session.community.peek(key);
    final invitationCached = _session.invitations.peek(key);
    setState(() {
      _displayedQuery = key;
      _aiEvents = aiCached?.data ?? (sameQuery ? _aiEvents : const []);
      _communityEvents =
          communityCached?.data ??
          (sameQuery && !communityChanged ? _communityEvents : const []);
      _invitations =
          invitationCached?.data ??
          (sameQuery && !communityChanged ? _invitations : const []);
      if (!sameQuery || communityChanged) _eventTitlesById = const {};
      if (!sameQuery || communityChanged) _lastFeedSyncAt = null;
      _isLoading = true;
      _aiLoading = _activeSources.contains(_FeedSource.ai) &&
          city.trim().isNotEmpty &&
          !invitationsOnly;
      _errorMessage = null;
    });
    final ageLabels = ages.map(_ageGroupLabel).toList();
    Future<void> loadAi() async {
      if (city.trim().isEmpty) {
        if (isCurrent() && _aiLoading) setState(() => _aiLoading = false);
        return;
      }
      try {
        final pendingAi = _session.ai.pending(aiKey);
        if ((communityChanged || invitationsOnly) && pendingAi == null) {
          // Reiner Community-/Einladungs-Refresh: KI wird nicht neu geladen.
          if (isCurrent() && _aiLoading) setState(() => _aiLoading = false);
          return;
        }
        final request = communityChanged || invitationsOnly
            ? pendingAi!
            : _session.ai.load(
                aiKey,
                () => _agent.discoverEvents(
                  city: city,
                  radiusHint: '$radius km Umkreis',
                  childAges: ageLabels,
                  latitude: validCoordinates(coords.$1, coords.$2)
                      ? coords.$1
                      : null,
                  longitude: validCoordinates(coords.$1, coords.$2)
                      ? coords.$2
                      : null,
                ),
                force: force,
              );
        final value = await request;
        if (isCurrent()) {
          setState(() {
            _aiEvents = value.data;
            _aiFeedFailed = false;
          });
        }
      } catch (e) {
        debugPrint('EventsActivitiesScreen: AI feed unavailable: $e');
        if (isCurrent()) setState(() => _aiFeedFailed = true);
      } finally {
        // In JEDEM Fall den KI-Ladezustand beenden — sonst bliebe der
        // animierte Hinweis-Spinner stehen (und ließe pumpAndSettle hängen).
        if (isCurrent() && _aiLoading) setState(() => _aiLoading = false);
      }
    }

    Future<void> loadCommunity() async {
      if (invitationsOnly) return;
      try {
        final value = await _session.community.load(
          key,
          () => _loadCommunityEventsForCity(
            coords,
            viewerUserId,
            radius,
            ages,
            onlyFree: onlyFree,
            nearbyOnly: nearbyOnly,
            timeWindow: timeWindow,
          ),
          force: force || communityChanged,
        );
        if (isCurrent()) {
          setState(() {
            _communityEvents = value.data;
            _eventTitlesById = {
              ..._eventTitlesById,
              for (final event in value.data) event.id: event.title,
            };
          });
        }
      } catch (e) {
        debugPrint('EventsActivitiesScreen: community feed unavailable: $e');
      }
    }

    Future<void> loadInvitations() async {
      try {
        final value = await _session.invitations.load(
          key,
          () => _eventService.getInvitationsForUser(viewerUserId ?? 'guest'),
          force: force || communityChanged || invitationsOnly,
        );
        if (!isCurrent()) return;
        setState(() => _invitations = value.data);
        await Future.wait(
          value.data
              .map((invitation) => invitation.eventId)
              .where((id) => id.isNotEmpty && !_eventTitlesById.containsKey(id))
              .toSet()
              .map((eventId) async {
                try {
                  final event = await _eventService.getEventById(eventId);
                  if (event != null && isCurrent()) {
                    setState(
                      () => _eventTitlesById = {
                        ..._eventTitlesById,
                        eventId: event.title,
                      },
                    );
                  }
                } catch (e) {
                  debugPrint(
                    'EventsActivitiesScreen: invitation title unavailable: $e',
                  );
                }
              }),
        );
      } catch (e) {
        debugPrint('EventsActivitiesScreen: invitations load skipped: $e');
      }
    }

    _pendingQuery = key;
    final aiFuture = loadAi();

    // Globalen Spinner nur an die SCHNELLEN Quellen (Community + Einladungen)
    // koppeln, damit diese sofort erscheinen. Die langsame KI-Suche läuft
    // parallel weiter; ihre Treffer poppen progressiv nach (eigener
    // _aiLoading-Hinweis), statt alles hinter dem Spinner zu blockieren.
    final fastSources = Future.wait([loadCommunity(), loadInvitations()])
        .then((_) {
      if (!isCurrent()) return;
      final community = _session.community.peek(key);
      setState(() {
        _isLoading = false;
        _lastFeedSyncAt = community?.loadedAt;
      });
    });

    final pending = Future.wait([aiFuture, fastSources]).then((_) {
      if (!isCurrent()) return;
      final ai = _session.ai.peek(aiKey);
      final community = _session.community.peek(key);
      setState(() {
        _lastFeedSyncAt = ai != null && community != null
            ? (ai.loadedAt.isBefore(community.loadedAt)
                ? ai.loadedAt
                : community.loadedAt)
            : (community?.loadedAt ?? ai?.loadedAt);
      });
      _pendingQuery = null;
      _pendingRefresh = null;
    });
    _pendingRefresh = pending;
    return pending;
  }

  String _formatLastSyncLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  Future<List<MeetupEvent>> _loadCommunityEventsForCity(
    (double, double) coords,
    String? viewerUserId,
    int radius,
    List<AgeGroup> ages, {
    required bool onlyFree,
    required bool nearbyOnly,
    required String timeWindow,
  }) async {
    return _eventService.getFilteredDiscoverableEventsForUser(
      viewerUserId: viewerUserId ?? 'guest',
      viewerLatitude: coords.$1,
      viewerLongitude: coords.$2,
      ageGroups: ages.isEmpty ? null : ages,
      radiusKm: radius.toDouble(),
      onlyFree: onlyFree,
      nearbyOnly: nearbyOnly,
      timeWindow: timeWindow,
    );
  }

  (double, double) get _originCoords {
    final loc = _activeLocation;
    if (loc != null && validCoordinates(loc.lat, loc.lon)) {
      return (loc.lat, loc.lon);
    }
    return (double.nan, double.nan);
  }

  List<_UnifiedFeedItem> get _combinedFeed {
    final coords = _originCoords;
    final items = <_UnifiedFeedItem>[];

    if (_activeSources.contains(_FeedSource.ai)) {
      items.addAll(_aiEvents.map(_UnifiedFeedItem.fromAi));
    }
    if (_activeSources.contains(_FeedSource.community)) {
      items.addAll(_communityEvents.map(_UnifiedFeedItem.fromCommunity));
    }

    final filtered = items
        .where((item) => _withinRadius(item, coords.$1, coords.$2, _radiusKm))
        .where((item) => _matchesNearbyQuickFilter(item, coords.$1, coords.$2))
        .where((item) => _matchesSelectedAges(item))
        .where(_matchesPriceFilter)
        .where(_matchesTimeWindow)
        .toList();

    final now = DateTime.now();
    filtered.sort((a, b) {
      final aScore = _rankingScore(a, coords.$1, coords.$2, now);
      final bScore = _rankingScore(b, coords.$1, coords.$2, now);
      final comparison = bScore.compareTo(aScore);
      return comparison != 0
          ? comparison
          : (a.eventId ?? a.title).compareTo(b.eventId ?? b.title);
    });

    return filtered;
  }

  int get _nearbyQuickCount {
    final coords = _originCoords;

    final items = <_UnifiedFeedItem>[];
    if (_activeSources.contains(_FeedSource.ai)) {
      items.addAll(_aiEvents.map(_UnifiedFeedItem.fromAi));
    }
    if (_activeSources.contains(_FeedSource.community)) {
      items.addAll(_communityEvents.map(_UnifiedFeedItem.fromCommunity));
    }

    return items
        .where((item) => _withinRadius(item, coords.$1, coords.$2, _radiusKm))
        .where((item) => _matchesSelectedAges(item))
        .where(_matchesPriceFilter)
        .where(_matchesTimeWindow)
        .where((item) {
          final distance = _distanceKmForDisplay(item, coords.$1, coords.$2);
          return distance != null && distance <= 10;
        })
        .length;
  }

  bool _matchesPriceFilter(_UnifiedFeedItem item) {
    if (!_onlyFree) return true;
    return item.isFree;
  }

  bool _matchesTimeWindow(_UnifiedFeedItem item) {
    return eventMatchesTime(
      item.eventDate,
      _timeWindowFilter.name,
      DateTime.now(),
    );
  }

  bool _withinRadius(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
    int radiusKm,
  ) {
    final distance = _distanceKmForDisplay(item, originLat, originLon);
    return distance == null || distance <= radiusKm;
  }

  bool _matchesNearbyQuickFilter(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
  ) {
    if (!_onlyNearbyQuick) return true;
    final distance = _distanceKmForDisplay(item, originLat, originLon);
    return distance != null && distance <= 10;
  }

  bool _matchesSelectedAges(_UnifiedFeedItem item) {
    return eventMatchesAges(_itemAges(item), _selectedAgeGroups);
  }

  List<AgeGroup> _itemAges(_UnifiedFeedItem item) =>
      item.source == _FeedSource.community
      ? item.communityAgeGroups
      : eventAgesFromLabel(item.ageLabel ?? '');

  double _rankingScore(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
    DateTime now,
  ) {
    return eventRankingScore(
      distance: _distanceKmForDisplay(item, originLat, originLon),
      date: item.eventDate,
      ages: _itemAges(item),
      selected: _selectedAgeGroups,
      now: now,
    );
  }

  double? _distanceKmForDisplay(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
  ) {
    return eventDistanceKm(originLat, originLon, item.latitude, item.longitude);
  }

  String _ageGroupLabel(AgeGroup ageGroup) {
    return context.tr(_ageGroupKey(ageGroup));
  }

  // ─── Feed mit Ads ──────────────────────────────────────────────────────────

  List<Widget> _buildFeedWithAds(
    List<_UnifiedFeedItem> feed,
    (double, double) coords,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < feed.length; i++) {
      // Ad-Slot einfügen (1 pro 5 Items, ab Position 3)
      if (NativeAdSlot.shouldInsertAt(i)) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: NativeAdSlot(contextHint: 'events'),
          ),
        );
      }

      final item = feed[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _UnifiedEventCard(
            item: item,
            distanceKm: _distanceKmForDisplay(item, coords.$1, coords.$2),
            onTap: () {
              if (item.source == _FeedSource.community &&
                  item.eventId != null) {
                final event = _findCommunityEventById(item.eventId!);
                if (event == null) {
                  _showAiDetails(item);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(
                      event: event,
                      eventService: _eventService,
                    ),
                  ),
                ).then((_) {
                  if (mounted) _refreshFeed(communityChanged: true);
                });
                return;
              }
              _showAiDetails(item);
            },
          ),
        ),
      );
    }
    return widgets;
  }

  MeetupEvent? _findCommunityEventById(String id) {
    for (final event in _communityEvents) {
      if (event.id == id) return event;
    }
    return null;
  }

  int get _pendingInvitationsCount {
    return _invitations
        .where((inv) => inv.status == EventInvitationStatus.pending)
        .length;
  }

  List<EventInvitation> get _sortedInvitations {
    final sorted = List<EventInvitation>.from(_invitations);
    sorted.sort((a, b) {
      final rankCompare = _statusRank(
        a.status,
      ).compareTo(_statusRank(b.status));
      if (rankCompare != 0) return rankCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int _statusRank(EventInvitationStatus status) {
    switch (status) {
      case EventInvitationStatus.pending:
        return 0;
      case EventInvitationStatus.accepted:
        return 1;
      case EventInvitationStatus.declined:
        return 2;
    }
  }

  String _invitationStatusLabel(EventInvitationStatus status) {
    switch (status) {
      case EventInvitationStatus.pending:
        return context.tr('events_invitation_pending');
      case EventInvitationStatus.accepted:
        return context.tr('events_invitation_accepted');
      case EventInvitationStatus.declined:
        return context.tr('events_invitation_declined');
    }
  }

  Color _invitationStatusColor(EventInvitationStatus status) {
    switch (status) {
      case EventInvitationStatus.pending:
        return const Color(0xFFB45309);
      case EventInvitationStatus.accepted:
        return const Color(0xFF15803D);
      case EventInvitationStatus.declined:
        return const Color(0xFFB91C1C);
    }
  }

  String _eventTitleForInvitation(EventInvitation invitation) {
    return _eventTitlesById[invitation.eventId] ??
        context.tr(
          'events_invitation_fallback_title',
          values: {
            'id': invitation.eventId.isEmpty
                ? context.tr('events_without_id')
                : invitation.eventId,
          },
        );
  }

  String _formatShortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String _hostLabel(String hostUserId) {
    if (hostUserId.trim().isEmpty) return 'H';
    final cleaned = hostUserId.trim();
    if (cleaned.length == 1) return cleaned.toUpperCase();
    return cleaned.substring(0, 2).toUpperCase();
  }

  Color _hostColor(String hostUserId) {
    final palette = <Color>[
      const Color(0xFF0284C7),
      const Color(0xFF7C3AED),
      const Color(0xFF0F766E),
      const Color(0xFFC2410C),
      const Color(0xFFBE185D),
    ];
    final index = hostUserId.hashCode.abs() % palette.length;
    return palette[index];
  }

  Future<void> _respondInvitation(
    EventInvitation invitation,
    bool accept,
  ) async {
    setState(() => _updatingInvitationIds.add(invitation.id));

    try {
      await _eventService.respondToInvitation(
        invitationId: invitation.id,
        accept: accept,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              accept
                  ? 'events_invitation_accept_success'
                  : 'events_invitation_decline_success',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      await _refreshFeed(invitationsOnly: true);
    } catch (e) {
      debugPrint('EventsActivitiesScreen._respondInvitation(): failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'action_save_error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingInvitationIds.remove(invitation.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = _combinedFeed;
    final coords = _originCoords; // GPS/picked coords, not city-name lookup
    final showInvitationsSection = _invitations.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStringsManager.getString(
            languageService.currentLanguage,
            'events_activities_title',
          ),
        ),
        actions: [
          IconButton(
            key: const Key('event-feed-refresh'),
            tooltip: context.tr('reload_btn'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _refreshFeed(force: true),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF7F6), Color(0xFFF3F7FC), Color(0xFFFCF8EF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Sticky: Location + Quellfilter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _buildLocationSearch(theme),
                  const SizedBox(height: 10),
                  _buildSourceFilters(theme),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildHeaderCard(theme),
                  const SizedBox(height: 10),
                  _buildPinnedActionBar(theme),
                  if (showInvitationsSection) ...[
                    const SizedBox(height: 10),
                    _buildInvitationsSection(theme),
                  ],
                  const SizedBox(height: 10),
                  _buildAdvancedFilters(theme),
                  const SizedBox(height: 14),
                  if (_lastFeedSyncAt != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFB8DAF6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.update_rounded,
                            size: 18,
                            color: Color(0xFF155E75),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr(
                                'events_last_sync',
                                values: {
                                  'time': _formatLastSyncLabel(
                                    _lastFeedSyncAt!,
                                  ),
                                },
                              ),
                              key: const Key('event-feed-last-sync'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF155E75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    context.tr('events_nearby_for_you'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dezenter Hinweis, wenn die KI-Suche fehlschlug (z.B. keine
                  // gültige Sitzung) — statt stummer Leere. Nur wenn die
                  // KI-Quelle aktiv ist und gerade nicht geladen wird.
                  if (!_isLoading &&
                      _errorMessage == null &&
                      _aiFeedFailed &&
                      _activeSources.contains(_FeedSource.ai)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_outlined,
                              size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStringsManager.getString(
                                languageService.currentLanguage,
                                'events_ai_unavailable',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _refreshFeed(force: true),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              AppStringsManager.getString(
                                languageService.currentLanguage,
                                'retry_btn',
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_aiLoading &&
                      _activeSources.contains(_FeedSource.ai)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppStringsManager.getString(
                                languageService.currentLanguage,
                                'events_ai_searching',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF5B21B6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_isLoading && feed.isNotEmpty)
                    const LinearProgressIndicator(),
                  if (_isLoading && feed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD1C3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF8C3E28),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => _refreshFeed(force: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              AppStringsManager.getString(
                                languageService.currentLanguage,
                                'reload_btn',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (feed.isEmpty && !_aiLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '\u{1F50D}',
                            style: TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppStringsManager.getString(
                              languageService.currentLanguage,
                              'events_empty_title',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStringsManager.getString(
                              languageService.currentLanguage,
                              'events_empty_subtitle',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _refreshFeed(force: true),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              AppStringsManager.getString(
                                languageService.currentLanguage,
                                'reload_btn',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._buildFeedWithAds(feed, coords),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedActionBar(ThemeData theme) {
    final isCompact = MediaQuery.sizeOf(context).width < 390;

    return Container(
      color: const Color(0xFFEFF3F8),
      padding: EdgeInsets.fromLTRB(
        16,
        isCompact ? 6 : 8,
        16,
        isCompact ? 6 : 8,
      ),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
          border: Border.all(color: const Color(0xFFCAD9EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1E3A5F),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: _buildTopActionBar(compact: isCompact),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('events_family_spot_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('events_family_spot_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionBar({bool compact = false}) {
    return Row(
      children: [
        Expanded(
          child: _CompactActionButton(
            icon: Icons.campaign_rounded,
            label: context.tr('events_plan_event'),
            color: const Color(0xFFEA580C),
            compact: compact,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateEventScreen()),
              ).then((_) => _refreshFeed(communityChanged: true));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompactActionButton(
            icon: Icons.mark_email_unread_rounded,
            label: context.tr('events_invitations'),
            color: const Color(0xFF4F46E5),
            compact: compact,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EventInvitationsScreen(),
                ),
              ).then((_) => _refreshFeed(invitationsOnly: true));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSearch(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: LocationPickerWidget(
            hint: context.tr('events_choose_location'),
            initialLocation: _activeLocation,
            onLocationPicked: (loc) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                _savedCityKey,
                loc.city.isNotEmpty ? loc.city : loc.displayName,
              );
              if (!mounted) return;
              setState(() {
                _activeLocation = loc;
                _fallbackCity = loc.city.isNotEmpty
                    ? loc.city
                    : loc.displayName;
                _userLockedLocation = true;
                _hasRealLocation = true;
              });
              _refreshFeed();
            },
          ),
        ),
        const SizedBox(width: 8),
        // GPS-Detect Button
        Tooltip(
          message: _activeLocation != null
              ? context.tr('events_gps_active')
              : context.tr('events_detect_location'),
          child: InkWell(
            onTap: _gpsDetecting
                ? null
                : () => _detectGpsAndRefresh(forceOverride: true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _activeLocation != null
                    ? const Color(0xFF0EA5A4).withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _activeLocation != null
                      ? const Color(0xFF0EA5A4)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: _gpsDetecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _activeLocation != null
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      size: 18,
                      color: _activeLocation != null
                          ? const Color(0xFF0EA5A4)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceFilters(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'ki_finds',
            ),
          ),
          selected: _activeSources.contains(_FeedSource.ai),
          onSelected: (value) {
            setState(() {
              if (value) {
                _activeSources.add(_FeedSource.ai);
              } else {
                _activeSources.remove(_FeedSource.ai);
              }
            });
          },
        ),
        FilterChip(
          label: Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'community_offers',
            ),
          ),
          selected: _activeSources.contains(_FeedSource.community),
          onSelected: (value) {
            setState(() {
              if (value) {
                _activeSources.add(_FeedSource.community);
              } else {
                _activeSources.remove(_FeedSource.community);
              }
            });
          },
        ),
        FilterChip(
          label: Text(
            context.tr(
              'events_nearby_only',
              values: {'count': '$_nearbyQuickCount'},
            ),
          ),
          selected: _onlyNearbyQuick,
          onSelected: (value) {
            setState(() => _onlyNearbyQuick = value);
            _refreshFeed();
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters(ThemeData theme) {
    const radiusOptions = [5, 10, 20, 50];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('events_filter_title'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: radiusOptions
                .map(
                  (radius) => ChoiceChip(
                    label: Text('$radius km'),
                    selected: _radiusKm == radius,
                    onSelected: (_) {
                      if (_radiusKm == radius) return;
                      setState(() => _radiusKm = radius);
                      _refreshFeed();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AgeGroup.values
                .map(
                  (group) => FilterChip(
                    key: ValueKey('event-feed-age-${group.name}'),
                    label: Text(_ageGroupLabel(group)),
                    selected: _selectedAgeGroups.contains(group),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedAgeGroups.add(group);
                        } else {
                          _selectedAgeGroups.remove(group);
                        }
                      });
                      _refreshFeed();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const ValueKey('event-feed-only-free'),
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'only_free',
                  ),
                ),
                selected: _onlyFree,
                onSelected: (value) {
                  setState(() => _onlyFree = value);
                  _refreshFeed();
                },
              ),
              ChoiceChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'all_dates',
                  ),
                ),
                selected: _timeWindowFilter == _TimeWindowFilter.all,
                onSelected: (_) {
                  setState(() => _timeWindowFilter = _TimeWindowFilter.all);
                  _refreshFeed();
                },
              ),
              ChoiceChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'today_label',
                  ),
                ),
                selected: _timeWindowFilter == _TimeWindowFilter.today,
                onSelected: (_) {
                  setState(() => _timeWindowFilter = _TimeWindowFilter.today);
                  _refreshFeed();
                },
              ),
              ChoiceChip(
                label: Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'this_weekend',
                  ),
                ),
                selected: _timeWindowFilter == _TimeWindowFilter.weekend,
                onSelected: (_) {
                  setState(() => _timeWindowFilter = _TimeWindowFilter.weekend);
                  _refreshFeed();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('events_sort_explanation'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsSection(ThemeData theme) {
    final visibleInvitations = _sortedInvitations.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('events_invitations'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr(
                    'events_open_count',
                    values: {'count': '$_pendingInvitationsCount'},
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_invitations.isEmpty)
            Text(
              context.tr('events_no_open_invitations'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...visibleInvitations.map((invitation) {
              final statusColor = _invitationStatusColor(invitation.status);
              final isBusy = _updatingInvitationIds.contains(invitation.id);
              final hostColor = _hostColor(invitation.hostUserId);
              final pending =
                  invitation.status == EventInvitationStatus.pending;

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: hostColor.withValues(alpha: 0.16),
                            child: Text(
                              _hostLabel(invitation.hostUserId),
                              style: TextStyle(
                                color: hostColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _eventTitleForInvitation(invitation),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _invitationStatusLabel(invitation.status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'events_invitation_from',
                          values: {
                            'host': invitation.hostUserId,
                            'date': _formatShortDate(invitation.createdAt),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (pending)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => _respondInvitation(
                                          invitation,
                                          false,
                                        ),
                                  child: Text(
                                    AppStringsManager.getString(
                                      languageService.currentLanguage,
                                      'decline_btn',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => _respondInvitation(
                                          invitation,
                                          true,
                                        ),
                                  child: Text(
                                    isBusy
                                        ? '...'
                                        : context.tr(
                                            'events_accept_invitation',
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAiDetails(_UnifiedFeedItem item) {
    // Events-Limit prüfen (nur wenn Monetarisierung aktiv)
    if (EventsLimitService.instance.isLimitReached) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'events_activities_title',
                ),
              ),
            ),
            body: PremiumGate(
              featureLabel: context.tr('events_activities_title'),
              gateType: PremiumGateType.events,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      return;
    }
    // View registrieren
    EventsLimitService.instance.recordEventView();

    // Finde das originale DiscoveredEvent
    final discoveredEvent = _aiEvents
        .where((e) => e.id == item.eventId)
        .firstOrNull;
    if (discoveredEvent != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailPage(event: discoveredEvent),
        ),
      );
    } else {
      // Fallback: erstelle ein temporaeres DiscoveredEvent
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailPage(
            event: DiscoveredEvent(
              id:
                  item.eventId ??
                  'temp_${DateTime.now().millisecondsSinceEpoch}',
              title: item.title,
              description: item.description,
              category: DiscoveredEventCategory.sonstiges,
              ageLabels: item.ageLabel != null
                  ? [item.ageLabel!]
                  : [context.tr('filter_all')],
              location: item.location,
              cityHint: _searchCity,
              discoveredAt: DateTime.now(),
            ),
          ),
        ),
      );
    }
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: Colors.white),
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: compact ? 13 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnifiedFeedItem {
  const _UnifiedFeedItem({
    required this.source,
    required this.title,
    required this.description,
    required this.location,
    this.ageLabel,
    this.communityAgeGroups = const [],
    this.eventDate,
    this.eventTimeRange,
    this.latitude,
    this.longitude,
    this.priceLabel,
    this.isFree = false,
    this.eventId,
    this.hosterId,
    this.participationMode,
    this.confirmedParticipants = 0,
  });

  final _FeedSource source;
  final String title;
  final String description;
  final String location;
  final String? ageLabel;
  final List<AgeGroup> communityAgeGroups;
  final DateTime? eventDate;
  final String? eventTimeRange;
  final double? latitude;
  final double? longitude;
  final String? priceLabel;
  final bool isFree;
  final String? eventId;
  final String? hosterId;
  final ParticipationMode? participationMode;
  final int confirmedParticipants;

  factory _UnifiedFeedItem.fromAi(DiscoveredEvent event) {
    final price = event.price?.trim();
    final normalized = (price ?? '').toLowerCase();
    final isFree =
        normalized.contains('kostenlos') ||
        normalized.contains('free') ||
        normalized == '0 €' ||
        normalized == '0€';

    return _UnifiedFeedItem(
      source: _FeedSource.ai,
      title: event.title,
      description: event.description,
      location: event.location,
      ageLabel: event.ageLabels.isNotEmpty ? event.ageLabels.join(', ') : null,
      eventDate: event.eventDate,
      eventTimeRange: event.eventTimeRange,
      latitude: event.latitude,
      longitude: event.longitude,
      priceLabel: price,
      isFree: isFree,
      eventId: event.id,
    );
  }

  factory _UnifiedFeedItem.fromCommunity(MeetupEvent event) {
    final isFree = event.price == 0;
    final priceLabel = event.price == null || event.price == 0
        ? null
        : '${event.price!.toStringAsFixed(2)} €';

    return _UnifiedFeedItem(
      source: _FeedSource.community,
      hosterId: event.hosterId,
      title: event.title,
      description: event.description,
      location: event.location,
      ageLabel: null,
      communityAgeGroups: event.ageGroups,
      participationMode: event.participationMode,
      confirmedParticipants: event.currentParticipants,
      eventDate: event.eventDate,
      latitude: event.latitude,
      longitude: event.longitude,
      priceLabel: priceLabel,
      isFree: isFree,
      eventId: event.id,
    );
  }
}

class _UnifiedEventCard extends StatelessWidget {
  const _UnifiedEventCard({
    required this.item,
    this.distanceKm,
    required this.onTap,
  });

  final _UnifiedFeedItem item;
  final double? distanceKm;
  final VoidCallback onTap;

  Color _distanceColor(double km) {
    if (km <= 5) return const Color(0xFF15803D);
    if (km <= 15) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  String _distanceHint(BuildContext context, double km) {
    if (km <= 5) return context.tr('events_distance_near');
    if (km <= 15) return context.tr('events_distance_medium');
    return context.tr('events_distance_far');
  }

  String _formatCardDate(_UnifiedFeedItem item) {
    final d = item.eventDate!.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dateStr = '$dd.$mm.${d.year}';
    if (item.eventTimeRange != null && item.eventTimeRange!.isNotEmpty) {
      return '$dateStr  ${item.eventTimeRange!}';
    }
    if (d.hour != 0 || d.minute != 0) {
      final h = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$dateStr  $h:$min';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final isAi = item.source == _FeedSource.ai;
    final color = isAi ? const Color(0xFF0EA5A4) : const Color(0xFF2563EB);
    // Beziehung der angezeigten Person: geteiltes Angebot (interest) vs. nur
    // eingetragenes Dritt-Event. Steuert Label UND Teilnehmerzeile konsistent.
    final hostRelation = item.participationMode == ParticipationMode.interest
        ? EventHostRelation.sharedOffer
        : EventHostRelation.submittedBy;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isAi
                          ? context.tr('events_source_ai')
                          : context.tr(
                              'event_mode_${item.participationMode?.name ?? 'legacyApproval'}',
                            ),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item.eventDate != null)
                    Text(
                      _formatCardDate(item),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isAi) ...[
                if (item.hosterId?.isNotEmpty == true) ...[
                  EventHostIdentity(
                    userId: item.hosterId!,
                    relation: hostRelation,
                  ),
                  const SizedBox(height: 8),
                ],
                // Teilnehmerzahl nur bei echten Treffen mit Anmeldung
                // (Gastgeber) sinnvoll. Fuer geteilte/eingetragene Dritt-Events
                // ist „0 bestaetigt" irrefuehrend — stattdessen ein Hinweis auf
                // Anmeldung beim Veranstalter.
                Text(
                  context.tr(
                    switch (hostRelation) {
                      EventHostRelation.host => 'event_confirmed_count',
                      EventHostRelation.sharedOffer =>
                        'event_interest_not_booking',
                      EventHostRelation.submittedBy =>
                        'event_submitted_not_booking',
                    },
                    values: {'count': item.confirmedParticipants},
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (distanceKm != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _distanceColor(
                          distanceKm!,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: _distanceColor(distanceKm!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distanceKm!.toStringAsFixed(1)} km · ${_distanceHint(context, distanceKm!)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _distanceColor(distanceKm!),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (item.isFree ||
                  (item.priceLabel != null && item.priceLabel!.isNotEmpty)) ...[
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'events_price_label',
                    values: {
                      'price': item.isFree
                          ? context.tr('events_free')
                          : item.priceLabel!,
                    },
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if ((item.ageLabel != null && item.ageLabel!.isNotEmpty) ||
                  item.communityAgeGroups.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'events_for_age',
                    values: {
                      'age': item.communityAgeGroups.isNotEmpty
                          ? item.communityAgeGroups
                                .map((group) => context.tr(_ageGroupKey(group)))
                                .join(', ')
                          : item.ageLabel!,
                    },
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _ageGroupKey(AgeGroup ageGroup) {
  switch (ageGroup) {
    case AgeGroup.infant:
      return 'events_age_infant';
    case AgeGroup.toddler:
      return 'events_age_toddler';
    case AgeGroup.preschool:
      return 'events_age_preschool';
    case AgeGroup.elementary:
      return 'events_age_elementary';
    case AgeGroup.teenager:
      return 'events_age_teenager';
    case AgeGroup.mixed:
      return 'events_age_mixed';
  }
}
