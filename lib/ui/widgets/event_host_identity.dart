import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/user_profile_service.dart';
import 'package:parentpeak/ui/widgets/user_avatar.dart';

class EventHostProfile {
  const EventHostProfile({this.name = '', this.photoUrl});
  final String name;
  final String? photoUrl;
}

/// Beziehung der angezeigten Person zum Event.
enum EventHostRelation {
  /// Veranstaltet das Event selbst (z.B. eigenes Eltern-Treffen) → „Gastgeber".
  host,

  /// Teilt ein offenes Angebot (interest-Modus) → „Geteilt von".
  sharedOffer,

  /// Hat eine (oft fremde) Veranstaltung nur in die Community eingetragen
  /// → „Eingetragen von". Vermeidet die irreführende Gastgeber-Behauptung.
  submittedBy,
}

/// Liefert den i18n-Key für das Beziehungs-Label einer Event-Karte.
String eventHostLabelKey(EventHostRelation relation) {
  switch (relation) {
    case EventHostRelation.host:
      return 'event_host';
    case EventHostRelation.sharedOffer:
      return 'event_shared_by';
    case EventHostRelation.submittedBy:
      return 'event_submitted_by';
  }
}

class EventHostIdentity extends StatefulWidget {
  const EventHostIdentity({
    super.key,
    required this.userId,
    this.relation = EventHostRelation.host,
    this.loadProfile,
  });

  final String userId;
  final EventHostRelation relation;
  final Future<EventHostProfile> Function(String userId)? loadProfile;

  @override
  State<EventHostIdentity> createState() => _EventHostIdentityState();
}

class _EventHostIdentityState extends State<EventHostIdentity> {
  EventHostProfile _profile = const EventHostProfile();
  String? _sessionId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_sessionChanged);
    _load();
  }

  @override
  void didUpdateWidget(EventHostIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.loadProfile != widget.loadProfile) {
      _load();
    }
  }

  void _sessionChanged() {
    if (_sessionId != AuthService.instance.currentUser?.uid) {
      _load();
    }
    if (mounted) setState(() {});
  }

  Future<EventHostProfile> _lookup(String uid) async {
    final service = UserProfileService.instance;
    final ownName = AuthService.instance.currentUser?.uid == uid
        ? AuthService.instance.currentUser?.displayName.trim()
        : null;
    final results = await Future.wait<Object?>([
      if (ownName == null)
        service.displayNameFor(uid)
      else
        Future.value(ownName),
      service.avatarUrlFor(uid),
    ]);
    return EventHostProfile(
      name: results[0] as String? ?? '',
      photoUrl: results[1] as String?,
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _profile = const EventHostProfile();
    _sessionId = AuthService.instance.currentUser?.uid;
    if (_sessionId == null ||
        _sessionId!.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(widget.userId)) {
      return;
    }
    try {
      final profile = await (widget.loadProfile ?? _lookup)(widget.userId);
      if (!mounted ||
          generation != _generation ||
          _sessionId != AuthService.instance.currentUser?.uid) {
        return;
      }
      setState(() => _profile = profile);
    } catch (_) {
      if (mounted && generation == _generation) setState(() {});
    }
  }

  @override
  void dispose() {
    _generation++;
    AuthService.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownUser = AuthService.instance.currentUser;
    final name = (ownUser?.uid == widget.userId
            ? ownUser?.displayName ?? ''
            : _profile.name)
        .trim();
    final safeName = name == widget.userId ? '' : name;
    final label = context.tr(eventHostLabelKey(widget.relation));
    return Row(
      key: const Key('event-host-identity'),
      children: [
        UserAvatar(name: safeName, photoUrl: _profile.photoUrl, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              if (safeName.isNotEmpty)
                Text(
                  safeName,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
