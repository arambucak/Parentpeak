import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:parentpeak/ui/widgets/event_host_identity.dart';
import 'package:parentpeak/ui/widgets/event_photo.dart';

class MeetupScreen extends StatefulWidget {
  const MeetupScreen({super.key});

  @override
  State<MeetupScreen> createState() => _MeetupScreenState();
}

enum FeedVisibilityFilter { all, publicOnly, familyCircle, inviteOnly }

class _MeetupScreenState extends State<MeetupScreen> {
  final _eventService = EventService();
  List<MeetupEvent> _events = [];
  bool _isGridView = false;
  bool _isLoading = true;
  bool _showAgeFilters = false;
  final List<AgeGroup> _selectedAgeGroups = [];
  FeedVisibilityFilter _visibilityFilter = FeedVisibilityFilter.all;
  static const double _viewerLatitude = 52.5200;
  static const double _viewerLongitude = 13.4050;

  @override
  void initState() {
    super.initState();
    if (!FeatureFlags.enableFamilyCircle &&
        _visibilityFilter == FeedVisibilityFilter.familyCircle) {
      _visibilityFilter = FeedVisibilityFilter.all;
    }
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final viewerUserId = AuthService.instance.currentUser?.uid;
      if (viewerUserId == null || viewerUserId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _events = const [];
          _isLoading = false;
        });
        return;
      }
      final events = await _eventService.getDiscoverableEventsForUser(
        viewerUserId: viewerUserId,
        viewerLatitude: _viewerLatitude,
        viewerLongitude: _viewerLongitude,
        ageGroups: _selectedAgeGroups,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_action_failed'))),
      );
    }
  }

  void _filterByAgeGroup(AgeGroup ageGroup) {
    setState(() {
      if (_selectedAgeGroups.contains(ageGroup)) {
        _selectedAgeGroups.remove(ageGroup);
      } else {
        _selectedAgeGroups.add(ageGroup);
      }
    });
  }

  List<MeetupEvent> get _filteredEvents {
    final byAge = _selectedAgeGroups.isEmpty
        ? _events
        : _events
            .where((event) =>
                event.ageGroups.any((ag) => _selectedAgeGroups.contains(ag)))
            .toList();

    switch (_visibilityFilter) {
      case FeedVisibilityFilter.all:
        return byAge;
      case FeedVisibilityFilter.publicOnly:
        return byAge
            .where((e) => e.visibility == EventVisibility.publicNearby)
            .toList();
      case FeedVisibilityFilter.familyCircle:
        return byAge
            .where((e) => e.visibility == EventVisibility.familyCircle)
            .toList();
      case FeedVisibilityFilter.inviteOnly:
        return byAge
            .where((e) => e.visibility == EventVisibility.inviteOnly)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('meetup_title')),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          ).then((_) => _loadEvents());
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('meetup_nearby'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('meetup_filter_description'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                context.tr('meetup_activity_count',
                                  values: {'count': _filteredEvents.length}),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showAgeFilters = !_showAgeFilters),
                            icon: Icon(_showAgeFilters
                                ? Icons.tune_rounded
                                : Icons.tune_outlined),
                            label:
                                Text(context.tr(_showAgeFilters
                                  ? 'meetup_less_filters'
                                  : 'meetup_more_filters')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildVisibilityChip(
                          label: context.tr('filter_all'),
                          selected: _visibilityFilter == FeedVisibilityFilter.all,
                          onTap: () =>
                              setState(() => _visibilityFilter = FeedVisibilityFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _buildVisibilityChip(
                          label: context.tr('filter_public'),
                          selected:
                              _visibilityFilter == FeedVisibilityFilter.publicOnly,
                          onTap: () => setState(
                              () => _visibilityFilter = FeedVisibilityFilter.publicOnly),
                        ),
                        if (FeatureFlags.enableFamilyCircle) ...[
                          const SizedBox(width: 8),
                          _buildVisibilityChip(
                            label: context.tr('filter_family_circle'),
                            selected:
                                _visibilityFilter == FeedVisibilityFilter.familyCircle,
                            onTap: () => setState(() =>
                                _visibilityFilter =
                                    FeedVisibilityFilter.familyCircle),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _buildVisibilityChip(
                          label: context.tr('filter_invited'),
                          selected:
                              _visibilityFilter == FeedVisibilityFilter.inviteOnly,
                          onTap: () => setState(
                              () => _visibilityFilter = FeedVisibilityFilter.inviteOnly),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAgeFilters)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: AgeGroup.values
                          .map(
                            (ageGroup) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_getAgeGroupLabel(ageGroup)),
                                selected: _selectedAgeGroups.contains(ageGroup),
                                onSelected: (_) => _filterByAgeGroup(ageGroup),
                                selectedColor: const Color(0xFFDBEAFE),
                                checkmarkColor: const Color(0xFF1D4ED8),
                                labelStyle: TextStyle(
                                  color: _selectedAgeGroups.contains(ageGroup)
                                      ? const Color(0xFF1D4ED8)
                                      : null,
                                  fontWeight:
                                      _selectedAgeGroups.contains(ageGroup)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('events_view'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildViewToggleButton(
                              icon: Icons.view_comfy,
                              selected: _isGridView,
                              onTap: () => setState(() => _isGridView = true),
                            ),
                            _buildViewToggleButton(
                              icon: Icons.list,
                              selected: !_isGridView,
                              onTap: () => setState(() => _isGridView = false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('events_empty_title'),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('events_empty_subtitle'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _isGridView
                          ? GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.sizeOf(context).width < 500 ? 1 : 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 360 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 6,
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) =>
                                  _buildEventCard(_filteredEvents[index]),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) =>
                                  _buildEventListItem(_filteredEvents[index]),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventCard(MeetupEvent event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        ).then((_) {
          if (mounted) _loadEvents();
        });
      },
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: event.photoUrl.isEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFFDBEAFE), Color(0xFFE0F2FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: EventPhoto(photoUrl: event.photoUrl),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getCategoryLabel(event.category),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (event.isFull)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.tr('event_detail_fully_booked'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (event.visibility != EventVisibility.publicNearby)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getVisibilityBadge(event),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  EventHostIdentity(
                    userId: event.hosterId,
                    isSharedOffer: event.participationMode == ParticipationMode.interest,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${event.eventDate.day}.${event.eventDate.month}. ${event.eventDate.hour.toString().padLeft(2, '0')}:${event.eventDate.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${event.currentParticipants}/${event.maxParticipants}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1D4ED8) : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildEventListItem(MeetupEvent event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        ).then((_) {
          if (mounted) _loadEvents();
        });
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: SizedBox(
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: EventPhoto(photoUrl: event.photoUrl),
            ),
          ),
          title: Text(event.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              EventHostIdentity(
                userId: event.hosterId,
                isSharedOffer: event.participationMode == ParticipationMode.interest,
              ),
              const SizedBox(height: 4),
              if (event.visibility != EventVisibility.publicNearby)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _getVisibilityDescription(event),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${event.eventDate.day}.${event.eventDate.month}. ${event.eventDate.hour.toString().padLeft(2, '0')}:${event.eventDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.people, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${event.currentParticipants}/${event.maxParticipants}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          trailing: event.isFull
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('event_detail_fully_booked'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                )
              : Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
        ),
      ),
    );
  }

  String _getCategoryLabel(EventCategory category) {
    return context.tr(category == EventCategory.socialGathering
        ? 'event_category_social'
        : 'event_category_${category.name}');
  }

  String _getAgeGroupLabel(AgeGroup ageGroup) {
    return context.tr('event_age_${ageGroup.name}');
  }

  String _getVisibilityBadge(MeetupEvent event) {
    switch (event.visibility) {
      case EventVisibility.privateOnly:
        return context.tr('events_visibility_private');
      case EventVisibility.familyCircle:
        return context.tr('event_visibility_circle');
      case EventVisibility.inviteOnly:
        return context.tr('events_visibility_invited');
      case EventVisibility.publicNearby:
        return '';
    }
  }

  String _getVisibilityDescription(MeetupEvent event) {
    switch (event.visibility) {
      case EventVisibility.privateOnly:
        return context.tr('events_visibility_private');
      case EventVisibility.familyCircle:
        return context.tr('event_visibility_circle');
      case EventVisibility.inviteOnly:
        return context.tr('events_visibility_invited');
      case EventVisibility.publicNearby:
        return '';
    }
  }
}
