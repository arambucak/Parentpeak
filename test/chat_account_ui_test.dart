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
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/chat_memory_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/ui/ai_memory_settings_screen.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _question = 'Wie begleiten wir das Einschlafen abends?';
const _answer =
    'Das klingt gerade herausfordernd. Du könntest beim Einschlafen '
    'abends eine ruhige Wahl anbieten und daneben präsent bleiben. '
    'Was passiert bei euch direkt vor dieser Situation?';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ChatAccountStore store;
  late ChatAiConsent consent;
  late PedagogicalChatBackend backend;
  late AiMemoryService memory;
  late ChatMemoryConsent memoryConsent;
  late List<http.Request> calls;
  late List<http.Request> memoryCalls;
  late Future<http.Response> Function(http.Request) aiResponse;
  late Future<http.Response> Function(http.Request) memoryResponse;

  void configure() {
    consent = ChatAiConsent(scopeProvider: () => store.scope);
    memoryConsent = ChatMemoryConsent(scopeProvider: () => store.scope);
    backend = PedagogicalChatBackend(
      accountStore: store,
      consent: consent,
      geminiService: GeminiAIService(
        memoryConsent: memoryConsent,
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) {
            calls.add(request);
            return aiResponse(request);
          }),
        ),
      ),
    );
    memory = AiMemoryService(
      consent: memoryConsent,
      accountStore: store,
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient((request) {
          memoryCalls.add(request);
          return memoryResponse(request);
        }),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ChatAccountStore(userIdProvider: () => uid);
    calls = [];
    memoryCalls = [];
    aiResponse = (_) async => http.Response(jsonEncode({'text': _answer}), 200);
    memoryResponse = (request) async => http.Response(
      request.url.path == '/ai/settings'
          ? '{"enabled":false}'
          : uid == 'a'
          ? '{"items":[{"id":"child-a","name":"Private child","memoryItems":[]}]}'
          : '{"items":[]}',
      200,
    );
    configure();
  });
  tearDown(() => store.dispose());

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    String language = 'en',
  }) async {
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
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chat(WidgetTester tester) async {
    await consent.grant(store.scope);
    await mount(
      tester,
      ChatScreen(chatBackend: backend, memoryService: memory),
    );
  }

  Future<void> switchAccount(WidgetTester tester, String? next) async {
    uid = next;
    store.synchronize();
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, {bool settle = true}) async {
    await tester.enterText(find.byType(TextField), _question);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets(
    'logout clears history, input, feedback, topics and does not restore RAM',
    (tester) async {
      await chat(tester);
      await send(tester);
      expect(find.text(_answer, findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Private unsent text');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await switchAccount(tester, null);
      expect(controller.text, isEmpty);
      expect(find.text(_question), findsNothing);
      expect(find.text(_answer), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await switchAccount(tester, 'a');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(_question), findsNothing);
      expect(find.text(_answer), findsNothing);
      expect(await store.read(store.ticket), {'Schlaf': 1});
      expect(calls, hasLength(1));
    },
  );

  testWidgets('late A response cannot pollute B or a later A session', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    aiResponse = (_) => pending.future;
    await chat(tester);
    await send(tester, settle: false);
    expect(calls, hasLength(1));
    uid = 'b';
    await consent.grant('account.b');
    store.synchronize();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await switchAccount(tester, 'a');
    pending.complete(http.Response(jsonEncode({'text': _answer}), 200));
    await tester.pumpAndSettle();
    expect(find.text(_answer), findsNothing);
    expect(find.text(_question), findsNothing);
    expect(calls, hasLength(1));
  });

  testWidgets('chat deletion invalidates an in-flight answer', (tester) async {
    final pending = Completer<http.Response>();
    aiResponse = (_) => pending.future;
    await chat(tester);
    await send(tester, settle: false);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(http.Response(jsonEncode({'text': _answer}), 200));
    await tester.pumpAndSettle();
    expect(find.text(_answer), findsNothing);
    expect(find.text(_question), findsNothing);
    expect(calls, hasLength(1));
  });

  testWidgets(
    'old keyboard callback cannot submit private text in a new account',
    (tester) async {
      await chat(tester);
      final callback = tester
          .widget<TextField>(find.byType(TextField))
          .onSubmitted!;
      uid = 'b';
      await consent.grant('account.b');
      store.synchronize();
      await tester.pumpAndSettle();
      callback('Private old input');
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Private old input'), findsNothing);
      expect(await store.read(store.ticket), isEmpty);
    },
  );

  testWidgets('rapid submissions have one origin-bound request', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    aiResponse = (_) => pending.future;
    await chat(tester);
    await tester.enterText(find.byType(TextField), _question);
    final field = tester.widget<TextField>(find.byType(TextField));
    field.onSubmitted!(_question);
    field.onSubmitted!(_question);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, hasLength(1));
    pending.complete(http.Response(jsonEncode({'text': _answer}), 200));
    await tester.pumpAndSettle();
    expect(await store.read(store.ticket), {'Schlaf': 1});
  });

  testWidgets(
    'legacy claim is explicit, localized, local only and independent',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ChatAccountStore.legacyKey, '{"Schlaf":2}');
      for (final language in ['de', 'en', 'tr', 'ku']) {
        await tester.pumpWidget(const SizedBox.shrink());
        await consent.grant(store.scope);
        await mount(
          tester,
          ChatScreen(chatBackend: backend, memoryService: memory),
          language: language,
        );
        final action = AppStringsManager.getString(
          language,
          'chat_claim_action',
        );
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStringsManager.getString(language, 'chat_legacy_body')),
          findsNWidgets(2),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(await store.read(store.ticket), isEmpty);
        expect(calls, isEmpty);
      }
      await tester.tap(
        find.text(AppStringsManager.getString('ku', 'chat_claim_action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(await store.read(store.ticket), {'Schlaf': 2});
      expect(prefs.getString(ChatAccountStore.legacyKey), '{"Schlaf":2}');
      expect(calls, isEmpty);
      await switchAccount(tester, 'b');
      expect(await store.read(store.ticket), isEmpty);
      expect(await store.hasLegacy(store.ticket), isFalse);
    },
  );

  testWidgets(
    'legacy dialog disappears on account change and cannot claim for B',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ChatAccountStore.legacyKey, '{"Krise":2}');
      await chat(tester);
      await tester.tap(find.text('Confirm ownership'));
      await tester.pumpAndSettle();
      await switchAccount(tester, 'b');
      expect(find.byType(AlertDialog), findsNothing);
      expect(await store.hasLegacy(store.ticket), isTrue);
      expect(await store.read(store.ticket), isEmpty);
    },
  );

  testWidgets('claim and topic writes fail visibly without false success', (
    tester,
  ) async {
    store.dispose();
    store = ChatAccountStore(
      userIdProvider: () => uid,
      persist: (_, __) async => false,
    );
    configure();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ChatAccountStore.legacyKey, '{"Schlaf":2}');
    await chat(tester);
    await tester.tap(find.text('Confirm ownership'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppStringsManager.getString('en', 'chat_claim_failed')),
      findsOneWidget,
    );
    expect(await store.hasLegacy(store.ticket), isTrue);
    await send(tester);
    expect(
      find.text(AppStringsManager.getString('en', 'chat_topics_save_failed')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      _question,
    );
    expect(await store.read(store.ticket), isEmpty);
    expect(calls, isEmpty);
  });

  testWidgets('corrupt topics show a retry boundary and are not overwritten', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ChatAccountStore.storageKey, 'corrupt');
    await chat(tester);
    expect(
      find.text(AppStringsManager.getString('en', 'chat_topics_load_failed')),
      findsOneWidget,
    );
    await send(tester);
    expect(prefs.getString(ChatAccountStore.storageKey), 'corrupt');
    expect(calls, isEmpty);
  });

  testWidgets(
    'open topic sheet closes on logout and does not expose old counts',
    (tester) async {
      await chat(tester);
      await send(tester);
      await tester.tap(find.byIcon(Icons.insights_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);
      await switchAccount(tester, null);
      expect(find.byIcon(Icons.restart_alt_rounded), findsNothing);
      expect(find.text(_question), findsNothing);
    },
  );

  testWidgets(
    'memory child edit closes on logout and clears its private controllers',
    (tester) async {
      await memoryConsent.grant(store.scope);
      memoryResponse = (request) async => http.Response(
        request.url.path == '/ai/settings'
            ? '{"enabled":true,"consentVersion":"chat-memory-v1"}'
            : '{"items":[{"id":"child-a","name":"Private child","memoryItems":[]}]}', 200);
      await mount(tester, AiMemorySettingsScreen(service: memory));
      expect(find.text('Private child'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Private draft name');
      final controllers = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!)
          .toList();
      await switchAccount(tester, null);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Private draft name'), findsNothing);
      // Draft input must be cleared before the dialog route is removed.
      expect(
        controllers.every((controller) => controller.value.text.isEmpty),
        isTrue,
      );
      expect(memoryCalls.where((call) => call.method != 'GET'), isEmpty);
    },
  );

  testWidgets('failed topic reset retains persisted and displayed counts', (
    tester,
  ) async {
    var fail = false;
    store.dispose();
    store = ChatAccountStore(
      userIdProvider: () => uid,
      persist: (key, raw) async => fail
          ? false
          : await (await SharedPreferences.getInstance()).setString(key, raw),
    );
    configure();
    await chat(tester);
    await send(tester);
    fail = true;
    await tester.tap(find.byIcon(Icons.insights_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restart_alt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(await store.read(store.ticket), {'Schlaf': 1});
    expect(
      find.text(AppStringsManager.getString('en', 'chat_topics_save_failed')),
      findsOneWidget,
    );
  });

  testWidgets(
    'late old active memory profile is never included in the new chat',
    (tester) async {
      await memoryConsent.grant(store.scope);
      final oldChildren = Completer<http.Response>();
      memoryResponse = (request) async {
        if (request.url.path == '/ai/settings') {
          return http.Response(
            uid == 'a' ? '{"enabled":true,"consentVersion":"chat-memory-v1"}' : '{"enabled":false}',
            200,
          );
        }
        return oldChildren.future;
      };
      await chat(tester);
      uid = 'b';
      await consent.grant('account.b');
      store.synchronize();
      await tester.pumpAndSettle();
      oldChildren.complete(
        http.Response(
          '{"items":[{"id":"private-a","name":"Private child"}]}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      await send(tester);
      expect(calls, hasLength(1));
      expect(
        jsonDecode(calls.single.body).containsKey('childProfileId'),
        isFalse,
      );
    },
  );

  testWidgets(
    'memory detail closes on account switch and never deletes old items',
    (tester) async {
      memoryResponse = (request) async => http.Response(
        request.url.path.endsWith('/memory')
            ? '{"items":[{"id":"item-a","category":"health","key":"allergy","value":"Private allergy","status":"confirmed"}]}'
            : request.url.path == '/ai/settings'
            ? '{"enabled":false}'
            : '{"items":[{"id":"child-a","name":"Private child","memoryItems":[]}]}',
        200,
      );
      await mount(tester, AiMemorySettingsScreen(service: memory));
      await tester.tap(find.text('Private child'));
      await tester.pumpAndSettle();
      expect(find.text('Private allergy'), findsOneWidget);
      await switchAccount(tester, 'b');
      expect(find.text('Private allergy'), findsNothing);
      expect(memoryCalls.where((call) => call.method == 'DELETE'), isEmpty);
    },
  );

  testWidgets(
    'late old memory settings response cannot restore the old profile',
    (tester) async {
      final pending = Completer<http.Response>();
      var first = true;
      memoryResponse = (request) async {
        if (first) {
          first = false;
          return pending.future;
        }
        return http.Response(
          request.url.path == '/ai/settings'
              ? '{"enabled":false}'
              : '{"items":[]}',
          200,
        );
      };
      await tester.pumpWidget(
        MaterialApp(home: AiMemorySettingsScreen(service: memory)),
      );
      await tester.pump();
      await switchAccount(tester, 'b');
      pending.complete(http.Response('{"enabled":true}', 200));
      await tester.pumpAndSettle();
      expect(find.text('Private child'), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        memoryCalls.where((call) => call.url.path == '/ai/children'),
        hasLength(1),
      );
    },
  );
}
