import 'dart:math' as math;
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/models/event_participation.dart';

double? eventDistanceKm(
  double? lat1,
  double? lon1,
  double? lat2,
  double? lon2,
) {
  if (!validCoordinates(lat1, lon1) || !validCoordinates(lat2, lon2)) {
    return null;
  }
  final latitudeDelta = (lat2! - lat1!) * math.pi / 180;
  final longitudeDelta = (lon2! - lon1!) * math.pi / 180;
  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return 12742 * math.asin(math.sqrt(haversine.clamp(0, 1)));
}

bool eventMatchesAges(Iterable<AgeGroup> known, Iterable<AgeGroup> selected) =>
    selected.isEmpty ||
    known.isEmpty ||
    known.contains(AgeGroup.mixed) ||
    selected.contains(AgeGroup.mixed) ||
    known.any(selected.contains);

List<AgeGroup> eventAgesFromLabel(String label) {
  final text = label.toLowerCase();
  if (RegExp(r'alle|famil|mixed|all ages').hasMatch(text)) {
    return [AgeGroup.mixed];
  }
  final groups = <AgeGroup>{};
  if (RegExp(r'baby|infant|säug').hasMatch(text)) groups.add(AgeGroup.infant);
  if (RegExp(r'kleinkind|toddler').hasMatch(text)) groups.add(AgeGroup.toddler);
  if (RegExp(r'vorschul|preschool').hasMatch(text)) {
    groups.add(AgeGroup.preschool);
  }
  if (RegExp(r'grundschul|elementary').hasMatch(text)) {
    groups.add(AgeGroup.elementary);
  }
  if (RegExp(r'teen|jugend').hasMatch(text)) groups.add(AgeGroup.teenager);
  final range = RegExp(r'(\d{1,2})\s*[-–]\s*(\d{1,2})').firstMatch(text);
  final numbers = RegExp(
    r'\b\d{1,2}\b',
  ).allMatches(text).map((match) => int.parse(match.group(0)!)).toList();
  final minimum = range != null
      ? int.parse(range.group(1)!)
      : (numbers.isEmpty ? null : numbers.first);
  final maximum = range != null ? int.parse(range.group(2)!) : minimum;
  if (minimum != null && maximum != null && maximum >= minimum) {
    const bounds = [(0, 1), (1, 3), (4, 6), (6, 10), (11, 18)];
    for (var index = 0; index < bounds.length; index++) {
      if (minimum <= bounds[index].$2 && maximum >= bounds[index].$1) {
        groups.add(AgeGroup.values[index]);
      }
    }
  }
  return groups.toList();
}

bool eventMatchesTime(DateTime? date, String window, DateTime now) {
  if (date == null) return window == 'all';
  final local = date.toLocal();
  final today = now.toLocal();
  final startOfToday = DateTime(today.year, today.month, today.day);
  // Ein Event gilt erst dann als "vergangen", wenn sein Tag vor heute liegt.
  // So bleiben heute stattfindende Events den ganzen Tag sichtbar — auch wenn
  // ihr Datum nur den Tag (00:00) trägt (häufig bei KI-Funden) und die aktuelle
  // Uhrzeit bereits weiter ist.
  if (local.isBefore(startOfToday)) return false;
  if (window == 'today') {
    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }
  if (window == 'weekend') {
    return date.isBefore(now.add(const Duration(days: 7))) &&
        (local.weekday == DateTime.saturday ||
            local.weekday == DateTime.sunday);
  }
  return true;
}

double eventRankingScore({
  required double? distance,
  required DateTime? date,
  required Iterable<AgeGroup> ages,
  required Iterable<AgeGroup> selected,
  required DateTime now,
}) {
  final timeScore = date == null
      ? 0.0
      : (30 - date.difference(now).inMilliseconds / Duration.millisecondsPerDay)
                .clamp(0, 30) *
            2;
  final proximityScore = distance == null ? 0.0 : (50 - distance).clamp(0, 50);
  final ageScore =
      selected.isNotEmpty && ages.isNotEmpty && eventMatchesAges(ages, selected)
      ? 20
      : 0;
  return (timeScore + proximityScore + ageScore).toDouble();
}

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

      return eventMatchesAges(event.ageGroups, ageGroups ?? const []) &&
          eventMatchesTime(event.eventDate, 'all', DateTime.now());
    }).toList();

    return visible;
  }

  Future<List<MeetupEvent>> getFilteredDiscoverableEventsForUser({
    required String viewerUserId,
    required double viewerLatitude,
    required double viewerLongitude,
    List<AgeGroup>? ageGroups,
    double radiusKm = 25,
    bool nearbyOnly = false,
    bool onlyFree = false,
    String timeWindow = 'all',
  }) async {
    final remote = _backend.isEnabled
        ? await _backend.discoverEventsForUser(
            viewerUserId: viewerUserId,
            viewerLatitude: viewerLatitude,
            viewerLongitude: viewerLongitude,
            ageGroups: ageGroups,
            radiusKm: radiusKm,
            nearbyOnly: nearbyOnly,
            onlyFree: onlyFree,
            timeWindow: timeWindow,
            throwOnFailure: true,
          )
        : await getDiscoverableEventsForUser(
            viewerUserId: viewerUserId,
            viewerLatitude: viewerLatitude,
            viewerLongitude: viewerLongitude,
            ageGroups: ageGroups,
          );
    if (_backend.isEnabled) _syncFromRemoteEvents(remote);
    final now = DateTime.now();
    final selected = ageGroups ?? const <AgeGroup>[];
    double? distance(MeetupEvent event) => eventDistanceKm(
      viewerLatitude,
      viewerLongitude,
      event.latitude,
      event.longitude,
    );
    final filtered = remote.where((event) {
      final km = distance(event);
      return event.status == EventStatus.active &&
          eventMatchesTime(event.eventDate, timeWindow, now) &&
          eventMatchesAges(event.ageGroups, selected) &&
          (!onlyFree || event.price == 0) &&
          (km == null
              ? !nearbyOnly
              : km <= radiusKm &&
                    (!nearbyOnly || km <= 10) &&
                    (event.visibility != EventVisibility.publicNearby ||
                        event.hosterId == viewerUserId ||
                        km <= (event.shareRadiusKm ?? 25)));
    }).toList();
    filtered.sort((first, second) {
      final comparison =
          eventRankingScore(
            distance: distance(second),
            date: second.eventDate,
            ages: second.ageGroups,
            selected: selected,
            now: now,
          ).compareTo(
            eventRankingScore(
              distance: distance(first),
              date: first.eventDate,
              ages: first.ageGroups,
              selected: selected,
              now: now,
            ),
          );
      return comparison != 0 ? comparison : first.id.compareTo(second.id);
    });
    return filtered;
  }

  Future<List<EventInvitation>> getInvitationsForUser(String userId) async {
    if (_backend.isEnabled) {
      final remote = await _backend.fetchInvitationsForUser(
        userId,
        throwOnFailure: true,
      );
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
      if (!event.hasReliableCoordinates ||
          !validCoordinates(latitude, longitude)) {
        return false;
      }
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

      return eventMatchesAges(event.ageGroups, ageGroups ?? const []) &&
          event.status == EventStatus.active &&
          eventMatchesTime(event.eventDate, 'all', DateTime.now());
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
    if (!event.hasReliableCoordinates ||
        !validCoordinates(viewerLatitude, viewerLongitude)) {
      return true;
    }
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
    return eventDistanceKm(lat1, lon1, lat2, lon2) ?? double.nan;
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
