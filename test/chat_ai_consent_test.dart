import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/logic/treasure_photo_consent.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _question = 'Wie begleiten wir das Einschlafen abends?';
const _reply =
    'Das klingt gerade herausfordernd. Du könntest heute eine ruhige Wahl '
    'anbieten und abends beim Einschlafen präsent bleiben. Wenn dein Kind '
    '3 Jahre alt ist, können kleine Routinen helfen. '
    'Was passiert vor dem Einschlafen?';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late ChatAiConsent consent;
  late PedagogicalChatBackend backend;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  void configureBackend() {
    backend = PedagogicalChatBackend(
      consent: consent,
      geminiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'audit-token',
          httpClient: MockClient((request) async {
            requests.add(request);
            return respond(request);
          }),
        ),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.chat-a';
    consent = ChatAiConsent(scopeProvider: () => scope);
    requests = [];
    respond = (_) async => http.Response(jsonEncode({'text': _reply}), 200);
    configureBackend();
  });

  Future<List<String>> reply({String? expectedScope}) => backend
      .streamReply(
        history: const [
          {'role': 'user', 'content': 'Mein Kind schläft abends schwer ein.'},
        ],
        userMessage: _question,
        expectedScope: expectedScope,
      )
      .toList();

  test(
    'old global terms and other feature consent cannot authorize chat',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat.terms_accepted', true);
      await TreasurePhotoConsent(scopeProvider: () => scope).grant(scope);
      expect(await consent.hasConsent(), isFalse);
      await expectLater(
        reply(),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
      expect(prefs.getBool('chat.terms_accepted'), isTrue);
    },
  );

  test(
    'versioned consent survives reload only for its account, not guests',
    () async {
      await consent.grant(scope);
      expect(
        await ChatAiConsent(scopeProvider: () => scope).hasConsent(),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('chat.ai_consent.v1.account.chat-a'), isTrue);
      scope = 'account.chat-b';
      expect(await consent.hasConsent(), isFalse);
      await expectLater(
        reply(),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      await consent.grant(scope);
      await expectLater(
        reply(expectedScope: 'account.chat-a'),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      scope = 'guest';
      expect(await consent.hasConsent(), isFalse);
      expect(requests, isEmpty);
    },
  );

  test(
    'negative and thrown storage acknowledgements never enable chat',
    () async {
      for (final throwWrite in [false, true]) {
        consent = ChatAiConsent(
          scopeProvider: () => scope,
          persist: (_, __) async {
            if (throwWrite) throw StateError('Storage unavailable');
            return false;
          },
        );
        configureBackend();
        await expectLater(consent.grant(scope), throwsStateError);
        expect(await consent.hasConsent(), isFalse);
        await expectLater(
          reply(),
          throwsA(isA<AccountAiConsentRequiredException>()),
        );
      }
      expect(requests, isEmpty);
    },
  );

  test('consenting sends the real prepared history to the proxy', () async {
    await consent.grant(scope);
    expect((await reply()).join(), _reply);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/ai/generate');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['prompt'], contains('Mein Kind schläft abends schwer ein.'));
    expect(body['prompt'], contains(_question));
  });

  test(
    'account change during HTTP discards the reply and prevents retries',
    () async {
      await consent.grant(scope);
      respond = (_) async {
        scope = 'account.chat-b';
        await consent.grant(scope);
        return http.Response(jsonEncode({'text': 'Kurze Antwort.'}), 200);
      };
      await expectLater(
        reply(),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'revocation during HTTP prevents quality retries and response delivery',
    () async {
      await consent.grant(scope);
      respond = (_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('chat.ai_consent.v1.$scope');
        return http.Response(jsonEncode({'text': 'Kurze Antwort.'}), 200);
      };
      await expectLater(
        reply(),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test('quality retries remain inside the same consent boundary', () async {
    await consent.grant(scope);
    respond = (_) async => http.Response(
      jsonEncode({'text': requests.length == 1 ? 'Kurze Antwort.' : _reply}),
      200,
    );
    expect((await reply()).join(), _reply);
    expect(requests, hasLength(2));
  });

  test(
    'local crisis help remains available without transmitting data',
    () async {
      final result = await backend
          .streamReply(
            history: const [],
            userMessage: 'I want to die',
            languageCode: 'en',
            countryCode: 'GB',
          )
          .toList();
      expect(result.join(), isNotEmpty);
      expect(requests, isEmpty);
      expect(await consent.hasConsent(), isFalse);
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    String? initial,
    bool settle = true,
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
        home: ChatScreen(chatBackend: backend, initialMessage: initial),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> accept(WidgetTester tester, {String language = 'en'}) async {
    final button = find.widgetWithText(
      FilledButton,
      AppStringsManager.getString(language, 'chat_terms_accept'),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('loading and legacy consent cannot start an initial message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'chat.terms_accepted': true});
    await mount(tester, initial: _question, settle: false);
    expect(find.byType(TextField), findsNothing);
    expect(requests, isEmpty);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Processing by Google Gemini'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('four-language consent is honest and may be declined', (
    tester,
  ) async {
    for (final language in ['de', 'en', 'tr', 'ku']) {
      await tester.pumpWidget(const SizedBox.shrink());
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
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    chatBackend: backend,
                    initialMessage: _question,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final body = AppStringsManager.getString(
        language,
        'chat_terms_privacy_text',
      );
      expect(body, contains('Google Gemini'));
      expect(find.text(body), findsOneWidget);
      final back = find.widgetWithText(
        TextButton,
        AppStringsManager.getString(language, 'back_btn'),
      );
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(requests, isEmpty);
      expect(await consent.hasConsent(), isFalse);
    }
  });

  for (final tip in [false, true]) {
    testWidgets(
      'initial ${tip ? 'tip' : 'message'} waits for confirmed consent and starts once',
      (tester) async {
        await mount(
          tester,
          initial: tip ? '___TIP_EXPAND___$_question' : _question,
        );
        expect(requests, isEmpty);
        await accept(tester);
        expect(await consent.hasConsent(), isTrue);
        expect(requests, hasLength(1));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(find.byType(TextField), findsOneWidget);
      },
    );
  }

  testWidgets('confirmed consent is reused after screen restart', (
    tester,
  ) async {
    await consent.grant(scope);
    await mount(tester, initial: _question);
    expect(requests, hasLength(1));
    expect(find.text('Processing by Google Gemini'), findsNothing);
  });

  testWidgets('manual sending uses the same confirmed service boundary', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byType(TextField), findsNothing);
    await accept(tester);
    await tester.enterText(find.byType(TextField), _question);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.text(_question), findsOneWidget);
  });

  testWidgets(
    'account notification closes consent and rejects a pending old reply',
    (tester) async {
      await consent.grant(scope);
      final pending = Completer<http.Response>();
      respond = (_) => pending.future;
      await mount(tester, initial: _question, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(requests, hasLength(1));
      scope = 'account.chat-b';
      await AuthService.instance.logout();
      await tester.pumpAndSettle();
      expect(find.text('Processing by Google Gemini'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      pending.complete(http.Response(jsonEncode({'text': _reply}), 200));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text(_reply), findsNothing);
      expect(await consent.hasConsent(), isFalse);
      expect(requests, hasLength(1));
    },
  );

  testWidgets(
    'failed consent write is visible and keeps all send paths closed',
    (tester) async {
      consent = ChatAiConsent(
        scopeProvider: () => scope,
        persist: (_, __) async => false,
      );
      configureBackend();
      await mount(tester, initial: '___TIP_EXPAND___$_question');
      await accept(tester);
      expect(
        find.text(
          AppStringsManager.getString('en', 'chat_consent_save_failed'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(requests, isEmpty);
      expect(await consent.hasConsent(), isFalse);
    },
  );

  testWidgets('dispose during consent persistence cannot start initial chat', (
    tester,
  ) async {
    final ack = Completer<bool>();
    consent = ChatAiConsent(
      scopeProvider: () => scope,
      persist: (_, __) => ack.future,
    );
    configureBackend();
    await mount(tester, initial: _question);
    await accept(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    ack.complete(true);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
