import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';

ParentMatchingBackendService service(http.Client client) =>
    ParentMatchingBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authToken: 'test-token',
        httpClient: client,
      ),
    );

void main() {
  test('sendAction posts like to the canonical route and reads matchState',
      () async {
    late http.Request captured;
    final matching = service(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'connected': true,
            'matchState': 'matched',
            'action': {'id': 'a1'},
          }),
          201,
        );
      }),
    );

    final result = await matching.sendAction(
      profileId: 'target-profile',
      action: 'like',
      userId: 'owner',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/parent-matching/actions');
    expect(jsonDecode(captured.body), {
      'profileId': 'target-profile',
      'action': 'like',
      'userId': 'owner',
    });
    expect(result.connected, isTrue);
    expect(result.matchState, 'matched');
    expect(matching.lastSyncError, isNull);
  });

  test('sendAction reports pending when interest is one-sided', () async {
    final matching = service(
      MockClient((_) async => http.Response(
            jsonEncode({'connected': false, 'matchState': 'pending'}),
            201,
          )),
    );
    final result = await matching.sendAction(
      profileId: 'p',
      action: 'like',
      userId: 'owner',
    );
    expect(result.connected, isFalse);
    expect(result.matchState, 'pending');
  });

  test('sendAction reports none for a pass', () async {
    final matching = service(
      MockClient((_) async => http.Response(
            jsonEncode({'connected': false, 'matchState': 'none'}),
            201,
          )),
    );
    final result = await matching.sendAction(
      profileId: 'p',
      action: 'pass',
      userId: 'owner',
    );
    expect(result.connected, isFalse);
    expect(result.matchState, 'none');
  });

  test('sendAction surfaces an error state on HTTP failure', () async {
    final matching = service(
      MockClient((_) async => http.Response('{"error":"nope"}', 503)),
    );
    final result = await matching.sendAction(
      profileId: 'p',
      action: 'like',
      userId: 'owner',
    );
    expect(result.matchState, 'error');
    expect(result.connected, isFalse);
    expect(matching.lastSyncError, isNotNull);
  });
}
