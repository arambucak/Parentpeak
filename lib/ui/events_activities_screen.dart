import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:parentpeak/ui/event_detail_page.dart';
import 'package:parentpeak/ui/event_invitations_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';

class EventsActivitiesScreen extends StatefulWidget {
  final EventDiscoveryAgent? agent;
  final EventService? eventService;

  const EventsActivitiesScreen({
    super.key,
    this.agent,
    this.eventService,
  });

  @override
  State<EventsActivitiesScreen> createState() => _EventsActivitiesScreenState();
}

enum _FeedSource { ai, community }

enum _TimeWindowFilter { all, today, weekend }

class _EventsActivitiesScreenState extends State<EventsActivitiesScreen> {
  late final EventDiscoveryAgent _agent;
  late final EventService _eventService;

  // Single source of truth for location.
  // null = no location selected yet (bar shows "Standort wählen").
  PickedLocation? _activeLocation;
  // Fallback city for search when no active location (from saved prefs).
  String _fallbackCity = 'Berlin';
  // True once the user explicitly picked a location — GPS won't auto-override.
  bool _userLockedLocation = false;
  // True once we have a real location (from GPS or manual pick) — not just the Berlin default.
  bool _hasRealLocation = false;

  bool _isLoading = true;
  String? _errorMessage;
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
    _eventService = widget.eventService ?? EventService();
    _loadSavedCityThenDetect();
  }

  Future<void> _loadSavedCityThenDetect() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedCityKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _fallbackCity = saved;
        _hasRealLocation = true; // saved city = previously confirmed location
      });
      _refreshFeed(); // load immediately only when we have a real saved city
    }
    _detectGpsAndRefresh();
  }

  // Search city: active location takes priority, saved city is the fallback.
  String get _searchCity => _activeLocation?.city.isNotEmpty == true
      ? _activeLocation!.city
      : _fallbackCity;

  @override
  void dispose() {
    super.dispose();
  }

  // ─── GPS Standort-Erkennung ───────────────────────────────────────────────

  /// [forceOverride] true wenn Nutzer den GPS-Button manuell drueckt —
  /// dann wird die Stadt immer aktualisiert und gespeichert.
  Future<void> _detectGpsAndRefresh({bool forceOverride = false}) async {
    setState(() => _gpsDetecting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _gpsDetecting = false);
          if (!_hasRealLocation) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('GPS nicht verfügbar — bitte Standort oben eingeben.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
        if (_hasRealLocation) _refreshFeed();
        return;
      }
      // Web needs more time: browser uses WiFi/IP geolocation
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 6),
        ),
      );
      final district = await _reverseGeocode(pos.latitude, pos.longitude);
      // When Nominatim fails, use coordinates as search city so Gemini can locate events
      final coordCity = '${pos.latitude.toStringAsFixed(4)},${pos.longitude.toStringAsFixed(4)}';
      final cityLabel = district ?? 'Aktueller Standort';
      final city = district != null
          ? (district.contains(',') ? district.split(',').last.trim() : district)
          : coordCity; // pass raw coords to agent when city name unknown
      final newLocation = PickedLocation(
        displayName: cityLabel,
        city: city,
        postcode: '',
        lat: pos.latitude,
        lon: pos.longitude,
      );
      if (mounted) {
        final shouldUpdate = forceOverride || !_userLockedLocation;
        if (shouldUpdate) {
          final prefs = await SharedPreferences.getInstance();
          if (district != null) await prefs.setString(_savedCityKey, district);
        }
        setState(() {
          _activeLocation = newLocation;
          _hasRealLocation = true;
          if (shouldUpdate) {
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
      final headers = kIsWeb ? <String, String>{} : {'User-Agent': 'ParentPeak/1.0 (family app)'};
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final suburb = address?['suburb'] as String? ??
            address?['quarter'] as String? ??
            address?['neighbourhood'] as String?;
        final cityName = address?['city'] as String? ??
            address?['town'] as String? ??
            address?['village'] as String?;
        if (suburb != null && cityName != null) return '$suburb, $cityName';
        if (cityName != null) return cityName;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _refreshFeed() async {
    final city = _searchCity;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final viewerUserId = AuthService.instance.currentUser?.uid ?? 'guest';
      final coords = _coordsForCity(city);
      List<DiscoveredEvent> aiEvents;
      try {
        aiEvents = await _agent.discoverEvents(
          city: city,
          radiusHint: '$_radiusKm km Umkreis',
          childAges: _selectedAgeGroups.map(_ageGroupLabel).toList(),
          latitude: _activeLocation?.lat,
          longitude: _activeLocation?.lon,
        );
      } catch (e) {
        debugPrint('EventsActivitiesScreen: AI feed unavailable: $e');
        aiEvents = const <DiscoveredEvent>[];
      }

      List<MeetupEvent> communityEvents;
      try {
        communityEvents = await _loadCommunityEventsForCity(coords);
      } catch (e) {
        debugPrint('EventsActivitiesScreen: community feed unavailable: $e');
        communityEvents = const <MeetupEvent>[];
      }

      List<EventInvitation> invitations;
      try {
        invitations = await _eventService.getInvitationsForUser(viewerUserId);
      } catch (e) {
        debugPrint('EventsActivitiesScreen: invitations load skipped: $e');
        invitations = const <EventInvitation>[];
      }

      final titleMap = <String, String>{
        for (final event in communityEvents) event.id: event.title,
      };
      final missingEventIds = invitations
          .map((inv) => inv.eventId)
          .where((id) => id.isNotEmpty && !titleMap.containsKey(id))
          .toSet();

      for (final eventId in missingEventIds) {
        final event = await _eventService.getEventById(eventId);
        if (event != null) {
          titleMap[eventId] = event.title;
        }
      }

      if (aiEvents.isEmpty && communityEvents.isEmpty) {
        aiEvents = _buildLocalFallbackAiEvents(city, _originCoords);
      }

      if (!mounted) return;
      setState(() {
        _aiEvents = aiEvents;
        _communityEvents = communityEvents;
        _invitations = invitations;
        _eventTitlesById = titleMap;
        _isLoading = false;
        _lastFeedSyncAt = DateTime.now();
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('EventsActivitiesScreen._refreshFeed(): failed: $e');
      if (!mounted) return;
      setState(() {
        _aiEvents = const <DiscoveredEvent>[];
        _communityEvents = const <MeetupEvent>[];
        _invitations = const <EventInvitation>[];
        _eventTitlesById = const {};
        _errorMessage = null;
        _isLoading = false;
        _lastFeedSyncAt = DateTime.now();
      });
    }
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

  List<DiscoveredEvent> _buildLocalFallbackAiEvents(
    String city,
    (double, double) coords,
  ) {
    final now = DateTime.now();
    return <DiscoveredEvent>[
      DiscoveredEvent(
        id: 'fallback_event_1',
        title: 'Spielplatz-Treff im Kiez',
        description:
            'Offenes Treffen fuer Eltern mit Kindern. Lockeres Kennenlernen mit kurzer Bewegungsrunde.',
        category: DiscoveredEventCategory.spielplatz,
        ageLabels: const ['Alle Altersklassen'],
        location: 'Stadtpark Nord',
        cityHint: city,
        latitude: coords.$1,
        longitude: coords.$2,
        eventDate: now.add(const Duration(days: 1)),
        price: 'kostenlos',
        organizer: 'Parentpeak Community',
        discoveredAt: now,
      ),
      DiscoveredEvent(
        id: 'fallback_event_2',
        title: 'Kreativnachmittag fuer Familien',
        description:
            'Basteln mit Alltagsmaterialien, kleine Mitmachstationen und Zeit fuer Austausch.',
        category: DiscoveredEventCategory.basteln,
        ageLabels: const ['Alle Altersklassen'],
        location: 'Familienzentrum Mitte',
        cityHint: city,
        latitude: coords.$1 + 0.01,
        longitude: coords.$2 + 0.01,
        eventDate: now.add(const Duration(days: 3)),
        price: 'kostenlos',
        organizer: 'Lokales Familienzentrum',
        discoveredAt: now,
      ),
      DiscoveredEvent(
        id: 'fallback_event_3',
        title: 'Waldspaziergang mit Kindern',
        description:
            'Gemeinsamer Spaziergang mit kleinen Naturspielen. Kinderwagenfreundliche Strecke.',
        category: DiscoveredEventCategory.natur,
        ageLabels: const ['Alle Altersklassen'],
        location: 'Waldpark Treffpunkt Ost',
        cityHint: city,
        latitude: coords.$1 - 0.015,
        longitude: coords.$2 + 0.008,
        eventDate: now.add(const Duration(days: 5)),
        price: 'kostenlos',
        organizer: 'Elterninitiative',
        discoveredAt: now,
      ),
    ];
  }

  Future<List<MeetupEvent>> _loadCommunityEventsForCity(
      (double, double) coords) async {
    final viewerUserId = AuthService.instance.currentUser?.uid;
    if (viewerUserId == null || viewerUserId.trim().isEmpty) {
      final publicEvents = await _eventService.getEvents();
      return publicEvents.where((event) {
        if (event.status != EventStatus.active) return false;
        if (event.visibility != EventVisibility.publicNearby) return false;

        final distance =
            _distanceKm(coords.$1, coords.$2, event.latitude, event.longitude);
        final visibleRadius = event.shareRadiusKm ?? _radiusKm.toDouble();
        if (distance > visibleRadius || distance > _radiusKm) return false;

        if (_selectedAgeGroups.isNotEmpty &&
            !event.ageGroups.any(_selectedAgeGroups.contains)) {
          return false;
        }

        return true;
      }).toList();
    }

    return _eventService.getDiscoverableEventsForUser(
      viewerUserId: viewerUserId,
      viewerLatitude: coords.$1,
      viewerLongitude: coords.$2,
      ageGroups:
          _selectedAgeGroups.isEmpty ? null : _selectedAgeGroups.toList(),
    );
  }

  (double, double) _coordsForCity(String city) {
    final normalized = city.toLowerCase();
    if (normalized.contains('hamburg')) return (53.5511, 9.9937);
    if (normalized.contains('münchen') || normalized.contains('munchen')) {
      return (48.1351, 11.5820);
    }
    if (normalized.contains('köln') || normalized.contains('koeln')) {
      return (50.9375, 6.9603);
    }
    if (normalized.contains('frankfurt')) return (50.1109, 8.6821);
    return (52.5200, 13.4050);
  }

  (double, double) get _originCoords {
    final loc = _activeLocation;
    if (loc != null && loc.lat != 0) return (loc.lat, loc.lon);
    return _coordsForCity(_searchCity);
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

    filtered.sort((a, b) {
      final aScore = _rankingScore(a, coords.$1, coords.$2);
      final bScore = _rankingScore(b, coords.$1, coords.$2);
      return bScore.compareTo(aScore);
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
        .where((item) => _matchesNearbyQuickFilter(item, coords.$1, coords.$2))
        .length;
  }

  bool _matchesPriceFilter(_UnifiedFeedItem item) {
    if (!_onlyFree) return true;
    return item.isFree;
  }

  bool _matchesTimeWindow(_UnifiedFeedItem item) {
    if (_timeWindowFilter == _TimeWindowFilter.all) return true;
    if (item.eventDate == null) return false;

    final date = item.eventDate!;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (_timeWindowFilter == _TimeWindowFilter.today) {
      return isToday;
    }

    final withinNext7Days = date.isBefore(now.add(const Duration(days: 7))) &&
        date.isAfter(now.subtract(const Duration(days: 1)));
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    return withinNext7Days && isWeekend;
  }

  bool _withinRadius(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
    int radiusKm,
  ) {
    if (item.latitude == null || item.longitude == null) return true;
    final distance =
        _distanceKm(originLat, originLon, item.latitude!, item.longitude!);
    return distance <= radiusKm;
  }

  bool _matchesNearbyQuickFilter(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
  ) {
    if (!_onlyNearbyQuick) return true;
    if (item.latitude == null || item.longitude == null) return false;
    final distance =
        _distanceKm(originLat, originLon, item.latitude!, item.longitude!);
    return distance <= 10;
  }

  bool _matchesSelectedAges(_UnifiedFeedItem item) {
    if (_selectedAgeGroups.isEmpty) return true;

    if (item.source == _FeedSource.community) {
      return item.communityAgeGroups.any(_selectedAgeGroups.contains);
    }

    final text = (item.ageLabel ?? '').toLowerCase();
    if (text.isEmpty) return false;

    bool matches(AgeGroup group) {
      switch (group) {
        case AgeGroup.infant:
          return text.contains('0') ||
              text.contains('baby') ||
              text.contains('säug');
        case AgeGroup.toddler:
          return text.contains('1') ||
              text.contains('2') ||
              text.contains('3') ||
              text.contains('kleinkind');
        case AgeGroup.preschool:
          return text.contains('4') ||
              text.contains('5') ||
              text.contains('6') ||
              text.contains('vorschule');
        case AgeGroup.elementary:
          return text.contains('6') ||
              text.contains('7') ||
              text.contains('8') ||
              text.contains('9') ||
              text.contains('10') ||
              text.contains('grundschule');
        case AgeGroup.teenager:
          return text.contains('11') ||
              text.contains('12') ||
              text.contains('13') ||
              text.contains('14') ||
              text.contains('15') ||
              text.contains('16') ||
              text.contains('teen');
        case AgeGroup.mixed:
          return text.contains('alle') ||
              text.contains('familie') ||
              text.contains('mixed');
      }
    }

    return _selectedAgeGroups.any(matches);
  }

  double _rankingScore(
      _UnifiedFeedItem item, double originLat, double originLon) {
    double score = 0;

    if (item.eventDate != null) {
      final days = item.eventDate!.difference(DateTime.now()).inDays;
      final urgency = (30 - days).clamp(0, 30).toDouble();
      score += urgency * 2;
    }

    if (item.latitude != null && item.longitude != null) {
      final distance =
          _distanceKm(originLat, originLon, item.latitude!, item.longitude!);
      score += (50 - distance).clamp(0, 50);
    } else {
      score += 8;
    }

    if (_selectedAgeGroups.isEmpty || _matchesSelectedAges(item)) {
      score += 20;
    }

    if (item.source == _FeedSource.community) {
      score += 4;
    }

    return score;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  double? _distanceKmForDisplay(
    _UnifiedFeedItem item,
    double originLat,
    double originLon,
  ) {
    if (item.latitude == null || item.longitude == null) return null;
    return _distanceKm(originLat, originLon, item.latitude!, item.longitude!);
  }

  String _ageGroupLabel(AgeGroup ageGroup) {
    switch (ageGroup) {
      case AgeGroup.infant:
        return '0-1 Jahre';
      case AgeGroup.toddler:
        return '1-3 Jahre';
      case AgeGroup.preschool:
        return '4-6 Jahre';
      case AgeGroup.elementary:
        return '6-10 Jahre';
      case AgeGroup.teenager:
        return '11-16 Jahre';
      case AgeGroup.mixed:
        return 'Gemischt';
    }
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
      final rankCompare =
          _statusRank(a.status).compareTo(_statusRank(b.status));
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
        return 'Ausstehend';
      case EventInvitationStatus.accepted:
        return 'Angenommen';
      case EventInvitationStatus.declined:
        return 'Abgelehnt';
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
        'Event ${invitation.eventId.isEmpty ? 'ohne ID' : invitation.eventId}';
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
      EventInvitation invitation, bool accept) async {
    setState(() => _updatingInvitationIds.add(invitation.id));

    try {
      await _eventService.respondToInvitation(
        invitationId: invitation.id,
        accept: accept,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(accept ? 'Einladung angenommen.' : 'Einladung abgelehnt.'),
          duration: const Duration(seconds: 2),
        ),
      );
      await _refreshFeed();
    } catch (e) {
      debugPrint('EventsActivitiesScreen._respondInvitation(): failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktion konnte nicht gespeichert werden.'),
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
    final city = _searchCity;
    final coords = _coordsForCity(city);
    final showInvitationsSection = _invitations.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Events & Aktivitäten')),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        'Event-Stand: ${_formatLastSyncLabel(_lastFeedSyncAt!)}',
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
              'Für dich in der Nähe',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
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
                      onPressed: _refreshFeed,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Erneut laden'),
                    ),
                  ],
                ),
              )
            else if (feed.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Keine echten Events sind aktuell verfügbar.',
                ),
              )
            else
              ...feed.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UnifiedEventCard(
                    item: item,
                    distanceKm:
                        _distanceKmForDisplay(item, coords.$1, coords.$2),
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
                            builder: (_) => EventDetailScreen(event: event),
                          ),
                        );
                        return;
                      }
                      _showAiDetails(item);
                    },
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
  }

  Widget _buildPinnedActionBar(ThemeData theme) {
    final isCompact = MediaQuery.sizeOf(context).width < 390;

    return Container(
      color: const Color(0xFFEFF3F8),
      padding:
          EdgeInsets.fromLTRB(16, isCompact ? 6 : 8, 16, isCompact ? 6 : 8),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
          border: Border.all(
            color: const Color(0xFFCAD9EE),
          ),
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
            'Dein Familien-Spot',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Finden. Teilen. Gemeinsam erleben.',
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
            label: 'Event planen',
            color: const Color(0xFFEA580C),
            compact: compact,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateEventScreen()),
              ).then((_) => _refreshFeed());
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompactActionButton(
            icon: Icons.mark_email_unread_rounded,
            label: 'Einladungen',
            color: const Color(0xFF4F46E5),
            compact: compact,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EventInvitationsScreen(),
                ),
              ).then((_) => _refreshFeed());
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
            hint: 'Standort waehlen',
            initialLocation: _activeLocation,
            onLocationPicked: (loc) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_savedCityKey, loc.city.isNotEmpty ? loc.city : loc.displayName);
              setState(() {
                _activeLocation = loc;
                _fallbackCity = loc.city.isNotEmpty ? loc.city : loc.displayName;
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
          message: _activeLocation != null ? 'GPS aktiv' : 'Standort automatisch erkennen',
          child: InkWell(
            onTap: _gpsDetecting ? null : () => _detectGpsAndRefresh(forceOverride: true),
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
                      width: 18, height: 18,
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
          label: const Text('KI-Funde'),
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
          label: const Text('Community-Angebote'),
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
          label: Text('Nur nah ($_nearbyQuickCount)'),
          selected: _onlyNearbyQuick,
          onSelected: (value) {
            setState(() => _onlyNearbyQuick = value);
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
            'Feinfilter & Ranking',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
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
                label: const Text('Nur kostenlos'),
                selected: _onlyFree,
                onSelected: (value) {
                  setState(() => _onlyFree = value);
                },
              ),
              ChoiceChip(
                label: const Text('Alle Termine'),
                selected: _timeWindowFilter == _TimeWindowFilter.all,
                onSelected: (_) {
                  setState(() => _timeWindowFilter = _TimeWindowFilter.all);
                },
              ),
              ChoiceChip(
                label: const Text('Heute'),
                selected: _timeWindowFilter == _TimeWindowFilter.today,
                onSelected: (_) {
                  setState(() => _timeWindowFilter = _TimeWindowFilter.today);
                },
              ),
              ChoiceChip(
                label: const Text('Dieses Wochenende'),
                selected: _timeWindowFilter == _TimeWindowFilter.weekend,
                onSelected: (_) {
                  setState(() => _timeWindowFilter = _TimeWindowFilter.weekend);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sortierung: näher + zeitnah + passende Altersgruppe zuerst.',
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
                'Einladungen',
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
                  '$_pendingInvitationsCount offen',
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
              'Keine offenen Einladungen.',
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
                                horizontal: 8, vertical: 3),
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
                        'Von ${invitation.hostUserId} · Eingang: ${_formatShortDate(invitation.createdAt)}',
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
                                  child: const Text('Ablehnen'),
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
                                  child: Text(isBusy ? '...' : 'Zusagen'),
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
    // Finde das originale DiscoveredEvent
    final discoveredEvent =
        _aiEvents.where((e) => e.id == item.eventId).firstOrNull;
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
              id: item.eventId ??
                  'temp_${DateTime.now().millisecondsSinceEpoch}',
              title: item.title,
              description: item.description,
              category: DiscoveredEventCategory.sonstiges,
              ageLabels: item.ageLabel != null ? [item.ageLabel!] : ['Alle'],
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

  factory _UnifiedFeedItem.fromAi(DiscoveredEvent event) {
    final price = event.price?.trim();
    final normalized = (price ?? '').toLowerCase();
    final isFree = normalized.contains('kostenlos') ||
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
    final age = event.ageGroups.map((e) => e.name).join(', ');
    final isFree = event.price == null || event.price == 0;
    final priceLabel =
        isFree ? 'kostenlos' : '${event.price!.toStringAsFixed(0)} €';

    return _UnifiedFeedItem(
      source: _FeedSource.community,
      title: event.title,
      description: event.description,
      location: event.location,
      ageLabel: age.isEmpty ? null : age,
      communityAgeGroups: event.ageGroups,
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

  String _distanceHint(double km) {
    if (km <= 5) return 'nah';
    if (km <= 15) return 'mittel';
    return 'weit';
  }

  String _formatCardDate(_UnifiedFeedItem item) {
    final d = item.eventDate!;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dateStr = '$dd.$mm.${d.year}';
    if (item.eventTimeRange != null && item.eventTimeRange!.isNotEmpty) {
      return '$dateStr  ${item.eventTimeRange!}';
    }
    if (d.hour != 0 || d.minute != 0) {
      final h = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$dateStr  $h:$min Uhr';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final isAi = item.source == _FeedSource.ai;
    final color = isAi ? const Color(0xFF0EA5A4) : const Color(0xFF2563EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isAi ? 'KI' : 'Community',
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
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                        color:
                            _distanceColor(distanceKm!).withValues(alpha: 0.15),
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
                            '${distanceKm!.toStringAsFixed(1)} km · ${_distanceHint(distanceKm!)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
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
              if (item.priceLabel != null && item.priceLabel!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Preis: ${item.priceLabel}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (item.ageLabel != null && item.ageLabel!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Für: ${item.ageLabel}',
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
