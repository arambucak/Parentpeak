import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friendship_service.dart';

void main() {
  Future<Map<String, dynamic>> sentBody(Map<String, dynamic> body) async {
    Map<String, dynamic>? captured;
    final client = BackendApiClient(
      baseUrl: 'https://api.test',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/friendships/request');
        captured = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"ok":true,"status":"pending"}', 200);
      }),
    );
    await client.postJsonAny('/api/friendships/request', body);
    return captured!;
  }

  test('discovery request sends source: discovery', () async {
    final body = await sentBody(
      FriendshipService.buildRequestBody('uid-b', source: 'discovery'),
    );
    expect(body, {'toUid': 'uid-b', 'source': 'discovery'});
  });

  test('request without source omits the source key', () async {
    final body = await sentBody(FriendshipService.buildRequestBody('uid-b'));
    expect(body, {'toUid': 'uid-b'});
    expect(body.containsKey('source'), isFalse);
  });
}
