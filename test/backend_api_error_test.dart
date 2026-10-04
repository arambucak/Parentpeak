import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';

BackendApiClient _client(http.Response Function(http.Request) respond) =>
    BackendApiClient(
      baseUrl: 'http://localhost:3000',
      authToken: 'test-only',
      httpClient: MockClient((request) async => respond(request)),
    );

void main() {
  test('BackendApiException ist eine Exception mit Status + Server-Message',
      () async {
    final client = _client(
      (_) => http.Response(
        jsonEncode({'error': 'Gültiger Firebase ID-Token erforderlich'}),
        401,
      ),
    );

    try {
      await client.postJson('/ai/generate', {'prompt': 'hi'});
      fail('sollte werfen');
    } on BackendApiException catch (e) {
      expect(e, isA<Exception>());
      expect(e.statusCode, 401);
      expect(e.isUnauthorized, isTrue);
      expect(e.serverMessage, contains('Firebase'));
      expect(e.toString(), contains('401'));
      expect(e.toString(), contains('Firebase'));
    }
  });

  test('nicht-JSON-Fehlerbody wird gekürzt übernommen', () async {
    final client = _client((_) => http.Response('Bad Gateway', 502));
    try {
      await client.getJson('/something');
      fail('sollte werfen');
    } on BackendApiException catch (e) {
      expect(e.statusCode, 502);
      expect(e.isUnauthorized, isFalse);
      expect(e.serverMessage, 'Bad Gateway');
    }
  });

  test('weiterhin als generische Exception fangbar (Abwärtskompatibilität)',
      () async {
    final client = _client((_) => http.Response('{}', 500));
    await expectLater(
      client.postJsonAny('/x', const {}),
      throwsA(isA<Exception>()),
    );
  });

  test('401 wird einmal mit frisch erzwungenem Token wiederholt', () async {
    var calls = 0;
    final tokensSeen = <String?>[];
    final client = BackendApiClient(
      baseUrl: 'http://localhost:3000',
      authToken: 'static',
      authTokenProvider: () async => 'stale-token',
      forceRefreshTokenProvider: () async => 'fresh-token',
      httpClient: MockClient((request) async {
        calls++;
        tokensSeen.add(request.headers['Authorization']);
        // Erster Versuch (alter Token) -> 401, zweiter (frischer Token) -> 200.
        if (calls == 1) return http.Response('{"error":"unauth"}', 401);
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    final result = await client.postJson('/ai/generate', {'x': 1});
    assert(result['ok'] == true);
    assert(calls == 2);
    assert(tokensSeen[0] == 'Bearer stale-token');
    assert(tokensSeen[1] == 'Bearer fresh-token');
  });

  test('401 ohne forceRefreshProvider wirft (kein Retry)', () async {
    var calls = 0;
    final client = BackendApiClient(
      baseUrl: 'http://localhost:3000',
      authToken: 'static',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"error":"unauth"}', 401);
      }),
    );
    await expectLater(
      client.postJsonAny('/ai/generate', const {}),
      throwsA(isA<BackendApiException>()),
    );
    assert(calls == 1);
  });
}
