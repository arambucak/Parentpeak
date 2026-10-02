import 'dart:math' as math;
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/models/event_participation.dart';

class EventService {
  EventService({EventBackendService? backend})
    : _backend = backend ?? EventBackendService();

  final _familyCircleService = FamilyCircleService.instance;
  final EventBackendService _backend;

  static final List<MeetupEvent> _cachedEvents = [];

  static final List<EventParticipation> _cachedParticipations = [];
  static final List<EventInvitation> _cachedInvitations = [];
  static final Map<String, String> _eventInviteCodes = {};
  static final Map<String, DateTime> _eventInviteExpiresAt = {};

  Never _throwBackendRequired(String action) {
    throw StateError(
      _backend.lastSyncError ??
          '$action ist aktuell nicht mit dem Backend verbunden.',
    );
  }

  // Hole alle Events
  Future<List<MeetupEvent>> getEvents() async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchEvents(
        status: EventStatus.active.name,
        throwOnFailure: true,
      );
      _syncFromRemoteEvents(remote);
      return remote;
    }

    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simuliere API-Latenz
    return _cachedEvents.where((e) => e.status == EventStatus.active).toList();
  }

  /// Events für den aktuellen Nutzer mit Sichtbarkeits- und Standortregeln.
  Future<List<MeetupEvent>> getDiscoverableEventsForUser({
    required String viewerUserId,
    required double viewerLatitude,
    required double viewerLongitude,
    List<AgeGroup>? ageGroups,
  }) async {
    if (_backend.isEnabled) {
      final remote = await _backend.discoverEventsForUser(
        viewerUserId: viewerUserId,
        viewerLatitude: viewerLatitude,
        viewerLongitude: viewerLongitude,
        ageGroups: ageGroups,
        throwOnFailure: true,
      );
      _syncFromRemoteEvents(remote);
      return remote;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final visible = _cachedEvents.where((event) {
      if (event.status != EventStatus.active) return false;

      final canSee = _canUserSeeEvent(
        event: event,
        viewerUserId: viewerUserId,
        viewerLatitude: viewerLatitude,
        viewerLongitude: viewerLongitude,
      );
      if (!canSee) return false;

      if (ageGroups != null && ageGroups.isNotEmpty) {
        final hasMatchingAgeGroup = event.ageGroups.any(
          (eg) => ageGroups.contains(eg),
        );
        if (!hasMatchingAgeGroup) return false;
      }

      return true;
    }).toList();

    return visible;
  }

  Future<List<EventInvitation>> getInvitationsForUser(String userId) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchInvitationsForUser(userId,
          throwOnFailure: true);
      _syncFromRemoteInvitations(remote);
      return remote;
    }

    await Future.delayed(const Duration(milliseconds: 220));
    return _cachedInvitations.where((i) => i.invitedUserId == userId).toList();
  }

  Future<void> respondToInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Einladung antworten');
    }

    final remote = await _backend.respondToInvitation(
      invitationId: invitationId,
      accept: accept,
    );
    if (remote == null) {
      _throwBackendRequired('Einladung antworten');
    }

    _mergeRemoteInvitation(remote);
  }

  String? getInviteCodeForEvent(String eventId) => _eventInviteCodes[eventId];

  String? getInviteLinkForEvent(String eventId) {
    final code = _eventInviteCodes[eventId];
    if (code == null) return null;
    final encoded = Uri.encodeComponent(code);
    return 'parentpeak://invite?code=$encoded';
  }

  DateTime? getInviteExpiryForEvent(String eventId) =>
      _eventInviteExpiresAt[eventId];

  bool isInviteCodeExpired(String eventId) {
    final expiry = _eventInviteExpiresAt[eventId];
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  bool isInviteInputExpired(String input) {
    final normalizedInput = _extractCodeFromInput(input);
    if (normalizedInput.isEmpty) return false;

    String? eventId;
    for (final entry in _eventInviteCodes.entries) {
      if (entry.value.toUpperCase() == normalizedInput.toUpperCase()) {
        eventId = entry.key;
        break;
      }
    }

    if (eventId == null) return false;
    return isInviteCodeExpired(eventId);
  }

  Future<EventInvitation?> joinEventByInviteCode({
    required String code,
    required String userId,
  }) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Einladungscode einlösen');
    }

    final remote = await _backend.joinByCode(code: code, userId: userId);
    if (remote == null) {
      return null;
    }

    _mergeRemoteInvitation(remote);
    return remote;
  }

  // Hole Events nach Entfernung gefiltert
  Future<List<MeetupEvent>> getNearbyEvents({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    List<AgeGroup>? ageGroups,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return _cachedEvents.where((event) {
      // Berechne Entfernung (vereinfachte Haversine-Formel)
      final distance = _calculateDistance(
        latitude,
        longitude,
        event.latitude,
        event.longitude,
      );

      if (distance > radiusKm) return false;

      if (event.visibility == EventVisibility.privateOnly ||
          event.visibility == EventVisibility.familyCircle ||
          event.visibility == EventVisibility.inviteOnly) {
        return false;
      }

      final shareRadius = event.shareRadiusKm ?? radiusKm;
      if (distance > shareRadius) return false;

      if (ageGroups != null && ageGroups.isNotEmpty) {
        final hasMatchingAgeGroup = event.ageGroups.any(
          (eg) => ageGroups.contains(eg),
        );
        if (!hasMatchingAgeGroup) return false;
      }

      return event.status == EventStatus.active;
    }).toList();
  }

  bool _canUserSeeEvent({
    required MeetupEvent event,
    required String viewerUserId,
    required double viewerLatitude,
    required double viewerLongitude,
  }) {
    // Eigene Events sind immer sichtbar (auch private).
    if (event.hosterId == viewerUserId) return true;

    if (event.visibility == EventVisibility.privateOnly) {
      return false;
    }

    if (event.visibility == EventVisibility.familyCircle) {
      return _familyCircleService.areUsersConnected(
        userA: event.hosterId,
        userB: viewerUserId,
      );
    }

    if (event.visibility == EventVisibility.inviteOnly) {
      final invite = _cachedInvitations.where(
        (i) =>
            i.eventId == event.id &&
            i.invitedUserId == viewerUserId &&
            i.status == EventInvitationStatus.accepted,
      );
      return invite.isNotEmpty;
    }

    // Öffentlich: nur im definierten Radius teilen.
    final distance = _calculateDistance(
      viewerLatitude,
      viewerLongitude,
      event.latitude,
      event.longitude,
    );
    final shareRadius = event.shareRadiusKm ?? 25;
    return distance <= shareRadius;
  }

  // Hole Event Details
  Future<MeetupEvent?> getEventById(String eventId) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchEventById(eventId);
      if (remote != null) {
        _mergeRemoteEvent(remote);
        return remote;
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _cachedEvents.firstWhere((e) => e.id == eventId);
    } catch (e) {
      return null;
    }
  }

  // Erstelle ein neues Event
  Future<MeetupEvent> createEvent(MeetupEvent event) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Event erstellen');
    }

    final remote = await _backend.createEvent(event);
    if (remote == null) {
      _throwBackendRequired('Event erstellen');
    }

    _mergeRemoteEvent(remote);
    if (remote.inviteCodeExpiresAt != null) {
      _eventInviteExpiresAt[remote.id] = remote.inviteCodeExpiresAt!;
    }
    return remote;
  }

  // Lösche ein Event
  Future<MeetupEvent> updateEvent(
    String eventId,
    Map<String, dynamic> fields, {
    required String requestingUserId,
  }) async {
    if (!_backend.isEnabled) _throwBackendRequired('Event bearbeiten');
    final updated = await _backend.updateEvent(
      eventId,
      fields,
      requestingUserId: requestingUserId,
    );
    if (updated == null ||
        updated.id != eventId ||
        updated.hosterId != requestingUserId) {
      _throwBackendRequired('Event bearbeiten');
    }
    _mergeRemoteEvent(updated);
    return updated;
  }

  Future<bool> deleteEvent(String eventId, {String? requestingUserId}) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Event löschen');
    }

    final actingUserId =
        requestingUserId ?? AuthService.instance.currentUser?.uid;
    if (actingUserId == null || actingUserId.trim().isEmpty) {
      _throwBackendRequired('Event löschen');
    }
    final removed = await _backend.deleteEvent(eventId, hosterId: actingUserId);
    if (!removed) {
      _throwBackendRequired('Event löschen');
    }

    _cachedEvents.removeWhere((e) => e.id == eventId);
    _cachedInvitations.removeWhere((i) => i.eventId == eventId);
    _cachedParticipations.removeWhere((p) => p.eventId == eventId);
    _eventInviteCodes.remove(eventId);
    _eventInviteExpiresAt.remove(eventId);
    return true;
  }

  // Hole Partizipationen für einen User
  Future<List<EventParticipation>> getUserParticipations(String userId) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchUserParticipations(userId);
      if (remote.isNotEmpty) {
        _syncFromRemoteParticipations(remote);
        return remote;
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return _cachedParticipations.where((p) => p.userId == userId).toList();
  }

  // Hole ausstehende Anfragen für einen Host
  Future<List<EventParticipation>> getPendingRequestsForHost(
    String hosterId,
  ) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchPendingRequestsForHost(hosterId);
      if (remote.isNotEmpty) {
        _syncFromRemoteParticipations(remote);
        return remote;
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final hostEvents = _cachedEvents
        .where((e) => e.hosterId == hosterId)
        .toList();
    final hostEventIds = hostEvents.map((e) => e.id).toList();

    return _cachedParticipations
        .where(
          (p) =>
              hostEventIds.contains(p.eventId) &&
              p.status == ParticipationStatus.pending,
        )
        .toList();
  }

  // Entfernung berechnen (in km)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // math.pi / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  String _extractCodeFromInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final asUri = Uri.tryParse(trimmed);
    if (asUri != null && asUri.queryParameters.containsKey('code')) {
      return (asUri.queryParameters['code'] ?? '').trim();
    }

    return trimmed;
  }

  Future<List<MeetupEvent>> getHostedInviteOnlyEvents(String hostUserId) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchHostedInviteOnlyEvents(hostUserId);
      if (remote.isNotEmpty) {
        _syncFromRemoteEvents(remote);
        return remote;
      }
    }

    await Future.delayed(const Duration(milliseconds: 220));
    return _cachedEvents
        .where(
          (e) =>
              e.hosterId == hostUserId &&
              e.status == EventStatus.active &&
              e.visibility == EventVisibility.inviteOnly,
        )
        .toList();
  }

  Future<List<EventInvitation>> getAcceptedInvitationsForEvent(
    String eventId,
  ) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchAcceptedInvitationsForEvent(eventId);
      if (remote.isNotEmpty) {
        _syncFromRemoteInvitations(remote);
        return remote;
      }
    }

    await Future.delayed(const Duration(milliseconds: 220));
    return _cachedInvitations
        .where(
          (i) =>
              i.eventId == eventId &&
              i.status == EventInvitationStatus.accepted,
        )
        .toList();
  }

  void _syncFromRemoteEvents(List<MeetupEvent> events) {
    for (final event in events) {
      _mergeRemoteEvent(event);
    }
  }

  void _mergeRemoteEvent(MeetupEvent event) {
    final index = _cachedEvents.indexWhere((e) => e.id == event.id);
    if (index == -1) {
      _cachedEvents.add(event);
    } else {
      _cachedEvents[index] = event;
    }
  }

  void _syncFromRemoteInvitations(List<EventInvitation> invitations) {
    for (final invitation in invitations) {
      _mergeRemoteInvitation(invitation);
    }
  }

  void _mergeRemoteInvitation(EventInvitation invitation) {
    final index = _cachedInvitations.indexWhere((i) => i.id == invitation.id);
    if (index == -1) {
      _cachedInvitations.add(invitation);
    } else {
      _cachedInvitations[index] = invitation;
    }
  }

  void _syncFromRemoteParticipations(List<EventParticipation> participations) {
    for (final participation in participations) {
      final index = _cachedParticipations.indexWhere(
        (p) => p.id == participation.id,
      );
      if (index == -1) {
        _cachedParticipations.add(participation);
      } else {
        _cachedParticipations[index] = participation;
      }
    }
  }
}
