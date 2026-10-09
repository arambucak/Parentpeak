import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/notification_account_binding.dart';

void main() {
  late String? uid;
  late String token;
  late int deleted;
  late int cancelled;
  late List<String> requests;
  late NotificationAccountBinding binding;
  late BackendApiClient client;

  setUp(() {
    uid = 'a';
    token = 'device-1';
    deleted = 0;
    cancelled = 0;
    requests = [];
    client = BackendApiClient(
      baseUrl: 'https://backend.example',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add('${request.method}:${body['userId']}:${body['token']}');
        return http.Response('{}', 200);
      }),
    );
    binding = NotificationAccountBinding(
      currentUserId: () => uid,
      getToken: () async => token,
      deleteToken: () async {
        deleted++;
        token = 'device-$deleted-new';
      },
      cancelReminders: () async {
        cancelled++;
      },
    );
  });

  test(
    'account switch unregisters A then binds fresh device token to B',
    () async {
      await binding.bind('a', client);
      uid = 'b';
      await binding.bind('b', client);
      expect(requests, [
        'POST:a:device-1',
        'DELETE:a:device-1',
        'POST:b:device-1-new',
      ]);
      expect(deleted, 1);
      expect(cancelled, 1);
      expect(binding.acceptsMessage('a'), isFalse);
      expect(binding.acceptsMessage('b'), isTrue);
    },
  );

  test(
    'logout deregisters token, invalidates it and cancels reminders',
    () async {
      await binding.bind('a', client);
      final ending = binding.endSession();
      expect(binding.isActive, isFalse);
      await ending;
      await binding.refresh('late-refresh');
      expect(requests, ['POST:a:device-1', 'DELETE:a:device-1']);
      expect(deleted, 1);
      expect(cancelled, 1);
    },
  );

  test('refresh uses current owner, never the first listener owner', () async {
    await binding.bind('a', client);
    uid = 'b';
    await binding.bind('b', client);
    await binding.refresh('refreshed-b');
    expect(requests.sublist(3), [
      'DELETE:b:device-1-new',
      'POST:b:refreshed-b',
    ]);
  });

  test('pending token acquisition cannot bind after logout', () async {
    final gate = Completer<String?>();
    binding = NotificationAccountBinding(
      currentUserId: () => uid,
      getToken: () => gate.future,
      deleteToken: () async {
        deleted++;
      },
      cancelReminders: () async {
        cancelled++;
      },
    );
    final registering = binding.bind('a', client);
    final rejected = expectLater(
      registering,
      throwsA(isA<NotificationAccountChanged>()),
    );
    await Future<void>.delayed(Duration.zero);
    final ending = binding.endSession();
    gate.complete('late-token');
    await rejected;
    await ending;
    expect(requests, isEmpty);
    expect(cancelled, 1);
  });

  test(
    'server cleanup failure still invalidates device token and reminders',
    () async {
      final failing = BackendApiClient(
        baseUrl: 'https://backend.example',
        httpClient: MockClient(
          (request) async =>
              http.Response('{}', request.method == 'DELETE' ? 503 : 200),
        ),
      );
      await binding.bind('a', failing);
      await expectLater(binding.endSession(), throwsException);
      expect(deleted, 1);
      expect(cancelled, 1);
      expect(binding.isActive, isFalse);
    },
  );

  test('no session or foreign owner cannot register', () async {
    uid = null;
    await expectLater(
      binding.bind('a', client),
      throwsA(isA<NotificationAccountChanged>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'session guard prevents HTTP after token-provider account change',
    () async {
      final guarded = BackendApiClient(
        baseUrl: 'https://backend.example',
        authTokenProvider: () async {
          uid = 'b';
          return 'b-token';
        },
        httpClient: MockClient((_) async {
          fail('Stale registration sent');
        }),
      );
      await expectLater(
        binding.bind('a', guarded),
        throwsA(isA<NotificationAccountChanged>()),
      );
    },
  );

  test(
    'late registration acknowledgement is cleaned up after logout',
    () async {
      final started = Completer<void>();
      final gate = Completer<http.Response>();
      final slow = BackendApiClient(
        baseUrl: 'https://backend.example',
        httpClient: MockClient((request) async {
          requests.add(request.method);
          if (request.method == 'POST') {
            started.complete();
            return gate.future;
          }
          return http.Response('{}', 200);
        }),
      );
      final registering = binding.bind('a', slow);
      final rejected = expectLater(
        registering,
        throwsA(isA<NotificationAccountChanged>()),
      );
      await started.future;
      final ending = binding.endSession();
      gate.complete(http.Response('{}', 200));
      await rejected;
      await ending;
      expect(requests, ['POST', 'DELETE']);
      expect(deleted, 1);
      expect(cancelled, 1);
    },
  );

  test(
    'failed registration is retried rather than treated as success',
    () async {
      var attempts = 0;
      final retry = BackendApiClient(
        baseUrl: 'https://backend.example',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') attempts++;
          return http.Response(
            '{}',
            attempts == 1 && request.method == 'POST' ? 503 : 200,
          );
        }),
      );
      await expectLater(binding.bind('a', retry), throwsException);
      await binding.bind('a', retry);
      expect(attempts, 2);
    },
  );
}
