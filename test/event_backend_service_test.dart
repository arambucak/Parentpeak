// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/models/meetup_event.dart';

http.Client _mockClient(int statusCode, Map<String, dynamic> body) {
  return MockClient((_) async {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
}

BackendApiClient _client(http.Client httpClient) {
  return BackendApiClient(
    baseUrl: 'http://localhost:3000',
    authToken: 'test-token',
    httpClient: httpClient,
  );
}

void main() {
  test(
    'parses an acknowledged participation request from the server',
    () async {
      final service = EventBackendService(
        apiClient: _client(
          MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/events/participations');
            expect(jsonDecode(request.body), {
              'eventId': 'ev1',
              'userId': 'user1',
            });
            return http.Response(
              jsonEncode({
                'item': {
                  'id': 'part1',
                  'eventId': 'ev1',
                  'userId': 'user1',
                  'requestedAt': '2026-10-02T18:00:00Z',
                  'status': 'pending',
                },
              }),
              201,
            );
          }),
        ),
      );

      final participation = await service.requestParticipation(
        eventId: 'ev1',
        userId: 'user1',
      );

      expect(participation?.id, 'part1');
      expect(participation?.status, ParticipationStatus.pending);
      expect(service.lastSyncError, isNull);
    },
  );

  test('owner update keeps API image and participant capacity count', () async {
    final service = EventBackendService(
      apiClient: _client(
        _mockClient(200, {
          'event': {
            'id': 'ev1',
            'hosterId': 'owner',
            'imageUrl': 'https://example.test/event.jpg',
            'participants': [
              {'status': 'approved'},
              {'status': 'pending'},
              {'status': 'declined'},
            ],
          },
        }),
      ),
    );
    final updated = await service.updateEvent('ev1', {
      'title': 'Updated',
    }, requestingUserId: 'owner');
    expect(updated?.currentParticipants, 2);
    expect(updated?.photoUrl, 'https://example.test/event.jpg');
  });

  test('update sends the acting owner in the API hosterId field', () async {
    final service = EventBackendService(
      apiClient: _client(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/events/ev1');
          expect(jsonDecode(request.body), {
            'title': 'Updated',
            'startDate': '2026-10-10T10:00:00Z',
            'maxParticipants': 8,
            'hosterId': 'owner',
          });
          return http.Response(
            jsonEncode({
              'event': {
                'id': 'ev1',
                'hosterId': 'owner',
                'title': 'Updated',
                'startDate': '2026-10-10T10:00:00Z',
                'maxParticipants': 8,
              },
            }),
            200,
          );
        }),
      ),
    );
    final updated = await service.updateEvent('ev1', {
      'title': 'Updated',
      'startDate': '2026-10-10T10:00:00Z',
      'maxParticipants': 8,
    }, requestingUserId: 'owner');
    expect(updated?.title, 'Updated');
    expect(updated?.maxParticipants, 8);
  });

  test(
    'preserves the API startDate instead of using the current time',
    () async {
      final service = EventBackendService(
        apiClient: _client(
          _mockClient(200, {
            'event': {
              'id': 'ev-date',
              'startDate': '2026-10-03T10:00:00Z',
              'status': 'upcoming',
            },
          }),
        ),
      );

      final event = await service.fetchEventById('ev-date');

      expect(event?.eventDate, DateTime.utc(2026, 10, 3, 10));
    },
  );

  test(
    'uses registered server routes for all participation operations',
    () async {
      final paths = <String>[];
      final service = EventBackendService(
        apiClient: _client(
          MockClient((request) async {
            paths.add('${request.method} ${request.url.path}');
            return http.Response('{}', 404);
          }),
        ),
      );

      await service.fetchUserParticipations('user1');
      await service.fetchPendingRequestsForHost('host1');
      await service.requestParticipation(eventId: 'ev1', userId: 'user1');
      await service.respondToParticipation(
        participationId: 'part1',
        accept: true,
      );
      await service.fetchParticipationByUserAndEvent(
        userId: 'user1',
        eventId: 'ev1',
      );
      await service.fetchApprovedParticipantsForEvent('ev1');

      expect(paths, [
        'GET /events/participations',
        'GET /events/participations/pending',
        'POST /events/participations',
        'PUT /events/participations/part1/respond',
        'GET /events/participations',
        'GET /events/ev1/participations/approved',
      ]);
    },
  );

  group('EventBackendService backend statuses', () {
    for (final entry in {
      'upcoming': EventStatus.active,
      'ongoing': EventStatus.active,
      'active': EventStatus.active,
      'completed': EventStatus.completed,
      'cancelled': EventStatus.cancelled,
    }.entries) {
      test('parses ${entry.key} in a successful create response', () async {
        final event = MeetupEvent(
          id: 'ev1',
          hosterId: 'user1',
          title: 'Test Event',
          description: '',
          category: EventCategory.other,
          ageGroups: const [AgeGroup.mixed],
          location: 'Berlin',
          latitude: 52.52,
          longitude: 13.4,
          eventDate: DateTime(2026, 10, 10),
          createdAt: DateTime(2026, 10, 2),
          maxParticipants: 10,
          photoUrl: '',
        );
        final service = EventBackendService(
          apiClient: _client(
            _mockClient(201, {
              'event': {...event.toJson(), 'status': entry.key},
            }),
          ),
        );

        final created = await service.createEvent(event);

        expect(created, isNotNull);
        expect(created!.status, entry.value);
        expect(service.lastSyncError, isNull);
      });
    }
  });

  group('BackendApiClient uploads', () {
    test('byte upload uses dynamic auth token and multipart payload', () async {
      const imageBytes = <int>[1, 2, 3, 4];
      final mockHttp = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer firebase-id-token');
        expect(request.body, contains('filename="web-photo.png"'));
        expect(request.bodyBytes, containsAllInOrder(imageBytes));
        return http.Response(
          jsonEncode({'url': '/uploads/web-photo.png'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = BackendApiClient(
        baseUrl: 'http://localhost:3000',
        authToken: 'static-fallback-token',
        authTokenProvider: () async => 'firebase-id-token',
        httpClient: mockHttp,
      );

      final response = await client.uploadImageBytes(
        '/uploads/image',
        imageBytes,
        filename: 'web-photo.png',
      );

      expect(response['url'], '/uploads/web-photo.png');
    });
  });

  group('EventBackendService.fetchEvents', () {
    test('returns parsed events on 200', () async {
      final mockHttp = _mockClient(200, {
        'items': [
          {
            'id': 'ev1',
            'hosterId': 'user1',
            'title': 'Test Event',
            'description': '',
            'status': 'active',
            'eventType': 'other',
            'startDate': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
            'location': 'Berlin',
            'latitude': 52.52,
            'longitude': 13.4,
            'maxParticipants': 10,
            'costPerPerson': null,
            'imageUrl': '',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'visibility': 'publicNearby',
            'shareRadiusKm': 25,
          },
        ],
        'limit': 50,
        'offset': 0,
        'hasMore': false,
      });

      final svc = EventBackendService(apiClient: _client(mockHttp));
      final events = await svc.fetchEvents();

      expect(events, hasLength(1));
      expect(events.first.id, 'ev1');
      expect(events.first.title, 'Test Event');
    });

    test('returns empty list on network error', () async {
      final errorClient = MockClient((_) async => throw Exception('timeout'));
      final svc = EventBackendService(apiClient: _client(errorClient));
      final events = await svc.fetchEvents();
      expect(events, isEmpty);
      expect(svc.lastSyncError, isNotNull);
    });

    test('passes limit and offset query params', () async {
      http.Request? captured;
      final mockHttp = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'items': [],
            'limit': 10,
            'offset': 20,
            'hasMore': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = EventBackendService(apiClient: _client(mockHttp));
      await svc.fetchEvents(limit: 10, offset: 20);

      expect(captured!.url.queryParameters['limit'], '10');
      expect(captured!.url.queryParameters['offset'], '20');
    });
  });

  group('EventBackendService.discoverEventsForUser', () {
    test('passes viewerUserId and pagination params', () async {
      http.Request? captured;
      final mockHttp = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'items': [], 'limit': 25, 'offset': 0, 'hasMore': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = EventBackendService(apiClient: _client(mockHttp));
      await svc.discoverEventsForUser(
        viewerUserId: 'viewer1',
        viewerLatitude: 52.5,
        viewerLongitude: 13.4,
        limit: 25,
      );

      expect(captured!.url.queryParameters['viewerUserId'], 'viewer1');
      expect(captured!.url.queryParameters['limit'], '25');
    });
  });

  group('EventBackendService.updateEvent', () {
    test('sends PUT with fields and returns updated event', () async {
      http.Request? captured;
      final mockHttp = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'item': {
              'id': 'ev1',
              'hosterId': 'user1',
              'title': 'Updated Title',
              'description': '',
              'status': 'active',
              'eventType': 'other',
              'startDate': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
              'location': 'Hamburg',
              'latitude': 53.57,
              'longitude': 10.02,
              'maxParticipants': 15,
              'costPerPerson': null,
              'imageUrl': '',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'visibility': 'publicNearby',
              'shareRadiusKm': 25,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = EventBackendService(apiClient: _client(mockHttp));
      final updated = await svc.updateEvent('ev1', {
        'title': 'Updated Title',
        'location': 'Hamburg',
      }, requestingUserId: 'user1');

      expect(captured!.method, 'PUT');
      expect(captured!.url.path, contains('ev1'));
      final sentBody = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(sentBody['title'], 'Updated Title');
      expect(sentBody['hosterId'], 'user1');
      expect(updated?.title, 'Updated Title');
    });

    test('returns null on error', () async {
      final errorClient = MockClient(
        (_) async => http.Response(
          '{}',
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      final svc = EventBackendService(apiClient: _client(errorClient));
      final result = await svc.updateEvent('ev1', {'title': 'x'});
      expect(result, isNull);
    });
  });

  group('EventBackendService.deleteEvent', () {
    test('sends DELETE and returns true on 204', () async {
      http.Request? captured;
      final mockHttp = MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      });

      final svc = EventBackendService(apiClient: _client(mockHttp));
      final ok = await svc.deleteEvent('ev1', hosterId: 'host1');
      expect(ok, isTrue);
      expect(captured!.method, 'DELETE');
    });

    test('returns false on 403', () async {
      final mockHttp = MockClient(
        (_) async => http.Response(
          '{"error":"forbidden"}',
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      final svc = EventBackendService(apiClient: _client(mockHttp));
      final ok = await svc.deleteEvent('ev1', hosterId: 'host1');
      expect(ok, isFalse);
    });
  });
}
