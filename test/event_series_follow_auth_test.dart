import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EventBackendService service(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
    Future<String?> Function()? refresh,
    void Function()? guard,
  }) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return EventBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authToken: 'shared-must-not-be-used',
        authTokenProvider: token ?? () async => 'firebase-token',
        forceRefreshTokenProvider: refresh,
        requestGuard: guard,
        httpClient: client,
      ),
    );
  }

  Future<bool?> call(String method, EventBackendService api,
      {String seriesId = 'series', String userId = 'owner'}) {
    return switch (method) {
      'POST' => api.followSeries(seriesId: seriesId, userId: userId),
      'DELETE' => api.unfollowSeries(seriesId: seriesId, userId: userId),
      'GET' => api.isFollowingSeries(seriesId: seriesId, userId: userId),
      _ => throw ArgumentError.value(method),
    };
  }

  for (final method in ['POST', 'DELETE', 'GET']) {
    test('$method uses Firebase and preserves payload and path', () async {
      var requests = 0;
      final api = service((request) async {
        requests++;
        expect(request.method, method);
        expect(request.url.path, '/api/events/series/series/follow');
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        if (method == 'POST') {
          expect(jsonDecode(request.body)['userId'], 'owner');
        } else {
          expect(request.url.queryParameters['userId'], 'owner');
        }
        return http.Response('{"following":true,"followerCount":1}', 200);
      });
      expect(await call(method, api), isTrue);
      expect(requests, 1);
      expect(api.lastSyncError, isNull);
    });
    for (final token in <String?>[null, '', ' ', 'throws']) {
      test('$method blocks token $token without shared fallback or HTTP',
          () async {
        var requests = 0;
        final api = service((_) async {
          requests++;
          return http.Response('{"following":true}', 200);
        }, token: () async {
          if (token == 'throws') throw StateError('Token unavailable');
          return token;
        });
        expect(await call(method, api), method == 'GET' ? isNull : isFalse);
        expect(requests, 0);
        expect(api.lastSyncError, isNotEmpty);
      });
    }
    for (final status in [401, 403, 500, 503]) {
      test('$method HTTP $status never becomes a successful local action',
          () async {
        final api = service((_) async => http.Response('{}', status));
        expect(await call(method, api), method == 'GET' ? isNull : isFalse);
        expect(api.lastSyncError, contains('$status'));
      });
    }
    test('$method network failure remains explicit', () async {
      final api = service((_) async => throw http.ClientException('Offline'));
      expect(await call(method, api), method == 'GET' ? isNull : isFalse);
      expect(api.lastSyncError, isNotEmpty);
    });
    test('$method preserves 401 refresh without falling back to shared token',
        () async {
      var requests = 0, refreshes = 0;
      final api = service((request) async {
        requests++;
        expect(request.headers['Authorization'],
            requests == 1 ? 'Bearer firebase-token' : 'Bearer refreshed');
        return http.Response('{"following":true}', requests == 1 ? 401 : 200);
      }, refresh: () async {
        refreshes++;
        return 'refreshed';
      });
      expect(await call(method, api), isTrue);
      expect(requests, 2);
      expect(refreshes, 1);
    });
    test('$method retains request guard in authenticated client view',
        () async {
      var requests = 0;
      final api = service((_) async {
        requests++;
        return http.Response('{"following":true}', 200);
      }, guard: () => throw StateError('Account changed'));
      expect(await call(method, api), method == 'GET' ? isNull : isFalse);
      expect(requests, 0);
      expect(api.lastSyncError, contains('Account changed'));
    });
    test('$method rejects empty series/user input with an explicit error',
        () async {
      var requests = 0;
      final api = service((_) async {
        requests++;
        return http.Response('{"following":true}', 200);
      });
      for (final values in [('', 'owner'), ('series', ''), (' ', 'owner')]) {
        expect(
          await call(method, api, seriesId: values.$1, userId: values.$2),
          method == 'GET' ? isNull : isFalse,
        );
        expect(api.lastSyncError, isNotEmpty);
      }
      expect(requests, 0);
    });
    test('$method clears a previous error after a successful request',
        () async {
      var requests = 0;
      final api = service((_) async {
        requests++;
        return http.Response('{"following":true}', requests == 1 ? 503 : 200);
      });
      await call(method, api);
      expect(api.lastSyncError, isNotEmpty);
      expect(await call(method, api), isTrue);
      expect(api.lastSyncError, isNull);
    });
  }

  for (final body in ['{}', '{"following":"true"}', '[]', 'not json']) {
    test('malformed personal status $body is unavailable, not false', () async {
      final api = service((_) async => http.Response(body, 200));
      expect(await api.isFollowingSeries(seriesId: 'series', userId: 'owner'),
          isNull);
      expect(api.lastSyncError, isNotEmpty);
    });
  }
  test('valid following=false stays distinct from unavailable', () async {
    final api = service((_) async => http.Response('{"following":false}', 200));
    expect(await api.isFollowingSeries(seriesId: 'series', userId: 'owner'),
        isFalse);
    expect(api.lastSyncError, isNull);
  });
  test('personal status and opt-out encode the user as a single query value',
      () async {
    final api = service((request) async {
      expect(request.url.queryParameters, {'userId': 'owner&userId=other'});
      return http.Response('{"following":false}', 200);
    });
    for (final method in ['GET', 'DELETE']) {
      await call(method, api, userId: 'owner&userId=other');
    }
  });
  test('required-token view drops static token and shares guard/providers',
      () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final original = BackendApiClient(
      baseUrl: 'https://backend.example',
      authToken: 'shared',
      httpClient: client,
    );
    final verified = original.withRequiredAuthToken();
    expect(verified.requireAuthToken, isTrue);
    expect(verified.authToken, isNull);
    await expectLater(verified.getJson('/personal'), throwsStateError);
    expect(requests, 0);
    await original.getJson('/public');
    expect(requests, 1);
  });
}
