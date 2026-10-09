import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friend_chat_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ProfileAccountStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());

  FriendChatService service(http.Client client,
      {Future<String?> Function()? token, Future<String?> Function()? refresh}) {
    addTearDown(client.close);
    return FriendChatService(
      accountStore: store,
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authTokenProvider: token ?? () async => 'firebase-a',
        forceRefreshTokenProvider: refresh,
        requireAuthToken: true,
        httpClient: client,
      ),
    );
  }

  test('six chat operations send token but no remote owner claims', () async {
    final requests = <http.Request>[];
    final chat = service(MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer firebase-a');
      expect(request.url.queryParameters.containsKey('userId'), isFalse);
      if (request.method == 'POST') {
        expect((jsonDecode(request.body) as Map).containsKey('userId'), isFalse);
      }
      if (request.url.path.endsWith('overview')) {
        return http.Response('{"conversations":[]}', 200);
      }
      if (request.url.path.endsWith('messages')) {
        return http.Response(request.method == 'GET'
            ? '{"messages":[]}' : '{"item":{"id":"m","authorUserId":"a"}}',
            request.method == 'GET' ? 200 : 201);
      }
      return http.Response('{"ok":true}', 200);
    }));
    final ticket = store.ticket;
    await chat.fetchOverview('a');
    await chat.fetchMessages('a__b', ticket);
    await chat.sendMessage('a__b', 'Hello', 'A', ticket);
    await chat.markRead('a__b', 'a');
    expect(await chat.clearForMe('a__b', 'a'), isTrue);
    expect(await chat.deleteForAll('a__b', 'a'), isTrue);
    expect(requests.length, 6);
  });

  for (final operation in ['read', 'send', 'leave']) {
    test('$operation retries 401 once with refreshed token, never anonymously', () async {
      var count = 0;
      final headers = <String?>[];
      final chat = service(MockClient((request) async {
        headers.add(request.headers['Authorization']);
        if (++count == 1) return http.Response('{}', 401);
        return http.Response(
            operation == 'read' ? '{"messages":[]}' : '{"item":{"id":"m"}}', 200);
      }), token: () async => 'old', refresh: () async => 'fresh');
      if (operation == 'read') {
        await chat.fetchMessages('a__b', store.ticket);
      } else if (operation == 'send') {
        await chat.sendMessage('a__b', 'Hello', 'A', store.ticket);
      } else {
        expect(await chat.leaveGroup('g', 'a'), isTrue);
      }
      expect(headers, ['Bearer old', 'Bearer fresh']);
    });
  }

  for (final status in [403, 503]) {
    test('read $status is an explicit typed failure, not an empty archive', () async {
      final chat = service(MockClient((_) async =>
          http.Response('{"error":"Unavailable","code":"not_participant"}', status)));
      await expectLater(chat.fetchMessages('a__b', store.ticket),
          throwsA(isA<BackendApiException>().having((e) => e.statusCode, 'status', status)));
      await expectLater(chat.fetchOverview('a'), throwsA(isA<BackendApiException>()));
      await expectLater(chat.fetchMembers('g'), throwsA(isA<BackendApiException>()));
    });
  }

  test('send not_friends remains distinct from not_participant', () async {
    final chat = service(MockClient((_) async =>
        http.Response('{"error":"Archive","code":"not_friends"}', 403)));
    await expectLater(chat.sendMessage('a__b', 'Hello', 'A', store.ticket),
        throwsA(isA<BackendApiException>().having((e) => e.serverCode, 'code', 'not_friends')));
  });

  test('missing Firebase token fails locally without an anonymous request', () async {
    var requests = 0;
    final chat = service(MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    }), token: () async => null);
    await expectLater(chat.fetchMessages('a__b', store.ticket), throwsStateError);
    expect(requests, 0);
  });

  test('strict client rejects shared static token as an identity fallback', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final api = BackendApiClient(
      baseUrl: 'https://backend.example',
      authToken: 'shared-backend-token',
      authTokenProvider: () async => null,
      requireAuthToken: true,
      httpClient: client,
    );
    await expectLater(api.getJson('/friend-chat/messages'), throwsStateError);
    expect(requests, 0);
  });

  test('empty refreshed token cannot trigger an anonymous retry', () async {
    final headers = <String?>[];
    final chat = service(MockClient((request) async {
      headers.add(request.headers['Authorization']);
      return http.Response('{}', 401);
    }), refresh: () async => '');
    await expectLater(chat.fetchMessages('a__b', store.ticket),
        throwsA(isA<BackendApiException>()));
    expect(headers.length, 2);
    expect(headers.every((header) => header != null && header.isNotEmpty), isTrue);
  });

  test('account switch during token lookup sends no old-room request', () async {
    final started = Completer<void>(), token = Completer<String?>();
    var requests = 0;
    final chat = service(MockClient((_) async {
      requests++;
      return http.Response('{"messages":[]}', 200);
    }), token: () { started.complete(); return token.future; });
    final result = chat.fetchMessages('a__b', store.ticket);
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    uid = 'b';
    store.synchronize();
    token.complete('firebase-b');
    await checked;
    expect(requests, 0);
  });

  test('account switch discards an in-flight response', () async {
    final started = Completer<void>(), response = Completer<http.Response>();
    final chat = service(MockClient((_) { started.complete(); return response.future; }));
    final result = chat.fetchMessages('a__b', store.ticket);
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    uid = 'b';
    store.synchronize();
    response.complete(http.Response('{"messages":[{"content":"Private A"}]}', 200));
    await checked;
  });

  test('account switch during refresh prevents a retry', () async {
    final started = Completer<void>(), refreshed = Completer<String?>();
    var requests = 0;
    final chat = service(MockClient((_) async {
      requests++;
      return http.Response('{}', 401);
    }), refresh: () { started.complete(); return refreshed.future; });
    final result = chat.fetchMessages('a__b', store.ticket);
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    uid = 'b';
    store.synchronize();
    refreshed.complete('firebase-b');
    await checked;
    expect(requests, 1);
  });

  test('old navigation UID cannot write read/clear markers on new account', () async {
    var requests = 0;
    final chat = service(MockClient((_) async {
      requests++;
      return http.Response('{"ok":true}', 200);
    }));
    uid = 'b';
    store.synchronize();
    await expectLater(chat.markRead('a__c', 'a'), throwsA(isA<ProfileAccountChanged>()));
    expect(await chat.clearForMe('a__c', 'a'), isFalse);
    expect(requests, 0);
  });

  test('same-UID logout/login invalidates old chat ticket', () async {
    final ticket = store.ticket;
    final chat = service(MockClient((_) async => http.Response('{"messages":[]}', 200)));
    uid = null;
    store.synchronize();
    uid = 'a';
    store.synchronize();
    await expectLater(chat.fetchMessages('a__b', ticket), throwsA(isA<ProfileAccountChanged>()));
  });

  test('group actor claims are omitted and leave is locally owner-bound', () async {
    final requests = <http.Request>[];
    final chat = service(MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        final payload = jsonDecode(request.body) as Map;
        expect(payload.containsKey('ownerUserId'), isFalse);
        expect(payload.containsKey('actingUserId'), isFalse);
      }
      return http.Response('{"group":{"id":"g","ownerUserId":"a"},"ok":true}', 200);
    }));
    await chat.createGroup(name: 'Group', ownerUserId: 'a', ownerName: 'A');
    expect(await chat.addMembers(groupId: 'g', actingUserId: 'a', memberUids: ['b']), isTrue);
    expect(await chat.leaveGroup('g', 'b'), isFalse);
    expect(requests.length, 2);
  });

  test('malformed messages response is an error, not an empty list', () async {
    final chat = service(MockClient((_) async => http.Response('{"ok":true}', 200)));
    await expectLater(chat.fetchMessages('a__b', store.ticket), throwsFormatException);
  });
}
