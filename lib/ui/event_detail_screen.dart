import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/participation_service.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/meetup_chat_screen.dart';
import 'package:parentpeak/ui/event_edit_sheet.dart';
import 'package:parentpeak/models/event_participation.dart';
import 'package:parentpeak/ui/widgets/event_photo.dart';
import 'package:parentpeak/ui/widgets/event_host_identity.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatefulWidget {
  final MeetupEvent event;
  final EventService? eventService;
  final EventBackendService? backendService;
  final ParticipationService? participationService;
  final Future<bool> Function(Uri)? openOrganizerUrl;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.eventService,
    this.backendService,
    this.participationService,
    this.openOrganizerUrl,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final ParticipationService _participationService;
  late final EventBackendService _eventBackendService;
  late final EventService _eventService;
  late MeetupEvent _event;
  bool _ownerBusy = false;
  bool _hasRequested = false;
  bool _isApproved = false;
  bool _isDeclined = false;
  bool _isLoading = false;
  bool _requiresSignIn = false;
  bool _isInterested = false;
  bool _statusLoading = true;
  bool _statusFailed = false;

  // Serie folgen (Issue #47) — nur relevant, wenn das Event zu einer Serie
  // gehört (event.seriesId != null).
  bool _isFollowingSeries = false;
  bool _followBusy = false;

  String? get _currentUserId => AuthService.instance.currentUser?.uid;
  bool get _isOwner =>
      _currentUserId != null &&
      _currentUserId!.trim().isNotEmpty &&
      _currentUserId == _event.hosterId;

  bool get _hasSeries => _event.seriesId != null && _event.seriesId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _eventService = widget.eventService ?? EventService();
    _eventBackendService = widget.backendService ?? EventBackendService();
    _participationService =
        widget.participationService ??
        ParticipationService(backendService: _eventBackendService);
    _checkParticipationStatus();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    if (!_hasSeries || _isOwner) return;
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) return;
    final following = await _eventBackendService.isFollowingSeries(
      seriesId: _event.seriesId!,
      userId: uid,
    );
    if (!mounted || following == null) return;
    setState(() => _isFollowingSeries = following);
  }

  Future<void> _toggleFollowSeries() async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_series_sign_in_required'))),
      );
      return;
    }
    if (!_hasSeries || _followBusy || _isOwner) return;
    setState(() => _followBusy = true);
    final wasFollowing = _isFollowingSeries;
    var ok = false;
    try {
      ok = wasFollowing
          ? await _eventBackendService.unfollowSeries(
              seriesId: _event.seriesId!,
              userId: uid,
            )
          : await _eventBackendService.followSeries(
              seriesId: _event.seriesId!,
              userId: uid,
            );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _followBusy = false;
      if (ok) _isFollowingSeries = !wasFollowing;
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFollowingSeries
                ? context.tr('event_series_followed')
                : context.tr('event_series_unfollowed'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_action_failed'))),
      );
    }
  }

  Future<void> _checkParticipationStatus() async {
    if (_isOwner) {
      _statusLoading = false;
      return;
    }
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _requiresSignIn = true;
        _statusLoading = false;
      });
      return;
    }

    setState(() {
      _statusLoading = true;
      _statusFailed = false;
    });
    try {
      final participation = await _participationService
          .getParticipationByUserAndEvent(
            userId: currentUserId,
            eventId: _event.id,
          );

      if (!mounted) return;
      setState(() {
        _applyParticipation(participation);
        _statusLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusFailed = true;
          _statusLoading = false;
        });
      }
    }
  }

  void _applyParticipation(EventParticipation? participation) {
    _isApproved = participation?.status == ParticipationStatus.approved;
    _isDeclined = participation?.status == ParticipationStatus.declined;
    _hasRequested = participation?.status == ParticipationStatus.pending;
    _isInterested = participation?.status == ParticipationStatus.interested;
    _requiresSignIn = false;
  }

  Future<void> _requestParticipation() async {
    if (_isOwner || _isLoading) return;
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
      final participation = await _participationService.requestParticipation(
        eventId: _event.id,
        userId: currentUserId,
      );

      if (!mounted) return;
      setState(() {
        _applyParticipation(participation);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              _isInterested
                  ? 'event_interest_saved'
                  : _isApproved
                  ? 'event_detail_registered'
                  : 'event_legacy_pending',
            ),
          ),
        ),
      );
      await _refreshEvent();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_action_failed'))),
      );
    }
  }

  Future<void> _refreshEvent() async {
    final updated = await _eventBackendService.fetchEventById(_event.id);
    if (mounted && updated != null) setState(() => _event = updated);
  }

  Future<void> _withdraw() async {
    final uid = _currentUserId;
    if (uid == null || _isLoading || _isOwner) return;
    setState(() => _isLoading = true);
    try {
      await _participationService.withdrawParticipation(
        eventId: _event.id,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {
        _applyParticipation(null);
        _isLoading = false;
      });
      await _refreshEvent();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_action_failed'))),
      );
    }
  }

  Future<void> _openOrganizer() async {
    final uri = _event.organizerUri;
    if (uri == null) return;
    try {
      final opened =
          await (widget.openOrganizerUrl?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_action_failed'))),
      );
    }
  }

  Widget _buildParticipationControls() {
    final closed =
        _event.status != EventStatus.active ||
        !_event.eventDate.isAfter(DateTime.now());
    final active = _isApproved || _isInterested || _hasRequested;
    const progress = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_event.isSharedOffer) ...[
          Text(context.tr('event_interest_not_booking')),
          const SizedBox(height: 12),
          if (_event.organizerUri != null)
            OutlinedButton.icon(
              key: const Key('event-organizer-link'),
              onPressed: _openOrganizer,
              icon: const Icon(Icons.open_in_new),
              label: Text(context.tr('event_open_organizer')),
            ),
        ],
        if (!_isOwner && _statusLoading)
          const Center(child: progress)
        else if (!_isOwner && _statusFailed) ...[
          Text(context.tr('event_status_failed')),
          TextButton.icon(
            key: const Key('event-status-retry'),
            onPressed: _checkParticipationStatus,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('event_retry')),
          ),
        ] else if (!_isOwner) ...[
          if (_hasRequested)
            _buildStatusBanner(
              icon: Icons.schedule,
              text: context.tr('event_legacy_pending'),
              bgColor: const Color(0xFFFFF3CD),
              textColor: const Color(0xFF735C0F),
            ),
          if (_isInterested || (_isApproved && _event.isSharedOffer))
            Text(context.tr('event_interest_saved')),
          if (_isApproved && !_event.isSharedOffer) ...[
            _buildStatusBanner(
              icon: Icons.check_circle_outline,
              text: context.tr('event_detail_registered'),
              bgColor: const Color(0xFFDCFCE7),
              textColor: const Color(0xFF166534),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeetupChatScreen(event: _event),
                ),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: Text(context.tr('event_detail_open_chat')),
            ),
          ],
          if (_isDeclined) Text(context.tr('event_detail_request_declined')),
          if (active)
            OutlinedButton.icon(
              key: const Key('event-withdraw'),
              onPressed: _isLoading ? null : _withdraw,
              icon: _isLoading ? progress : const Icon(Icons.undo),
              label: Text(
                context.tr(
                  _event.isSharedOffer
                      ? 'event_interest_withdraw'
                      : 'event_withdraw',
                ),
              ),
            )
          else
            FilledButton.icon(
              key: const Key('event-join'),
              onPressed:
                  closed || _event.isFull || _isLoading || _requiresSignIn
                  ? null
                  : _requestParticipation,
              icon: _isLoading
                  ? progress
                  : Icon(
                      _event.isSharedOffer
                          ? Icons.favorite_border
                          : Icons.person_add_alt_1,
                    ),
              label: Text(
                context.tr(
                  closed
                      ? 'event_closed'
                      : _event.isFull
                      ? 'status_full'
                      : switch (_event.participationMode) {
                          ParticipationMode.direct => 'event_join_direct',
                          ParticipationMode.interest => 'event_show_interest',
                          ParticipationMode.legacyApproval =>
                            'event_detail_request_participation',
                        },
                ),
              ),
            ),
        ],
      ],
    );
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
            EventPhoto(photoUrl: _event.photoUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _getCategoryLabel(_event.category),
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (_isOwner) _buildOwnerToolbar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _event.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_event.isSharedOffer && _event.hasCapacity)
                          Row(
                            children: [
                              Expanded(
                                child: _MetaPill(
                                  icon: Icons.people_outline_rounded,
                                  label: context.tr('event_places'),
                                  value:
                                      '${_event.currentParticipants}/${_event.maxParticipants}',
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetaPill(
                                  icon: Icons.schedule_rounded,
                                  label: context.tr('common_status'),
                                  value: context.tr(
                                    _event.isFull
                                        ? 'status_full'
                                        : 'status_open',
                                  ),
                                  color: _event.isFull
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
                  EventHostIdentity(
                    userId: _event.hosterId,
                    relation: _event.isSharedOffer
                        ? EventHostRelation.sharedOffer
                        : EventHostRelation.host,
                  ),
                  const SizedBox(height: 14),
                  _buildInfoTile(
                    icon: Icons.calendar_today,
                    title: MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_event.eventDate.toLocal()),
                    subtitle: TimeOfDay.fromDateTime(
                      _event.eventDate.toLocal(),
                    ).format(context),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoTile(
                    icon: Icons.location_on,
                    title: _event.location,
                    subtitle: _event.hasReliableCoordinates
                        ? '${_event.latitude.toStringAsFixed(3)}, ${_event.longitude.toStringAsFixed(3)}'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  if (!_event.isSharedOffer && _event.hasCapacity)
                    _buildInfoTile(
                      icon: Icons.people,
                      title: context.tr(
                        'event_detail_participants',
                        values: {
                          'current': _event.currentParticipants,
                          'maximum': _event.maxParticipants,
                        },
                      ),
                      subtitle: _event.spotsAvailable > 0
                          ? context.tr(
                              'event_detail_spots_available',
                              values: {'count': _event.spotsAvailable},
                            )
                          : context.tr('event_detail_fully_booked'),
                    ),
                  const SizedBox(height: 12),
                  _buildAgeGroupChips(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
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
                          _event.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_hasSeries && !_isOwner) ...[
                    _buildSeriesFollowCard(theme),
                    const SizedBox(height: 16),
                  ],
                  _buildParticipationControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerToolbar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              _event.isSharedOffer
                  ? 'event_shared_by_you'
                  : 'event_owner_yours',
            ),
            style: theme.textTheme.titleSmall,
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const Key('event-owner-edit'),
                  onPressed: _ownerBusy ? null : _editEvent,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('event_owner_edit')),
                ),
              ),
              PopupMenuButton<String>(
                key: const Key('event-owner-menu'),
                enabled: !_ownerBusy,
                tooltip: context.tr('event_owner_actions'),
                icon: const Icon(Icons.more_vert),
                onSelected: (_) => _deleteEvent(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('event_owner_delete')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editEvent() async {
    if (!_isOwner || _ownerBusy) return;
    setState(() => _ownerBusy = true);
    final updated = await showModalBottomSheet<MeetupEvent>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => EventEditSheet(
        event: _event,
        onSave: (fields) async {
          if (!_isOwner) throw StateError('Owner session changed');
          return _eventService.updateEvent(
            _event.id,
            fields,
            requestingUserId: _currentUserId!,
          );
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _ownerBusy = false;
      if (updated != null) _event = updated;
    });
    if (updated != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('event_owner_saved'))));
    }
  }

  Future<void> _deleteEvent() async {
    if (!_isOwner || _ownerBusy) return;
    setState(() => _ownerBusy = true);
    var busy = false;
    String? error;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(context.tr('event_owner_delete_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(
                    'event_owner_delete_message',
                    values: {'title': _event.title},
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('common_cancel')),
              ),
              TextButton.icon(
                key: const Key('event-delete-confirm'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: busy
                    ? null
                    : () async {
                        if (!_isOwner) return;
                        updateDialog(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final removed = await _eventService.deleteEvent(
                            _event.id,
                            requestingUserId: _currentUserId!,
                          );
                          if (!removed) {
                            throw StateError('Delete not acknowledged');
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            updateDialog(() {
                              busy = false;
                              error = context.tr('event_owner_delete_failed');
                            });
                          }
                        }
                      },
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(context.tr('event_owner_delete')),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _ownerBusy = false);
    if (deleted == true) Navigator.pop(context, true);
  }

  /// Karte für wiederkehrende Angebote: Eltern können der Serie folgen und
  /// werden dann über neue konkrete Termine benachrichtigt (Issue #47).
  Widget _buildSeriesFollowCard(ThemeData theme) {
    final following = _isFollowingSeries;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('event_series_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            following
                ? context.tr('event_series_following_hint')
                : context.tr('event_series_follow_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: following
                ? OutlinedButton.icon(
                    onPressed: _followBusy ? null : _toggleFollowSeries,
                    icon: _followBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.notifications_active_rounded,
                            size: 18,
                          ),
                    label: Text(context.tr('event_series_unfollow')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _followBusy ? null : _toggleFollowSeries,
                    icon: _followBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                          ),
                    label: Text(context.tr('event_series_follow')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
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
                if (subtitle != null)
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
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
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
          children: _event.ageGroups
              .map(
                (ageGroup) => Chip(
                  label: Text(_getAgeGroupLabel(ageGroup)),
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
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
