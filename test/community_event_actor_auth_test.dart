import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/ui/widgets/event_safety_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final event = CommunityEvent(
    id: 'event',
    title: 'Family walk',
    description: 'Together in the park',
    category: EventCategory.natur,
    ageGroups: [EventAgeGroup.alle],
    location: 'Park',
    city: 'Berlin',
    eventDate: DateTime(2099, 10, 24),
    organizer: 'Parents',
    creatorId: 'owner',
    createdAt: DateTime(2026, 10, 24),
  );

  CommunityEventService service({
    required Future<http.Response> Function(http.Request) write,
    Future<String?> Function()? token,
    Future<String?> Function()? refresh,
    bool missingBackend = false,
    bool verified = true,
  }) {
    final publicHttp = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/community-events');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response(jsonEncode([event.toJson()]), 200);
    });
    final writeHttp = MockClient(write);
    addTearDown(publicHttp.close);
    addTearDown(writeHttp.close);
    final api = CommunityEventService.forTesting(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        httpClient: publicHttp,
      ),
      verifiedApiClient: missingBackend
          ? null
          : BackendApiClient(
              baseUrl: 'https://backend.example',
              requireAuthToken: verified,
              authToken: 'must-not-be-used',
              authTokenProvider: token ?? () async => 'firebase-token',
              forceRefreshTokenProvider: refresh,
              httpClient: writeHttp,
            ),
      displayNameProvider: () => 'Parent',
    );
    addTearDown(api.dispose);
    return api;
  }

  Future<bool> call(String action, CommunityEventService api) {
    return switch (action) {
      'create' => api.createEvent(event),
      'delete' => api.deleteEvent('event'),
      'interest' => api.showInterest('event', message: 'Joining'),
      _ => throw ArgumentError.value(action),
    };
  }

  Future<void> seed(CommunityEventService api) async {
    await api.loadEvents(city: 'Berlin', includeAiEvents: false);
    expect(api.events, hasLength(1));
  }

  for (final action in ['create', 'delete', 'interest']) {
    test('$action sends Firebase and updates local state only after success',
        () async {
      var requests = 0;
      final api = service(write: (request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        expect(request.method, action == 'delete' ? 'DELETE' : 'POST');
        expect(
          request.url.path,
          action == 'create'
              ? '/api/community-events'
              : '/api/community-events/event${action == 'interest' ? '/interest' : ''}',
        );
        if (action == 'create') {
          final body = jsonDecode(request.body);
          expect(body['creatorId'], 'owner');
          expect(body['title'], 'Family walk');
          expect(body['isFree'], isTrue);
        } else if (action == 'interest') {
          final body = jsonDecode(request.body);
          expect(body['message'], 'Joining');
          expect(body['displayName'], 'Parent');
          expect(body.containsKey('userId'), isFalse);
        } else {
          expect(request.url.queryParameters.containsKey('creatorId'), isFalse);
        }
        return http.Response(
            action == 'create'
                ? jsonEncode(event.toJson())
                : '{"success":true,"interestCount":1}',
            action == 'create' ? 201 : 200);
      });
      await seed(api);
      expect(await call(action, api), isTrue);
      expect(requests, 1);
      expect(api.error, isNull);
      expect(
          api.events.length,
          action == 'delete'
              ? 0
              : action == 'create'
                  ? 2
                  : 1);
      if (action == 'interest') expect(api.events.single.interestCount, 1);
      expect(api.remainingToday, action == 'create' ? 2 : 3);
    });

    for (final token in <String?>[null, '', ' ', 'throws']) {
      test('$action blocks token $token without HTTP or local mutation',
          () async {
        var requests = 0;
        final api = service(
          write: (_) async {
            requests++;
            return http.Response('{}', 200);
          },
          token: () async {
            if (token == 'throws') throw StateError('Token unavailable');
            return token;
          },
        );
        await seed(api);
        expect(await call(action, api), isFalse);
        expect(requests, 0);
        expect(api.error, isNotEmpty);
        expect(api.events, hasLength(1));
        expect(api.events.single.interestCount, 0);
        expect(api.remainingToday, 3);
      });
    }

    for (final status in [401, 403, 429, 500, 503]) {
      test('$action HTTP $status is an explicit failure without local mutation',
          () async {
        final api = service(
            write: (_) async => http.Response('{"error":"Rejected"}', status));
        await seed(api);
        expect(await call(action, api), isFalse);
        expect(api.error, contains('$status'));
        expect(api.events, hasLength(1));
        expect(api.events.single.interestCount, 0);
        expect(api.remainingToday, 3);
      });
    }
    for (final missingBackend in [false, true]) {
      test(
          '$action refuses missing or nonverified backend without local success',
          () async {
        var requests = 0;
        final api = service(
          missingBackend: missingBackend,
          verified: false,
          write: (_) async {
            requests++;
            return http.Response('{}', 200);
          },
        );
        await seed(api);
        expect(await call(action, api), isFalse);
        expect(requests, 0);
        expect(api.error, isNotEmpty);
        expect(api.events, hasLength(1));
        expect(api.events.single.interestCount, 0);
        expect(api.remainingToday, 3);
      });
    }
    test('$action network error never mutates local state', () async {
      final api =
          service(write: (_) async => throw http.ClientException('Offline'));
      await seed(api);
      expect(await call(action, api), isFalse);
      expect(api.error, isNotEmpty);
      expect(api.events, hasLength(1));
      expect(api.events.single.interestCount, 0);
      expect(api.remainingToday, 3);
    });

    test('$action retries expired Firebase once with a refreshed token',
        () async {
      var requests = 0;
      final api = service(
        write: (request) async {
          requests++;
          expect(request.headers['Authorization'],
              requests == 1 ? 'Bearer firebase-token' : 'Bearer refreshed');
          return http.Response('{"success":true}', requests == 1 ? 401 : 200);
        },
        refresh: () async => 'refreshed',
      );
      expect(await call(action, api), isTrue);
      expect(requests, 2);
    });
  }

  test('public discovery works without consulting verified session', () async {
    var requests = 0;
    final api = service(
      write: (_) async {
        requests++;
        throw StateError('No write expected');
      },
      token: () async => throw StateError('No session expected'),
    );
    await seed(api);
    expect(requests, 0);
    expect(api.error, isNull);
  });

  for (final status in [200, 403, 503]) {
    testWidgets('interest button waits for HTTP $status before showing success',
        (tester) async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final api = service(write: (_) async {
        requests++;
        return pending.future;
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EventInterestButton(
            eventId: 'event',
            initialCount: 2,
            service: api,
          ),
        ),
      ));
      final button = find.byType(EventInterestButton);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(requests, 1);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      pending.complete(http.Response('{"success":true}', status));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded),
          status == 200 ? findsOneWidget : findsNothing);
      if (status != 200) {
        expect(find.text('Not saved. Please try again.'), findsOneWidget);
      }
    });
  }
}
