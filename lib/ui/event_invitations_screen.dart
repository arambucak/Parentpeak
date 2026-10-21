import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/family_contact.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class EventInvitationsScreen extends StatefulWidget {
  final String? initialInviteInput;

  const EventInvitationsScreen({super.key, this.initialInviteInput});

  @override
  State<EventInvitationsScreen> createState() => _EventInvitationsScreenState();
}

class _EventInvitationsScreenState extends State<EventInvitationsScreen> {
  final _eventService = EventService();
  final _familyCircleService = FamilyCircleService.instance;
  final _codeCtrl = TextEditingController();

  List<EventInvitation> _invitations = [];
  Map<String, MeetupEvent> _eventsById = {};
  List<MeetupEvent> _hostedInviteEvents = [];
  Map<String, List<EventInvitation>> _acceptedByEvent = {};
  Map<String, FamilyContact> _contactsById = {};
  bool _isLoading = true;
  String? _errorMessage;

  String? get _currentUserId => AuthService.instance.currentUser?.uid;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  @override
  void initState() {
    super.initState();
    final initialInput = widget.initialInviteInput?.trim();
    if (initialInput != null && initialInput.isNotEmpty) {
      _codeCtrl.text = initialInput;
    }
    _load();
    if (initialInput != null && initialInput.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinByCode();
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _invitations = [];
        _eventsById = {};
        _hostedInviteEvents = [];
        _acceptedByEvent = {};
        _contactsById = {};
        _errorMessage = _t('event_login_required');
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final invites = await _eventService.getInvitationsForUser(currentUserId);
    final hosted = await _eventService.getHostedInviteOnlyEvents(currentUserId);
    final contacts =
        await _familyCircleService.getConnectedContacts(userId: currentUserId);

    final map = <String, MeetupEvent>{};
    for (final i in invites) {
      final event = await _eventService.getEventById(i.eventId);
      if (event != null) {
        map[i.eventId] = event;
      }
    }

    for (final event in hosted) {
      map[event.id] = event;
    }

    final acceptedByEvent = <String, List<EventInvitation>>{};
    for (final event in hosted) {
      acceptedByEvent[event.id] =
          await _eventService.getAcceptedInvitationsForEvent(event.id);
    }

    if (!mounted) return;
    setState(() {
      _invitations = invites;
      _eventsById = map;
      _hostedInviteEvents = hosted;
      _acceptedByEvent = acceptedByEvent;
      _contactsById = {for (final c in contacts) c.userId: c};
      _errorMessage = null;
      _isLoading = false;
    });
  }

  Future<void> _respond(EventInvitation invite, bool accept) async {
    await _eventService.respondToInvitation(
      invitationId: invite.id,
      accept: accept,
    );

    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _t(accept ? 'package3_accept_saved' : 'package3_decline_saved')),
      ),
    );
  }

  Future<void> _joinByCode() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) return;
    final input = _codeCtrl.text.trim();
    if (input.isEmpty) return;

    final invite = await _eventService.joinEventByInviteCode(
      code: input,
      userId: currentUserId,
    );

    if (!mounted) return;

    if (invite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _eventService.isInviteInputExpired(input)
                ? _t('package3_code_expired')
                : _t('package3_code_not_found'),
          ),
        ),
      );
      return;
    }

    _codeCtrl.clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('package3_join_now'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _invitations
        .where((i) => i.status == EventInvitationStatus.pending)
        .toList();
    final accepted = _invitations
        .where((i) => i.status == EventInvitationStatus.accepted)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('package3_invitations')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
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
                              _t('package3_invitations'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t('package3_join_now'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _CountPill(
                                    icon: Icons.mark_email_unread_rounded,
                                    label: AppStringsManager.getString(languageService.currentLanguage, 'events_invitation_pending'),
                                    value: pending.length.toString(),
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _CountPill(
                                    icon: Icons.check_circle_outline_rounded,
                                    label: AppStringsManager.getString(languageService.currentLanguage, 'events_invitation_accepted'),
                                    value: accepted.length.toString(),
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _CountPill(
                                    icon: Icons.celebration_rounded,
                                    label: _t('package3_my_events'),
                                    value:
                                        _hostedInviteEvents.length.toString(),
                                    color: const Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE4FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('package3_code'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _codeCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: _t('package3_code_not_found'),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _joinByCode,
                                  child: Text(AppStringsManager.getString(languageService.currentLanguage, 'start')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: AppStringsManager.getString(languageService.currentLanguage, 'events_invitation_pending'),
                        subtitle: pending.isEmpty
                          ? _t('package3_nothing_pending')
                          : _t('package3_pending_count')
                            .replaceAll('{count}', '${pending.length}'),
                      ),
                      const SizedBox(height: 8),
                      if (pending.isEmpty)
                        _EmptyTile(
                          icon: Icons.inbox_rounded,
                          text: _t('package3_all_answered'),
                        )
                      else
                        ...pending.map(
                          (i) {
                            final event = _eventsById[i.eventId];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PendingInviteRow(
                                title: event?.title ?? _t('package3_event_fallback'),
                                subtitle: event?.location ?? _t('package3_unknown_location'),
                                onDecline: () => _respond(i, false),
                                onAccept: () => _respond(i, true),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: AppStringsManager.getString(languageService.currentLanguage, 'events_invitation_accepted'),
                        subtitle: accepted.isEmpty
                          ? _t('package3_none_yet')
                          : _t('package3_active_count')
                            .replaceAll('{count}', '${accepted.length}'),
                      ),
                      const SizedBox(height: 8),
                      if (accepted.isEmpty)
                        _EmptyTile(
                          icon: Icons.check_circle_outline_rounded,
                          text: _t('package3_no_active_acceptances'),
                        )
                      else
                        ...accepted.map(
                          (i) {
                            final event = _eventsById[i.eventId];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SimpleInviteRow(
                                icon: Icons.check_circle_outline_rounded,
                                title: event?.title ?? _t('package3_event_fallback'),
                                subtitle: event?.location ?? _t('package3_unknown_location'),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: _t('package3_as_host'),
                        subtitle: _hostedInviteEvents.isEmpty
                          ? _t('package3_no_events')
                          : _t('package3_events_count').replaceAll(
                            '{count}', '${_hostedInviteEvents.length}'),
                      ),
                      const SizedBox(height: 8),
                      if (_hostedInviteEvents.isEmpty)
                        _EmptyTile(
                          icon: Icons.celebration_outlined,
                          text: _t('package3_no_private_events'),
                        )
                      else
                        ..._hostedInviteEvents.map((event) {
                          final acceptedList =
                              _acceptedByEvent[event.id] ?? const [];
                          final code =
                              _eventService.getInviteCodeForEvent(event.id) ??
                                  '-';
                          final expiry =
                              _eventService.getInviteExpiryForEvent(event.id);
                          final expired =
                              _eventService.isInviteCodeExpired(event.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(_t('package3_code')
                                    .replaceAll('{code}', code)),
                                if (expiry != null)
                                  Text(
                                    _t('package3_valid_until').replaceAll(
                                      '{date}',
                                      '${expiry.day.toString().padLeft(2, '0')}.${expiry.month.toString().padLeft(2, '0')}.${expiry.year}${expired ? _t('package3_expired_suffix') : ''}',
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  _t('package3_acceptances_count').replaceAll(
                                    '{count}', '${acceptedList.length}'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                if (acceptedList.isEmpty)
                                  Text(
                                    _t('package3_no_acceptances_yet'),
                                    style: const TextStyle(color: Colors.black54),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: acceptedList.map((invite) {
                                      final contact =
                                          _contactsById[invite.invitedUserId];
                                      return Chip(
                                        label: Text(
                                          contact?.displayName ??
                                              invite.invitedUserId,
                                        ),
                                        avatar: const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 16,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingInviteRow extends StatelessWidget {
  const _PendingInviteRow({
    required this.title,
    required this.subtitle,
    required this.onDecline,
    required this.onAccept,
  });

  final String title;
  final String subtitle;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final language = languageService.currentLanguage;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: Text(AppStringsManager.getString(
                      language, 'package3_decline_saved')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: Text(AppStringsManager.getString(
                      language, 'package3_accept_saved')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleInviteRow extends StatelessWidget {
  const _SimpleInviteRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
