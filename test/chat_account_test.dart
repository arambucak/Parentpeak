import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ChatAccountStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ChatAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());

  void change(String? next) {
    uid = next;
    store.synchronize();
  }

  test('independent legacy owner and explicit claim preserve original data', () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({'Schlaf': 3, 'Krise': 1});
    await prefs.setString(ChatAccountStore.legacyKey, raw);
    await prefs.setString('treasure.accounts.v1', '{"legacyOwner":"account.a","accounts":{}}');
    expect(await store.read(store.ticket), isEmpty);
    expect(await store.hasLegacy(store.ticket), isTrue);
    expect(await store.increment(store.ticket, 'Schlaf'), {'Schlaf': 1});
    expect(await store.claim(store.ticket), {'Schlaf': 4, 'Krise': 1});
    expect(await store.claim(store.ticket), {'Schlaf': 4, 'Krise': 1});
    expect(prefs.getString(ChatAccountStore.legacyKey), raw);
    final root = jsonDecode(prefs.getString(ChatAccountStore.storageKey)!);
    expect(root['legacyOwner'], 'account.a');
    expect(root['accounts']['account.a']['owner'], 'account.a');
    change('b');
    expect(await store.read(store.ticket), isEmpty);
    expect(await store.hasLegacy(store.ticket), isFalse);
    await expectLater(store.claim(store.ticket), throwsStateError);
  });

  test('guest never automatically adopts legacy and cannot claim it', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ChatAccountStore.legacyKey, '{"Schlaf":2}');
    change(null);
    expect(await store.read(store.ticket), isEmpty);
    await expectLater(store.claim(store.ticket), throwsStateError);
    await store.increment(store.ticket, 'Medien');
    change('b');
    expect(await store.read(store.ticket), isEmpty);
    expect(await store.claim(store.ticket), {'Schlaf': 2});
    change(null);
    expect(await store.read(store.ticket), {'Medien': 1});
  });

  test('topics and reset are account scoped and survive new instances', () async {
    await store.increment(store.ticket, 'Schlaf');
    change('b');
    await store.increment(store.ticket, 'Medien');
    expect(await store.reset(store.ticket), isEmpty);
    change('a');
    final reloaded = ChatAccountStore(userIdProvider: () => uid);
    addTearDown(reloaded.dispose);
    expect(await reloaded.read(reloaded.ticket), {'Schlaf': 1});
  });

  test('concurrent independent store writes serialize without losing counts', () async {
    final other = ChatAccountStore(userIdProvider: () => uid);
    addTearDown(other.dispose);
    await Future.wait([
      for (var i = 0; i < 10; i++)
        (i.isEven ? store : other).increment(
          (i.isEven ? store : other).ticket, 'Schlaf',
        ),
    ]);
    expect(await store.read(store.ticket), {'Schlaf': 10});
  });

  test('A to B to A invalidates original tickets', () async {
    final ticket = store.ticket;
    change('b');
    change('a');
    expect(() => store.require(ticket), throwsA(isA<ChatAccountChanged>()));
    await expectLater(store.increment(ticket, 'Schlaf'), throwsA(isA<ChatAccountChanged>()));
    expect(await store.read(store.ticket), isEmpty);
  });

  test('negative and thrown acks cannot claim or mutate topics; queue recovers', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ChatAccountStore.legacyKey, '{"Schlaf":2}');
    for (final throws in [false, true]) {
      final failed = ChatAccountStore(
        userIdProvider: () => uid,
        persist: (_, __) async {
          if (throws) throw StateError('No storage');
          return false;
        },
      );
      await expectLater(failed.claim(failed.ticket), throwsStateError);
      await expectLater(failed.increment(failed.ticket, 'Krise'), throwsStateError);
      expect(await failed.read(failed.ticket), isEmpty);
      expect(await failed.hasLegacy(failed.ticket), isTrue);
      failed.dispose();
    }
    expect(await store.claim(store.ticket), {'Schlaf': 2});
  });

  test('corrupt envelope and owner mismatches are not overwritten', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final raw in [
      'broken',
      '{"accounts":[]}',
      '{"accounts":{"account.a":{"owner":"account.b","topics":{}}}}',
      '{"accounts":{"account.a":{"owner":"account.a","topics":{"Schlaf":-1}}}}',
    ]) {
      await prefs.setString(ChatAccountStore.storageKey, raw);
      await expectLater(store.read(store.ticket), throwsFormatException);
      await expectLater(store.increment(store.ticket, 'Schlaf'), throwsFormatException);
      expect(prefs.getString(ChatAccountStore.storageKey), raw);
    }
  });

  test('invalid legacy types and ranges stay unassigned', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final raw in ['[]', '{"Schlaf":"2"}', '{"Schlaf":1.5}', '{"Schlaf":-1}']) {
      await prefs.setString(ChatAccountStore.legacyKey, raw);
      await expectLater(store.claim(store.ticket), throwsFormatException);
      expect(prefs.getString(ChatAccountStore.legacyKey), raw);
      expect(await store.hasLegacy(store.ticket), isTrue);
    }
  });

  test('pending old write remains old-account only and yields no new result', () async {
    final pending = Completer<bool>();
    final prefs = await SharedPreferences.getInstance();
    final slow = ChatAccountStore(
      userIdProvider: () => uid,
      persist: (key, raw) async {
        await pending.future;
        return prefs.setString(key, raw);
      },
    );
    addTearDown(slow.dispose);
    final write = slow.increment(slow.ticket, 'Schlaf');
    final rejected = expectLater(write, throwsA(isA<ChatAccountChanged>()));
    await Future<void>.delayed(Duration.zero);
    uid = 'b';
    slow.synchronize();
    pending.complete(true);
    await rejected;
    expect(await slow.read(slow.ticket), isEmpty);
    uid = 'a';
    slow.synchronize();
    expect(await slow.read(slow.ticket), {'Schlaf': 1});
  });

  test('token resolving after account switch cannot dispatch old chat', () async {
    final token = Completer<String?>();
    final consent = ChatAiConsent(scopeProvider: () => store.scope);
    await consent.grant(store.scope);
    final calls = <http.Request>[];
    final backend = PedagogicalChatBackend(
      accountStore: store, consent: consent,
      geminiService: GeminiAIService(apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        authTokenProvider: () => token.future,
        httpClient: MockClient((request) async {
          calls.add(request);
          return http.Response('{"text":"Reply"}', 200);
        }),
      )),
    );
    final result = backend.streamReply(history: const [], userMessage: 'Wie begleiten wir das Einschlafen abends?').toList();
    final rejected = expectLater(result, throwsA(isA<ChatAccountChanged>()));
    await Future<void>.delayed(Duration.zero);
    change('b');
    await consent.grant(store.scope);
    token.complete('new-account-token');
    await rejected;
    expect(calls, isEmpty);
  });

  test('401 refresh cannot resend old chat under a new account', () async {
    final refreshed = Completer<String?>();
    final started = Completer<void>();
    final ticket = store.ticket;
    var calls = 0;
    final client = BackendApiClient(
      baseUrl: 'https://example.invalid',
      authToken: 'old',
      forceRefreshTokenProvider: () { started.complete(); return refreshed.future; },
      httpClient: MockClient((_) async { calls++; return http.Response('{}', 401); }),
    ).withRequestGuard(() => store.require(ticket));
    final rejected = expectLater(client.postJson('/ai/generate', {'prompt': 'old'}), throwsA(isA<ChatAccountChanged>()));
    await started.future;
    change('b');
    refreshed.complete('new');
    await rejected;
    expect(calls, 1);
  });

  test('memory token and late reply are bounded to original generation', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final service = AiMemoryService(
      accountStore: store,
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient((_) { started.complete(); return pending.future; }),
      ),
    );
    final rejected = expectLater(service.getChildren(), throwsA(isA<ChatAccountChanged>()));
    await started.future;
    change('b');
    change('a');
    pending.complete(http.Response('{"items":[{"id":"old","name":"Private child"}]}', 200));
    await rejected;
  });

  test('memory mutation cannot dispatch after its token wait changes account', () async {
    final token = Completer<String?>();
    final started = Completer<void>();
    var calls = 0;
    final service = AiMemoryService(accountStore: store, apiClient: BackendApiClient(
      baseUrl: 'https://example.invalid',
      authTokenProvider: () { started.complete(); return token.future; },
      httpClient: MockClient((_) async { calls++; return http.Response('{}', 200); }),
    ));
    final rejected = expectLater(service.createChild(name: 'Private child'), throwsA(isA<ChatAccountChanged>()));
    await started.future;
    change('b');
    token.complete('new');
    await rejected;
    expect(calls, 0);
  });
}
