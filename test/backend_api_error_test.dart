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
}
