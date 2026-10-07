import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_memory_consent.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/ui/ai_memory_settings_screen.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ChatAccountStore store;
  late ChatMemoryConsent consent;
  late List<http.Request> calls;
  late bool enabled;
  late Future<http.Response> Function(http.Request) respond;

  AiMemoryService service({
    Future<bool> Function(String, String)? persistName,
  }) => AiMemoryService(
    accountStore: store,
    consent: consent,
    persistName: persistName,
    apiClient: BackendApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) {
        calls.add(request);
        return respond(request);
      }),
    ),
  );

  GeminiAIService gemini() => GeminiAIService(
    memoryConsent: consent,
    apiClient: BackendApiClient(
      baseUrl: 'https://example.invalid',
      httpClient: MockClient((request) {
        calls.add(request);
        return respond(request);
      }),
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ChatAccountStore(userIdProvider: () => uid);
    consent = ChatMemoryConsent(scopeProvider: () => store.scope);
    calls = [];
    enabled = false;
    respond = (request) async {
      final path = request.url.path;
      if (path == '/ai/settings') {
        if (request.method == 'PUT') {
          enabled = jsonDecode(request.body)['enabled'] == true;
        }
        return http.Response(
          jsonEncode({
            'enabled': enabled,
            'consentVersion': enabled ? ChatMemoryConsent.version : null,
          }),
          200,
        );
      }
      if (path == '/ai/children' && request.method == 'GET') {
        return http.Response(
          '{"items":[{"id":"c1","name":"[CHILD_1]","memoryItems":[]}]}',
          200,
        );
      }
      if (path == '/ai/generate') {
        return http.Response('{"text":"[CHILD_1] needs a calm evening."}', 200);
      }
      return http.Response(
        '{"item":{"id":"c1","userId":"a","name":"[CHILD_1]","childId":"c1","value":"saved"}}',
        200,
      );
    };
  });
  tearDown(() => store.dispose());

  test(
    'old flags and chat consent do not authorize memory; account and guest are separate',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat.terms_accepted', true);
      await prefs.setBool('chat.ai_consent.v1.account.a', true);
      expect(await consent.hasConsent(), isFalse);
      await consent.grant(store.scope);
      expect(await consent.hasConsent(), isTrue);
      uid = 'b';
      store.synchronize();
      expect(await consent.hasConsent(), isFalse);
      uid = null;
      store.synchronize();
      expect(await consent.hasConsent(), isFalse);
    },
  );

  test(
    'false and thrown local consent acknowledgments do not enable memory',
    () async {
      for (final throws in [false, true]) {
        consent = ChatMemoryConsent(
          scopeProvider: () => store.scope,
          persist: (key, value) async {
            if (throws) throw StateError('disk failure');
            return false;
          },
        );
        await expectLater(consent.grant(store.scope), throwsStateError);
        expect(await consent.hasConsent(), isFalse);
        await expectLater(
          service().setEnabled(true),
          throwsA(isA<ChatMemoryConsentRequiredException>()),
        );
        expect(calls, isEmpty);
      }
    },
  );

  test(
    'all new profile and memory writes are blocked without explicit consent',
    () async {
      final memory = service();
      for (final operation in [
        () => memory.createChild(name: 'Ada'),
        () => memory.updateChild('c1', name: 'Ada'),
        () => memory.saveMemory(
          'c1',
          category: 'medical',
          key: 'eczema',
          value: 'Ada needs care',
        ),
      ]) {
        await expectLater(
          operation(),
          throwsA(isA<ChatMemoryConsentRequiredException>()),
        );
      }
      expect(calls, isEmpty);
    },
  );

  test(
    'actual child payload is neutral and display name is local, account-bound and reloadable',
    () async {
      await consent.grant(store.scope);
      final child = await service().createChild(name: ' Ada ');
      expect(child.name, 'Ada');
      final body = jsonDecode(calls.single.body);
      expect(body['name'], '[CHILD_1]');
      expect(body['memoryConsentVersion'], ChatMemoryConsent.version);
      expect(calls.single.body, isNot(contains('Ada')));
      expect((await service().getChildren()).first.name, 'Ada');
      uid = 'b';
      store.synchronize();
      expect((await service().getChildren()).first.name, '[CHILD_1]');
    },
  );

  test(
    'memory value payload removes known local names before persistent write',
    () async {
      await consent.grant(store.scope);
      await service().createChild(name: 'Ada');
      calls.clear();
      await service().saveMemory(
        'c1',
        category: 'medical',
        key: 'Ada',
        value: 'ada needs skin care',
      );
      final write = calls.last;
      expect(jsonDecode(write.body)['value'], '[THIS_CHILD] needs skin care');
      expect(jsonDecode(write.body)['key'], '[THIS_CHILD]');
      expect(write.body, isNot(contains('Ada')));
    },
  );

  test(
    'failed local-name ack reports the real partial state, not complete success',
    () async {
      await consent.grant(store.scope);
      await expectLater(
        service(
          persistName: (key, value) async => false,
        ).createChild(name: 'Ada'),
        throwsA(isA<MemoryLocalNameWriteException>()),
      );
      expect(calls, hasLength(1));
      expect(jsonDecode(calls.single.body)['name'], '[CHILD_1]');
      expect((await service().getChildren()).first.name, '[CHILD_1]');
    },
  );

  test(
    'ordinary AI request omits all memory fields when consent is absent',
    () async {
      await gemini().generateText(
        'How can we support bedtime?',
        childProfileId: 'c1',
      );
      final body = jsonDecode(calls.single.body);
      expect(body.containsKey('childProfileId'), isFalse);
      expect(body.containsKey('memoryConsentVersion'), isFalse);
    },
  );

  test(
    'consented AI request includes exact version; revocation blocks late result',
    () async {
      await consent.grant(store.scope);
      final pending = Completer<http.Response>(), started = Completer<void>();
      respond = (_) {
        started.complete();
        return pending.future;
      };
      final result = gemini().generateText(
        'How can we support bedtime?',
        childProfileId: 'c1',
      );
      final rejected = expectLater(
        result,
        throwsA(isA<ChatMemoryConsentRequiredException>()),
      );
      await started.future;
      final body = jsonDecode(calls.single.body);
      expect(body['childProfileId'], 'c1');
      expect(body['memoryConsentVersion'], ChatMemoryConsent.version);
      await consent.revoke(store.scope);
      pending.complete(http.Response('{"text":"private response"}', 200));
      await rejected;
    },
  );

  test(
    'server memory rejection is a consent failure, not successful provider text',
    () async {
      await consent.grant(store.scope);
      respond = (_) async => http.Response(
        '{"error":"Memory consent changed","code":"MEMORY_CONSENT_REQUIRED"}',
        403,
      );
      await expectLater(
        gemini().chatWithHistory([
          {'role': 'user', 'content': 'Bedtime support'},
        ], childProfileId: 'c1'),
        throwsA(isA<ChatMemoryConsentRequiredException>()),
      );
      expect(calls, hasLength(1));
    },
  );

  test(
    'malformed identity response blocks memory persistence instead of bypassing minimization',
    () async {
      await consent.grant(store.scope);
      respond = (_) async => http.Response('{"items":[null]}', 200);
      await expectLater(
        service().saveMemory(
          'c1',
          category: 'note',
          key: 'sleep',
          value: 'Ada',
        ),
        throwsFormatException,
      );
      expect(calls.every((request) => request.method == 'GET'), isTrue);
    },
  );

  test(
    'deleting a profile removes its account-local display name too',
    () async {
      await consent.grant(store.scope);
      final memory = service();
      await memory.createChild(name: 'Ada');
      await memory.deleteChild('c1');
      expect((await memory.getChildren()).first.name, '[CHILD_1]');
    },
  );

  test(
    'memory revoke during token wait prevents dispatch and 401 retry',
    () async {
      for (final retry in [false, true]) {
        calls.clear();
        await consent.grant(store.scope);
        final token = Completer<String?>(), started = Completer<void>();
        final client = BackendApiClient(
          baseUrl: 'https://example.invalid',
          authTokenProvider: () async => retry
              ? 'old'
              : await (() {
                  started.complete();
                  return token.future;
                })(),
          forceRefreshTokenProvider: () {
            started.complete();
            return token.future;
          },
          httpClient: MockClient((request) async {
            calls.add(request);
            return http.Response('{}', 401);
          }),
        );
        final ai = GeminiAIService(apiClient: client, memoryConsent: consent);
        final rejected = expectLater(
          ai.generateText('Bedtime support', childProfileId: 'c1'),
          throwsA(isA<ChatMemoryConsentRequiredException>()),
        );
        await started.future;
        await consent.revoke(store.scope);
        token.complete('new');
        await rejected;
        expect(calls, hasLength(retry ? 1 : 0));
      }
    },
  );

  test(
    'account switch during memory consent grant cannot authorize the new account',
    () async {
      final ack = Completer<bool>(), started = Completer<void>();
      consent = ChatMemoryConsent(
        scopeProvider: () => store.scope,
        persist: (key, value) {
          started.complete();
          return ack.future;
        },
      );
      final rejected = expectLater(
        consent.grant(store.scope),
        throwsA(isA<ChatMemoryConsentRequiredException>()),
      );
      await started.future;
      uid = 'b';
      store.synchronize();
      ack.complete(true);
      await rejected;
      expect(await consent.hasConsent(), isFalse);
    },
  );

  test(
    'failed local revocation ack stays closed in RAM and server disable is acknowledged separately',
    () async {
      consent = ChatMemoryConsent(
        scopeProvider: () => store.scope,
        persist: (key, value) async => value
            ? await (await SharedPreferences.getInstance()).setBool(key, value)
            : false,
      );
      await consent.grant(store.scope);
      enabled = true;
      await expectLater(service().setEnabled(false), throwsStateError);
      expect(enabled, isFalse);
      expect(await consent.hasConsent(), isFalse);
      expect((await service().getSettings()).enabled, isFalse);
      await gemini().generateText('Bedtime support', childProfileId: 'c1');
      expect(
        jsonDecode(calls.last.body).containsKey('childProfileId'),
        isFalse,
      );
    },
  );

  test(
    'withdrawing memory consent during a coaching repair prevents a third request',
    () async {
      await consent.grant(store.scope);
      final chatConsent = ChatAiConsent(scopeProvider: () => store.scope);
      await chatConsent.grant(store.scope);
      var count = 0;
      respond = (_) async {
        count++;
        if (count == 2) await consent.revoke(store.scope);
        return http.Response('{"text":"Try a calm routine."}', 200);
      };
      final backend = PedagogicalChatBackend(
        accountStore: store,
        consent: chatConsent,
        geminiService: gemini(),
      );
      await expectLater(
        backend
            .streamReply(
              history: const [],
              userMessage: 'Wie begleiten wir das Einschlafen abends?',
              childProfileId: 'c1',
            )
            .toList(),
        throwsA(isA<ChatMemoryConsentRequiredException>()),
      );
      expect(count, 2);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Widget screen,
    String language,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['de', 'en', 'tr', 'ku']) {
    testWidgets('$language refusal sends no enable/write/AI request', (
      tester,
    ) async {
      await mount(tester, AiMemorySettingsScreen(service: service()), language);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        find.text(
          AppStringsManager.getString(language, 'memory_consent_title'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(AppStringsManager.getString(language, 'memory_consent_body')),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppStringsManager.getString(language, 'cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(calls.where((request) => request.method != 'GET'), isEmpty);
      expect(await consent.hasConsent(), isFalse);
    });
  }

  testWidgets(
    'failed local consent save is visible and makes no enabling request',
    (tester) async {
      consent = ChatMemoryConsent(
        scopeProvider: () => store.scope,
        persist: (key, value) async => false,
      );
      await mount(tester, AiMemorySettingsScreen(service: service()), 'en');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow storage and AI use'));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsManager.getString('en', 'memory_operation_failed')),
        findsOneWidget,
      );
      expect(calls.where((request) => request.method != 'GET'), isEmpty);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets(
    'accepted consent precedes acknowledged server enable; switching off revokes locally',
    (tester) async {
      await mount(tester, AiMemorySettingsScreen(service: service()), 'en');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow storage and AI use'));
      await tester.pumpAndSettle();
      expect(await consent.hasConsent(), isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(
        jsonDecode(
          calls.firstWhere((request) => request.method == 'PUT').body,
        )['memoryConsentVersion'],
        ChatMemoryConsent.version,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(await consent.hasConsent(), isFalse);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(calls.where((request) => request.method == 'DELETE'), isEmpty);
    },
  );

  testWidgets(
    'open additional consent closes on account switch without granting or writing',
    (tester) async {
      await mount(tester, AiMemorySettingsScreen(service: service()), 'en');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      uid = 'b';
      store.synchronize();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await consent.hasConsent(), isFalse);
      expect(calls.where((request) => request.method != 'GET'), isEmpty);
    },
  );

  testWidgets(
    'local-name save failure reports existing neutral backend profile visibly',
    (tester) async {
      await consent.grant(store.scope);
      enabled = true;
      await mount(
        tester,
        AiMemorySettingsScreen(
          service: service(persistName: (key, value) async => false),
        ),
        'en',
      );
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Ada');
      await tester.tap(find.text(AppStringsManager.getString('en', 'save')));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsManager.getString('en', 'memory_name_save_failed')),
        findsOneWidget,
      );
      expect(calls.where((request) => request.method == 'POST'), hasLength(1));
      expect(calls.every((request) => !request.body.contains('Ada')), isTrue);
    },
  );

  testWidgets(
    'display replaces neutral response locally; next real HTTP history retains placeholder',
    (tester) async {
      await consent.grant(store.scope);
      final memory = service();
      await memory.createChild(name: 'Ada');
      enabled = true;
      final chatConsent = ChatAiConsent(scopeProvider: () => store.scope);
      await chatConsent.grant(store.scope);
      final backend = PedagogicalChatBackend(
        accountStore: store,
        consent: chatConsent,
        geminiService: gemini(),
      );

      respond = (request) async {
        if (request.url.path == '/ai/settings') {
          return http.Response(
            '{"enabled":true,"consentVersion":"chat-memory-v1"}',
            200,
          );
        }
        if (request.url.path == '/ai/children') {
          return http.Response(
            '{"items":[{"id":"c1","name":"[CHILD_1]"}]}',
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'text':
                'Das klingt herausfordernd. [CHILD_1] braucht beim Einschlafen eine ruhige Wahl. Du könntest daneben bleiben. Was passiert bei euch vorher?',
          }),
          200,
        );
      };
      calls.clear();
      await mount(
        tester,
        ChatScreen(chatBackend: backend, memoryService: memory),
        'de',
      );
      for (var index = 0; index < 2; index++) {
        await tester.enterText(
          find.byType(TextField),
          'Wie begleiten wir das Einschlafen abends?',
        );
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
      }
      expect(
        find.textContaining('Ada braucht', findRichText: true),
        findsWidgets,
      );
      final aiCalls = calls
          .where((call) => call.url.path == '/ai/generate')
          .toList();
      expect(aiCalls.length, greaterThanOrEqualTo(2));
      expect(aiCalls.every((call) => !call.body.contains('Ada')), isTrue);
      expect(aiCalls.last.body, contains('[CHILD_1]'));
    },
  );
}
