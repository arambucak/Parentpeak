import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/event_participation.dart';
import 'package:parentpeak/models/meetup_event.dart';

import 'backend_api_client.dart';
import 'backend_service_factory.dart';

class EventBackendService {
  EventBackendService({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _apiClient;
  String? lastSyncError;

  bool get isEnabled => _apiClient != null;

  String get _eventsPath => '/api/events';
  String get _invitationsPath => '/api/events/invitations';

  Future<List<MeetupEvent>> fetchEvents({
    String? status,
    String? hostUserId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_apiClient == null) return [];
    try {
      final query = <String, String>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (hostUserId != null && hostUserId.isNotEmpty) 'hosterId': hostUserId,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      final payload = await _apiClient!.getJson(_appendQuery(_eventsPath, query));
      if (payload is Map<String, dynamic> && payload.containsKey('events')) {
        return _parseEventList(payload['events']);
      }
      return _parseEventList(payload);
    } catch (e) {
      lastSyncError = 'Events konnten nicht geladen werden: $e';
      return [];
    }
  }

  Future<List<MeetupEvent>> discoverEventsForUser({
    required String viewerUserId,
    required double viewerLatitude,
    required double viewerLongitude,
    List<AgeGroup>? ageGroups,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_apiClient == null) return [];
    try {
      final query = <String, String>{
        'viewerUserId': viewerUserId,
        'latitude': viewerLatitude.toString(),
        'longitude': viewerLongitude.toString(),
        'radiusKm': '25',
        'limit': limit.toString(),
        'offset': offset.toString(),
        'status': 'upcoming',
        'visibility': 'publicNearby',
      };

      final payload = await _apiClient!.getJson(_appendQuery(_eventsPath, query));
      if (payload is Map<String, dynamic> && payload.containsKey('events')) {
        return _parseEventList(payload['events']);
      }
      return _parseEventList(payload);
    } catch (e) {
      lastSyncError = 'Event-Discovery fehlgeschlagen: $e';
      return [];
    }
  }

  Future<MeetupEvent?> fetchEventById(String id) async {
    if (_apiClient == null) return null;
    try {
      final payload = await _apiClient!.getJson('$_eventsPath/$id');
      if (payload is Map<String, dynamic> && payload.containsKey('event')) {
        return _parseSingleEvent(payload['event']);
      }
      return _parseSingleEvent(payload);
    } catch (e) {
      lastSyncError = 'Event konnte nicht geladen werden: $e';
      return null;
    }
  }

  Future<MeetupEvent?> createEvent(MeetupEvent event) async {
    if (_apiClient == null) return null;
    try {
      final eventData = {
        'hosterId': event.hosterId,
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'startDate': event.eventDate.toIso8601String(),
        'eventType': event.category.name,
        'visibility': event.visibility.name,
        'maxParticipants': event.maxParticipants,
        'imageUrl': event.photoUrl,
      };

      final payload = await _apiClient!.postJsonAny(_eventsPath, eventData);
      if (payload is Map<String, dynamic> && payload.containsKey('event')) {
        return _parseSingleEvent(payload['event']);
      }
      return _parseSingleEvent(payload);
    } catch (e) {
      lastSyncError = 'Event konnte nicht erstellt werden: $e';
      return null;
    }
  }

  Future<bool> deleteEvent(String id, {required String hosterId}) async {
    if (_apiClient == null) return false;
    try {
      await _apiClient!.delete('$_eventsPath/$id?hosterId=$hosterId');
      return true;
    } catch (e) {
      lastSyncError = 'Event konnte nicht gelöscht werden: $e';
      return false;
    }
  }

  Future<MeetupEvent?> updateEvent(
    String id,
    Map<String, dynamic> fields, {
    String? requestingUserId,
  }) async {
    if (_apiClient == null) return null;
    try {
      final body = <String, dynamic>{
        ...fields,
        if (requestingUserId != null) 'requestingUserId': requestingUserId,
      };
      final payload = await _apiClient!.putJson('$_eventsPath/$id', body);
      if (payload is Map<String, dynamic> && payload.containsKey('event')) {
        return _parseSingleEvent(payload['event']);
      }
      return _parseSingleEvent(payload);
    } catch (e) {
      lastSyncError = 'Event konnte nicht aktualisiert werden: $e';
      return null;
    }
  }

  /// Uploads an image file and returns the public URL, or null on failure.
  Future<String?> uploadImage(File imageFile) async {
    if (_apiClient == null) return null;
    try {
      final baseUrl = _apiClient!.baseUrl;
      final uri = Uri.parse('$baseUrl/uploads/image');
      final request = http.MultipartRequest('POST', uri);
      if (_apiClient!.authToken != null && _apiClient!.authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${_apiClient!.authToken}';
      }
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return decoded['url']?.toString();
      }
      lastSyncError = 'Bild-Upload fehlgeschlagen: ${streamed.statusCode}';
      return null;
    } catch (e) {
      lastSyncError = 'Bild-Upload fehlgeschlagen: $e';
      return null;
    }
  }

  Future<List<EventInvitation>> fetchInvitationsForUser(String userId) async {
    if (_apiClient == null) return [];
    try {
      final payload = await _apiClient!
          .getJson(_appendQuery(_invitationsPath, {'userId': userId}));
      return _parseInvitationList(payload);
    } catch (e) {
      lastSyncError = 'Einladungen konnten nicht geladen werden: $e';
      return [];
    }
  }

  Future<EventInvitation?> respondToInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    if (_apiClient == null) return null;
    try {
      final payload = await _apiClient!.putJson(
        '$_invitationsPath/$invitationId/respond',
        {'accept': accept},
      );
      return _parseSingleInvitation(payload);
    } catch (e) {
      lastSyncError = 'Einladung konnte nicht aktualisiert werden: $e';
      return null;
    }
  }

  Future<EventInvitation?> joinByCode({
    required String code,
    required String userId,
  }) async {
    if (_apiClient == null) return null;
    try {
      final payload = await _apiClient!.postJsonAny(
        APIConfig.getBackendEventInvitationsJoinPath(),
        {'code': code, 'userId': userId},
      );
      return _parseSingleInvitation(payload);
    } catch (e) {
      lastSyncError = 'Code konnte nicht eingelöst werden: $e';
      return null;
    }
  }

  Future<List<MeetupEvent>> fetchHostedInviteOnlyEvents(String hostUserId) async {
    if (_apiClient == null) return [];
    try {
      final path = APIConfig.getBackendHostedInviteOnlyEventsPath();
      final payload =
          await _apiClient!.getJson(_appendQuery(path, {'hostUserId': hostUserId}));
      return _parseEventList(payload);
    } catch (e) {
      lastSyncError = 'Host-Events konnten nicht geladen werden: $e';
      return [];
    }
  }

  Future<List<EventInvitation>> fetchAcceptedInvitationsForEvent(String eventId) async {
    if (_apiClient == null) return [];
    try {
      final payload = await _apiClient!.getJson('$_eventsPath/$eventId/invitations/accepted');
      return _parseInvitationList(payload);
    } catch (e) {
      lastSyncError = 'Angenommene Einladungen konnten nicht geladen werden: $e';
      return [];
    }
  }

  Future<List<EventParticipation>> fetchUserParticipations(String userId) async {
    if (_apiClient == null) return [];
    try {
      final payload = await _apiClient!
          .getJson(_appendQuery('$_eventsPath/participations', {'userId': userId}));
      return _parseParticipationList(payload);
    } catch (e) {
      lastSyncError = 'Teilnahmen konnten nicht geladen werden: $e';
      return [];
    }
  }

  Future<List<EventParticipation>> fetchPendingRequestsForHost(String hostUserId) async {
    if (_apiClient == null) return [];
    try {
      final payload = await _apiClient!.getJson(
        _appendQuery('$_eventsPath/participations/pending', {'hostUserId': hostUserId}),
      );
      return _parseParticipationList(payload);
    } catch (e) {
      lastSyncError = 'Offene Anfragen konnten nicht geladen werden: $e';
      return [];
    }
  }

  Future<EventParticipation?> requestParticipation({
    required String eventId,
    required String userId,
  }) async {
    if (_apiClient == null) return null;
    try {
      final payload = await _apiClient!.postJsonAny(
        '$_eventsPath/participations',
        {'eventId': eventId, 'userId': userId},
      );
      return _parseSingleParticipation(payload);
    } catch (e) {
      lastSyncError = 'Teilnahmeanfrage konnte nicht gesendet werden: $e';
      return null;
    }
  }

  Future<EventParticipation?> respondToParticipation({
    required String participationId,
    required bool accept,
  }) async {
    if (_apiClient == null) return null;
    try {
      final payload = await _apiClient!.putJson(
        '$_eventsPath/participations/$participationId/respond',
        {'accept': accept},
      );
      return _parseSingleParticipation(payload);
    } catch (e) {
      lastSyncError = 'Teilnahmestatus konnte nicht aktualisiert werden: $e';
      return null;
    }
  }

  Future<EventParticipation?> fetchParticipationByUserAndEvent({
    required String userId,
    required String eventId,
  }) async {
    if (_apiClient == null) return null;
    try {
      final payload = await _apiClient!.getJson(
        _appendQuery(
          '$_eventsPath/participations',
          {'userId': userId, 'eventId': eventId},
        ),
      );
      final items = _parseParticipationList(payload);
      if (items.isEmpty) return null;
      items.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return items.first;
    } catch (e) {
      lastSyncError = 'Teilnahme konnte nicht geladen werden: $e';
      return null;
    }
  }

  Future<List<EventParticipation>> fetchApprovedParticipantsForEvent(
    String eventId,
  ) async {
    if (_apiClient == null) return [];
    try {
      final payload = await _apiClient!
          .getJson('$_eventsPath/$eventId/participations/approved');
      return _parseParticipationList(payload);
    } catch (e) {
      lastSyncError = 'Teilnehmer konnten nicht geladen werden: $e';
      return [];
    }
  }

  List<MeetupEvent> _parseEventList(dynamic payload) {
    final list = _extractList(payload, const ['items', 'events', 'data', 'results']);
    return list
        .whereType<Map>()
        .map((raw) => _normalizeEventMap(Map<String, dynamic>.from(raw)))
        .map(MeetupEvent.fromJson)
        .toList();
  }

  MeetupEvent? _parseSingleEvent(dynamic payload) {
    final map = _extractMap(payload, const ['item', 'event', 'data', 'result']);
    if (map == null) return null;
    return MeetupEvent.fromJson(_normalizeEventMap(map));
  }

  List<EventInvitation> _parseInvitationList(dynamic payload) {
    final list = _extractList(payload, const ['items', 'invitations', 'data', 'results']);
    return list
        .whereType<Map>()
        .map((raw) => EventInvitation.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  EventInvitation? _parseSingleInvitation(dynamic payload) {
    final map = _extractMap(payload, const ['item', 'invitation', 'data', 'result']);
    if (map == null) return null;
    return EventInvitation.fromJson(map);
  }

  EventParticipation? _parseSingleParticipation(dynamic payload) {
    final map = _extractMap(payload, const ['item', 'participation', 'data', 'result']);
    if (map == null) return null;
    return EventParticipation.fromJson(map);
  }

  List<EventParticipation> _parseParticipationList(dynamic payload) {
    final list =
        _extractList(payload, const ['items', 'participations', 'data', 'results']);
    return list
        .whereType<Map>()
        .map((raw) => EventParticipation.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Map<String, dynamic> _normalizeEventMap(Map<String, dynamic> raw) {
    double parseDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int parseInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return {
      'id': (raw['id'] ?? raw['_id'] ?? '').toString(),
      'hosterId': (raw['hosterId'] ?? raw['host_id'] ?? raw['hostUserId'] ?? '').toString(),
      'title': (raw['title'] ?? '').toString(),
      'description': (raw['description'] ?? '').toString(),
      'category': (raw['category'] ?? 'other').toString(),
      'ageGroups': (raw['ageGroups'] is List)
          ? List<String>.from((raw['ageGroups'] as List).map((e) => e.toString()))
          : <String>[],
      'location': (raw['location'] ?? '').toString(),
      'latitude': parseDouble(raw['latitude'], 0),
      'longitude': parseDouble(raw['longitude'], 0),
      'eventDate': (raw['eventDate'] ?? DateTime.now().toIso8601String()).toString(),
      'createdAt': (raw['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      'paymentDate': raw['paymentDate']?.toString(),
      'maxParticipants': parseInt(raw['maxParticipants'], 20),
      'currentParticipants': parseInt(raw['currentParticipants'], 0),
      'photoUrl': (raw['photoUrl'] ?? '').toString(),
      'status': (raw['status'] ?? 'active').toString(),
      'price': raw['price'] is num
          ? (raw['price'] as num).toDouble()
          : double.tryParse(raw['price']?.toString() ?? ''),
      'visibility': (raw['visibility'] ?? 'publicNearby').toString(),
      'shareRadiusKm': parseDouble(raw['shareRadiusKm'], 25),
      'invitedUserIds': (raw['invitedUserIds'] is List)
          ? List<String>.from((raw['invitedUserIds'] as List).map((e) => e.toString()))
          : <String>[],
      'inviteCodeExpiresAt': raw['inviteCodeExpiresAt']?.toString(),
    };
  }

  List<dynamic> _extractList(dynamic payload, List<String> keys) {
    if (payload is List) return payload;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in keys) {
        final value = map[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  Map<String, dynamic>? _extractMap(dynamic payload, List<String> keys) {
    if (payload is Map<String, dynamic>) {
      for (final key in keys) {
        final value = payload[key];
        if (value is Map<String, dynamic>) return value;
      }
      return payload;
    }

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in keys) {
        final value = map[key];
        if (value is Map) return Map<String, dynamic>.from(value);
      }
      return map;
    }

    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('EventBackendService._extractMap jsonDecode failed: $e');
      }
    }

    return null;
  }

  String _appendQuery(String path, Map<String, String> query) {
    if (query.isEmpty) return path;
    final uri = Uri(path: path, queryParameters: query);
    return uri.toString();
  }
}
