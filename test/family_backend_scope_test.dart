import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/contracts/todo_contract.dart';
import 'package:parentpeak/logic/contracts/shopping_contract.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/shopping_backend_service.dart';
import 'package:parentpeak/logic/todo_backend_service.dart';
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

  BackendApiClient api(Future<http.Response> Function(http.Request) handler,
      {Future<String?> Function()? token, Future<String?> Function()? refresh}) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return BackendApiClient(
      baseUrl: 'https://backend.example',
      httpClient: client,
      authTokenProvider: token ?? () async => 'firebase-$uid',
      forceRefreshTokenProvider: refresh,
      requireAuthToken: true,
    );
  }

  Future<void> operation(bool shopping, String method, BackendApiClient client) async {
    final todo = TodoBackendService(apiClient: client, accountStore: store);
    final shop = ShoppingBackendService(apiClient: client, accountStore: store);
    switch (method) {
      case 'GET':
        if (shopping) { await shop.fetchItems(); } else { await todo.fetchTodos(); }
      case 'POST':
        if (shopping) {
          await shop.addItem(name: 'Food', category: 'General');
        } else {
          await todo.addTodo(title: 'Task', assignee: 'A', category: 'General');
        }
      case 'PUT':
        if (shopping) { await shop.updateChecked('id', true); } else { await todo.updateDone('id', true); }
      case 'DELETE':
        if (shopping) { await shop.deleteItem('id'); } else { await todo.deleteTodo('id'); }
    }
  }

  test('both contracts omit global family claims from create and update', () {
    final payloads = [
      TodoContract.buildCreatePayload(title: 'T', assignee: 'A', category: 'C'),
      TodoContract.buildUpdatePayload(done: true),
      ShoppingContract.buildCreatePayload(name: 'S', category: 'C'),
      ShoppingContract.buildUpdatePayload(checked: true),
    ];
    expect(payloads.every((p) => !p.containsKey('familyId')), isTrue);
  });

  for (final shopping in [false, true]) {
    for (final method in ['GET', 'POST', 'PUT', 'DELETE']) {
      final name = '${shopping ? 'shopping' : 'todo'} $method';
      test('$name uses Firebase and no remote family/UID claims', () async {
        final client = api((request) async {
          expect(request.headers['Authorization'], 'Bearer firebase-a');
          expect(request.url.queryParameters.containsKey('familyId'), isFalse);
          if (request.body.isNotEmpty) {
            final body = jsonDecode(request.body) as Map;
            expect(body.containsKey('familyId'), isFalse);
            expect(body.containsKey('userId'), isFalse);
          }
          return http.Response('{"items":[],"item":{"id":"id","title":"T","name":"S"}}', 200);
        });
        await operation(shopping, method, client);
      });
      for (final status in [401, 403, 503]) {
        test('$name $status is explicit, never an empty successful sync', () async {
          final client = api((_) async => http.Response('{"error":"Denied"}', status));
          await expectLater(operation(shopping, method, client),
              throwsA(isA<BackendApiException>().having((e) => e.statusCode, 'status', status)));
        });
      }
      test('$name rejects guest without HTTP', () async {
        var count = 0;
        uid = null;
        store.synchronize();
        await expectLater(operation(shopping, method, api((_) async {
          count++;
          return http.Response('{}', 200);
        })), throwsStateError);
        expect(count, 0);
      });
      test('$name discards response after account switch', () async {
        final started = Completer<void>(), response = Completer<http.Response>();
        final result = operation(shopping, method,
            api((_) { started.complete(); return response.future; }));
        final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
        await started.future;
        uid = 'b'; store.synchronize();
        response.complete(http.Response('{"items":[],"item":{"id":"id"}}', 200));
        await checked;
      });
    }
    test('${shopping ? 'shopping' : 'todo'} missing token sends no anonymous request', () async {
      var count = 0;
      await expectLater(operation(shopping, 'GET', api((_) async {
        count++; return http.Response('{}', 200);
      }, token: () async => null)), throwsStateError);
      expect(count, 0);
    });
    test('${shopping ? 'shopping' : 'todo'} invalid list shape is an error', () async {
      await expectLater(operation(shopping, 'GET',
          api((_) async => http.Response('{}', 200))), throwsFormatException);
    });
  }

  test('PUT retries once with refreshed token and identical body', () async {
    final requests = <http.Request>[];
    final client = api((request) async {
      requests.add(request);
      return http.Response('{}', requests.length == 1 ? 401 : 200);
    }, token: () async => 'old', refresh: () async => 'fresh');
    await operation(false, 'PUT', client);
    expect(requests.map((r) => r.headers['Authorization']), ['Bearer old', 'Bearer fresh']);
    expect(requests[0].body, requests[1].body);
  });
  test('PUT retry remains bounded when refreshed token is rejected', () async {
    var count = 0;
    await expectLater(operation(false, 'PUT', api((_) async {
      count++; return http.Response('{}', 401);
    }, refresh: () async => 'fresh')), throwsA(isA<BackendApiException>()));
    expect(count, 2);
  });
  test('PUT account switch during token resolution prevents HTTP', () async {
    final started = Completer<void>(), token = Completer<String?>();
    var count = 0;
    final result = operation(false, 'PUT', api((_) async {
      count++; return http.Response('{}', 200);
    }, token: () { started.complete(); return token.future; }));
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    uid = 'b'; store.synchronize();
    token.complete('firebase-b');
    await checked;
    expect(count, 0);
  });
  test('PUT account switch during refresh prevents old-family retry', () async {
    final started = Completer<void>(), token = Completer<String?>();
    var count = 0;
    final result = operation(true, 'PUT', api((_) async {
      count++; return http.Response('{}', 401);
    }, refresh: () { started.complete(); return token.future; }));
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    uid = 'b'; store.synchronize();
    token.complete('firebase-b');
    await checked;
    expect(count, 1);
  });
  test('same UID new session invalidates previous family ticket', () async {
    final todo = TodoBackendService(apiClient: api((_) async => http.Response('{}', 200)),
        accountStore: store);
    final old = store.ticket;
    uid = null; store.synchronize();
    uid = 'a'; store.synchronize();
    await expectLater(todo.fetchTodos(ticket: old), throwsA(isA<ProfileAccountChanged>()));
  });
  test('strict family lists preserve all supported list envelopes', () {
    for (final payload in [
      <Object>[],
      {'items': <Object>[]},
      {'data': <Object>[]},
      {'results': <Object>[]},
      {'data': {'items': <Object>[]}},
    ]) {
      expect(TodoContract.parseList(payload, strict: true), isEmpty);
      expect(ShoppingContract.parseList(payload, strict: true), isEmpty);
    }
    expect(() => TodoContract.parseList({'items': [null]}, strict: true), throwsFormatException);
    expect(() => ShoppingContract.parseList({'items': [42]}, strict: true), throwsFormatException);
  });
}
