import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.loadFromString(
      envString:
          'BACKEND_BASE_URL=https://backend.example\nBACKEND_API_TOKEN=static-token',
    );
  });
  tearDown(dotenv.clean);

  ParentMatchingBackendService manualService(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
  }) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return ParentMatchingBackendService(
      httpClient: client,
      firebaseTokenProvider: token ?? () async => 'firebase-owner-token',
    );
  }

  test('manual profile fallback sends Firebase and preserves profile schema',
      () async {
    var requests = 0;
    final service = manualService((request) async {
      requests++;
      expect(request.method, 'POST');
      expect(request.url.path, '/parent-matching/my-profile');
      expect(request.headers['Authorization'], 'Bearer firebase-owner-token');
      expect(request.headers['Content-Type'], 'application/json');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['userId'], 'owner');
      expect(body['age'], isNull);
      expect(body['latitude'], isNull);
      expect(body['longitude'], isNull);
      expect(body['familyForm'], 'Kernfamilie');
      expect(body['interests'], ['playgrounds']);
      expect(body['languages'], ['de']);
      expect(body['valuesFocus'], ['respect']);
      expect(body['childAges'], ['3-5']);
      return http.Response(
        jsonEncode({
          'item': {
            ...body,
            'id': 'self-owner',
            'ownerUserId': 'owner',
            'phoneVerified': false,
            'identityVerified': false,
            'moderationChecked': false,
          },
        }),
        201,
      );
    });
    final profile = await service.createProfile(
      userId: 'owner',
      name: 'Parent',
      city: 'Berlin',
      familyForm: 'Kernfamilie',
      interests: ['playgrounds'],
      languages: ['de'],
      valuesFocus: ['respect'],
      childAges: ['3-5'],
    );
    expect(requests, 1);
    expect(profile?.id, 'self-owner');
    expect(profile?.userId, 'owner');
    expect(profile?.age, isNull);
    expect(profile?.latitude, isNull);
    expect(profile?.phoneVerified, isFalse);
    expect(service.lastSyncError, isNull);
  });

  test('manual action fallback sends current Firebase token and legacy schema',
      () async {
    var token = 'firebase-first-token';
    final sentTokens = <String?>[];
    final service = manualService((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/parent-matching/record-action');
      sentTokens.add(request.headers['Authorization']);
      expect(jsonDecode(request.body), {
        'userId': 'owner',
        'matchedProfileId': 'target-profile',
        'action': 'like',
      });
      return http.Response('{"action":{"id":"action"}}', 201);
    }, token: () async => token);
    for (final current in ['firebase-first-token', 'firebase-second-token']) {
      token = current;
      expect(await service.recordAction(
        userId: 'owner',
        matchedProfileId: 'target-profile',
        action: 'like',
      ), isTrue);
      expect(service.lastSyncError, isNull);
    }
    expect(sentTokens, [
      'Bearer firebase-first-token',
      'Bearer firebase-second-token',
    ]);
  });

  for (final token in <String?>[null, '', '   ']) {
    test('missing token ${jsonEncode(token)} blocks both manual writes',
        () async {
      var requests = 0;
      final service = manualService((_) async {
        requests++;
        return http.Response('{}', 201);
      }, token: () async => token);
      expect(await service.createProfile(
        userId: 'owner', name: 'Parent', city: 'Berlin',
      ), isNull);
      expect(service.lastSyncError, contains('Firebase-Anmeldung erforderlich'));
      expect(await service.recordAction(
        userId: 'owner', matchedProfileId: 'target', action: 'like',
      ), isFalse);
      expect(service.lastSyncError, contains('Firebase-Anmeldung erforderlich'));
      expect(requests, 0);
    });
  }

  test('failed Firebase token lookup prevents manual action send', () async {
    var requests = 0;
    final service = manualService((_) async {
      requests++;
      return http.Response('{}', 201);
    }, token: () async => throw StateError('Firebase token rejected'));
    expect(await service.recordAction(
      userId: 'owner', matchedProfileId: 'target', action: 'like',
    ), isFalse);
    expect(service.lastSyncError, contains('Firebase token rejected'));
    expect(requests, 0);
  });

  for (final status in [401, 403]) {
    test('rejected Firebase token $status fails explicitly without downgrade',
        () async {
      var requests = 0;
      final service = manualService((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer firebase-owner-token');
        return http.Response('{"error":"identity rejected"}', status);
      });
      expect(await service.createProfile(
        userId: 'owner', name: 'Parent', city: 'Berlin',
      ), isNull);
      expect(service.lastSyncError, contains('$status'));
      expect(await service.recordAction(
        userId: 'owner', matchedProfileId: 'target', action: 'like',
      ), isFalse);
      expect(service.lastSyncError, contains('$status'));
      expect(requests, 2);
    });
  }

  test('canonical endpoint unavailable does not trigger an unauthenticated retry',
      () async {
    var typedRequests = 0;
    var manualRequests = 0;
    final typedHttp = MockClient((request) async {
      typedRequests++;
      expect(request.headers['Authorization'], 'Bearer firebase-owner-token');
      return http.Response('{"error":"unavailable"}', 404);
    });
    final manualHttp = MockClient((_) async {
      manualRequests++;
      return http.Response('{}', 201);
    });
    addTearDown(typedHttp.close);
    addTearDown(manualHttp.close);
    final service = ParentMatchingBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        httpClient: typedHttp,
        authTokenProvider: () async => 'firebase-owner-token',
        requireAuthToken: true,
      ),
      httpClient: manualHttp,
      firebaseTokenProvider: () async => 'firebase-owner-token',
    );
    expect(await service.createProfile(
      userId: 'owner', name: 'Parent', city: 'Berlin',
    ), isNull);
    expect(service.lastSyncError, contains('404'));
    expect(typedRequests, 1);
    expect(manualRequests, 0);
  });
}
