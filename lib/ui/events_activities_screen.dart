import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:parentpeak/ui/event_invitations_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';

class EventsActivitiesScreen extends StatefulWidget {
  const EventsActivitiesScreen({super.key});

  @override
  State<EventsActivitiesScreen> createState() => _EventsActivitiesScreenState();
}

enum _FeedSource { ai, community }

enum _TimeWindowFilter { all, today, weekend }

class _EventsActivitiesScreenState extends State<EventsActivitiesScreen> {
  final EventDiscoveryAgent _agent = EventDiscoveryAgent.instance;
  final EventService _eventService = EventService();
  final TextEditingController _cityController =
      TextEditingController(text: 'Berlin');

  bool _isLoading = true;
  String? _errorMessage;
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

  @override
  void initState() {
    super.initState();
    _refreshFeed();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    final city = _cityController.text.trim().isEmpty
        ? 'Berlin'
        : _cityController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final viewerUserId = AuthService.instance.currentUser?.uid;
      if (viewerUserId == null || viewerUserId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _aiEvents = const [];
          _communityEvents = const [];
          _invitations = const [];
          _eventTitlesById = const {};
          _errorMessage = 'Bitte melde dich an, um Events zu sehen.';
          _isLoading = false;
        });
        return;
      }
      final coords = _coordsForCity(city);
      final aiFuture = _agent.discoverEvents(
        city: city,
        radiusHint: '$_radiusKm km Umkreis',
        childAges: _selectedAgeGroups.map(_ageGroupLabel).toList(),
      );
      final communityFuture = _loadCommunityEventsForCity(coords);
      final invitationsFuture =
          _eventService.getInvitationsForUser(viewerUserId);
      final results = await Future.wait<dynamic>([
        aiFuture,
        communityFuture,
        invitationsFuture,
      ]);

      final communityEvents = results[1] as List<MeetupEvent>;
      final invitations = results[2] as List<EventInvitation>;

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

      if (!mounted) return;
      setState(() {
        _aiEvents = results[0] as List<DiscoveredEvent>;
        _communityEvents = communityEvents;
        _invitations = invitations;
        _eventTitlesById = titleMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('EventsActivitiesScreen._refreshFeed(): failed: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Feed konnte nicht geladen werden. Bitte versuche es erneut.';
        _isLoading = false;
      });
    }
  }

  Future<List<MeetupEvent>> _loadCommunityEventsForCity(
      (double, double) coords) async {
    final viewerUserId = AuthService.instance.currentUser?.uid;
    if (viewerUserId == null || viewerUserId.trim().isEmpty) {
      return const <MeetupEvent>[];
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

  List<_UnifiedFeedItem> get _combinedFeed {
    final coords = _coordsForCity(_cityController.text.trim().isEmpty
        ? 'Berlin'
        : _cityController.text.trim());
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
    final coords = _coordsForCity(_cityController.text.trim().isEmpty
        ? 'Berlin'
        : _cityController.text.trim());

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
    final city = _cityController.text.trim().isEmpty
        ? 'Berlin'
        : _cityController.text.trim();
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeaderCard(theme),
            const SizedBox(height: 10),
            _buildPinnedActionBar(theme),
            const SizedBox(height: 12),
            _buildLocationSearch(theme),
            const SizedBox(height: 12),
            _buildSourceFilters(theme),
            if (showInvitationsSection) ...[
              const SizedBox(height: 10),
              _buildInvitationsSection(theme),
            ],
            const SizedBox(height: 10),
            _buildAdvancedFilters(theme),
            const SizedBox(height: 14),
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
                  'Keine passenden Events gefunden. Passe den Standort an oder veröffentliche selbst ein Angebot.',
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
    return LocationPickerWidget(
      hint: 'Standort waehlen',
      onLocationPicked: (loc) {
        _cityController.text = loc.displayName;
        _refreshFeed();
      },
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(item.description),
              const SizedBox(height: 10),
              Text('Ort: ${item.location}'),
              if (item.ageLabel != null && item.ageLabel!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Altersgruppe: ${item.ageLabel}'),
              ],
            ],
          ),
        );
      },
    );
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
      latitude: event.latitude,
      longitude: event.longitude,
      priceLabel: price,
      isFree: isFree,
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
                      '${item.eventDate!.day.toString().padLeft(2, '0')}.${item.eventDate!.month.toString().padLeft(2, '0')}.${item.eventDate!.year}',
                      style: Theme.of(context).textTheme.bodySmall,
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
