import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/participation_service.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/meetup_chat_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final MeetupEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _participationService = ParticipationService();
  bool _hasRequested = false;
  bool _isApproved = false;
  bool _isDeclined = false;
  bool _isLoading = false;
  bool _requiresSignIn = false;

  String? get _currentUserId => AuthService.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _checkParticipationStatus();
  }

  Future<void> _checkParticipationStatus() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _requiresSignIn = true;
      });
      return;
    }

    final participation =
        await _participationService.getParticipationByUserAndEvent(
      userId: currentUserId,
      eventId: widget.event.id,
    );

    if (!mounted) return;
    setState(() {
      _isApproved = participation?.status == ParticipationStatus.approved;
      _isDeclined = participation?.status == ParticipationStatus.declined;
      _hasRequested = participation?.status == ParticipationStatus.pending ||
          participation?.status == ParticipationStatus.approved;
      _requiresSignIn = false;
    });
  }

  Future<void> _requestParticipation() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('event_detail_join_sign_in_required')),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _participationService.requestParticipation(
        eventId: widget.event.id,
        userId: currentUserId,
      );

      if (!mounted) return;
      setState(() {
        _hasRequested = true;
        _isDeclined = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_detail_request_sent'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('event_detail_error', values: {'error': e}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('event_details_title')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_requiresSignIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  context.tr('event_detail_sign_in_required'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: widget.event.photoUrl.isEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFFDBEAFE), Color(0xFFE0F2FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: widget.event.photoUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(widget.event.photoUrl),
                        fit: BoxFit.cover,
                      ),
              ),
              child: Stack(
                children: [
                  if (widget.event.photoUrl.isEmpty)
                    const Center(
                      child: Icon(
                        Icons.celebration_rounded,
                        size: 56,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getCategoryLabel(widget.event.category),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.event.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _MetaPill(
                                icon: Icons.people_outline_rounded,
                                label: context.tr('event_places'),
                                value:
                                    '${widget.event.currentParticipants}/${widget.event.maxParticipants}',
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetaPill(
                                icon: Icons.schedule_rounded,
                                label: context.tr('common_status'),
                                value: context.tr(widget.event.isFull
                                    ? 'status_full'
                                    : 'status_open'),
                                color: widget.event.isFull
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInfoTile(
                    icon: Icons.calendar_today,
                    title:
                        '${widget.event.eventDate.day}.${widget.event.eventDate.month}.${widget.event.eventDate.year}',
                    subtitle:
                        '${widget.event.eventDate.hour.toString().padLeft(2, '0')}:${widget.event.eventDate.minute.toString().padLeft(2, '0')} Uhr',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoTile(
                    icon: Icons.location_on,
                    title: widget.event.location,
                    subtitle:
                        '${widget.event.latitude.toStringAsFixed(3)}, ${widget.event.longitude.toStringAsFixed(3)}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoTile(
                    icon: Icons.people,
                    title: context.tr(
                      'event_detail_participants',
                      values: {
                        'current': widget.event.currentParticipants,
                        'maximum': widget.event.maxParticipants,
                      },
                    ),
                    subtitle: widget.event.spotsAvailable > 0
                        ? context.tr(
                            'event_detail_spots_available',
                            values: {'count': widget.event.spotsAvailable},
                          )
                        : context.tr('event_detail_fully_booked'),
                  ),
                  const SizedBox(height: 12),
                  _buildAgeGroupChips(),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('event_detail_description'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.event.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isApproved)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusBanner(
                          icon: Icons.check_circle,
                          text: context.tr('event_detail_registered'),
                          bgColor: const Color(0xFFDCFCE7),
                          textColor: const Color(0xFF166534),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MeetupChatScreen(
                                    event: widget.event,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat),
                            label: Text(context.tr('event_detail_open_chat')),
                          ),
                        ),
                      ],
                    )
                  else if (_hasRequested)
                    _buildStatusBanner(
                      icon: Icons.schedule,
                      text: context.tr('event_detail_request_pending'),
                      bgColor: const Color(0xFFFEF3C7),
                      textColor: const Color(0xFF92400E),
                    )
                  else if (_isDeclined)
                    _buildStatusBanner(
                      icon: Icons.info_outline_rounded,
                      text: context.tr('event_detail_request_declined'),
                      bgColor: const Color(0xFFFEE2E2),
                      textColor: const Color(0xFF991B1B),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            widget.event.isFull ? null : _requestParticipation,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add),
                        label: Text(
                          context.tr('event_detail_request_participation'),
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

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGroupChips() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('event_detail_age_groups'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.event.ageGroups
              .map(
                (ageGroup) => Chip(
                  label: Text(_getAgeGroupLabel(ageGroup)),
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _getCategoryLabel(EventCategory category) {
    final keys = {
      EventCategory.sports: 'event_category_sports',
      EventCategory.outdoor: 'event_category_outdoor',
      EventCategory.education: 'event_category_education',
      EventCategory.arts: 'event_category_arts',
      EventCategory.socialGathering: 'event_category_social',
      EventCategory.other: 'event_category_other',
    };
    return context.tr(keys[category] ?? 'event_category_other');
  }

  String _getAgeGroupLabel(AgeGroup ageGroup) {
    final keys = {
      AgeGroup.infant: 'event_age_infant',
      AgeGroup.toddler: 'event_age_toddler',
      AgeGroup.preschool: 'event_age_preschool',
      AgeGroup.elementary: 'event_age_elementary',
      AgeGroup.teenager: 'event_age_teenager',
      AgeGroup.mixed: 'event_age_mixed',
    };
    final key = keys[ageGroup];
    return key == null ? '' : context.tr(key);
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
