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
import 'package:parentpeak/logic/chat_prompt_policy.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/ui/ai_memory_settings_screen.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _answers = {
  'de':
      'Das klingt gerade herausfordernd. Du könntest beim Einschlafen abends eine ruhige Wahl anbieten und daneben präsent bleiben. Was passiert bei euch direkt vor dieser Situation?',
  'en':
      'That sounds challenging, and your child may need closeness. You could offer a quiet choice at bedtime and remain calmly beside them. What happens right before this situation?',
  'tr':
      'Bu durum zor görünüyor ve çocuğun yakınlık arıyor olabilir. Uyku öncesinde sakin bir seçim sunabilir ve yanında sessizce durabilirsin. Bu durumdan hemen önce ne oluyor?',
  'ku':
      'Ev rewş dijwar xuya dike û dibe ku zarok nêzîkbûnê dixwaze. Tu dikarî berî xewê hilbijartineke aram bidî û li kêleka wî bimînî. Berî vê rewşê bi rastî çi diqewime?',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatAccountStore store;
  late ChatAiConsent consent;
  late ChatMemoryConsent memoryConsent;
  late List<Map<String, dynamic>> requests;
  late Future<http.Response> Function(http.Request) response;
  late PedagogicalChatBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ChatAccountStore(userIdProvider: () => 'locale');
    consent = ChatAiConsent(scopeProvider: () => store.scope);
    memoryConsent = ChatMemoryConsent(scopeProvider: () => store.scope);
    await consent.grant(store.scope);
    requests = [];
    response = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'text': _answers[body['language']]}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    };
    backend = PedagogicalChatBackend(
      accountStore: store,
      consent: consent,
      geminiService: GeminiAIService(
        memoryConsent: memoryConsent,
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) {
            requests.add(jsonDecode(request.body) as Map<String, dynamic>);
            return response(request);
          }),
        ),
      ),
    );
  });
  tearDown(() => store.dispose());

  Future<String> reply(
    String message,
    String language, {
    String? country,
  }) async =>
      (await backend
              .streamReply(
                history: const [],
                userMessage: message,
                languageCode: language,
                countryCode: country,
              )
              .toList())
          .join();

  Future<void> mount(WidgetTester tester, String language, Widget child) async {
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

  for (final language in ['de', 'en', 'tr', 'ku']) {
    test(
      '$language real payload has localized system/coaching prompt and no German empathy retry',
      () async {
        final answer = await reply(
          'Wie begleiten wir das Einschlafen abends?',
          language,
        );
        expect(answer, _answers[language]);
        expect(requests, hasLength(1));
        expect(
          requests.single['systemInstruction'],
          AppStringsManager.getString(language, 'chat_system_prompt'),
        );
        expect(
          requests.single['prompt'],
          contains(ChatPromptPolicy.followUp(language, true)),
        );
        expect(requests.single['language'], language);
        if (language != 'de') {
          expect(requests.single['prompt'], isNot(contains('Nutzeranliegen')));
        }
      },
    );

    test('$language curated quality fallback is labeled honestly', () async {
      response = (_) async => http.Response(
        jsonEncode({
          'text':
              'Das klingt schwierig. Schrei dein Kind an und bestrafe dein Kind.',
        }),
        200,
      );
      final answer = await reply(
        'Wie begleiten wir das Einschlafen abends?',
        language,
      );
      expect(
        answer,
        startsWith(
          AppStringsManager.getString(language, 'chat_fallback_label'),
        ),
      );
      expect(
        answer,
        contains(AppStringsManager.getString(language, 'chat_fallback_sleep')),
      );
      expect(answer, isNot(contains('Schrei dein Kind an')));
      expect(requests.length, lessThanOrEqualTo(5));
    });

    test(
      '$language local boundaries are localized and 116117 is DE-only',
      () async {
        for (final country in [null, 'GB', 'TR', 'AT', 'DE']) {
          final result = await reply(
            'Welches Medikament hilft?',
            language,
            country: country,
          );
          expect(
            result,
            startsWith(
              AppStringsManager.getString(language, 'chat_boundary_medical'),
            ),
          );
          expect(result.contains('116117'), country == 'DE');
        }
        expect(
          await reply('Hat mein Kind Autismus?', language),
          AppStringsManager.getString(language, 'chat_boundary_diagnosis'),
        );
        final medical = {
          'de': 'Welches Medikament hilft?',
          'en': 'Which medication helps?',
          'tr': 'Hangi ilaç yardımcı olur?',
          'ku': 'Kîjan derman alîkarî dike?',
        };
        final diagnosis = {
          'de': 'Hat mein Kind Autismus?',
          'en': 'Does my child have autism?',
          'tr': 'Bir teşhis istiyorum.',
          'ku': 'Ez teşxîs dixwazim.',
        };
        expect(
          await reply(medical[language]!, language),
          startsWith(
            AppStringsManager.getString(language, 'chat_boundary_medical'),
          ),
        );
        expect(
          await reply(diagnosis[language]!, language),
          AppStringsManager.getString(language, 'chat_boundary_diagnosis'),
        );
        expect(
          await reply('Bitte Flutter Code schreiben', language),
          AppStringsManager.getString(language, 'chat_boundary_topic'),
        );
        expect(requests, isEmpty);
      },
    );

    testWidgets(
      '$language memory UI/dialogs and failures are localized without raw server echo',
      (tester) async {
        final service = AiMemoryService(
          accountStore: store,
          consent: memoryConsent,
          apiClient: BackendApiClient(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient((request) async {
              if (request.url.path == '/ai/settings') {
                return http.Response(
                  '{"enabled":true,"consentVersion":"chat-memory-v1"}',
                  200,
                );
              }
              return http.Response('{"items":[]}', 200);
            }),
          ),
        );
        await memoryConsent.grant(store.scope);
        await mount(tester, language, AiMemorySettingsScreen(service: service));
        expect(
          find.text(AppStringsManager.getString(language, 'memory_title')),
          findsOneWidget,
        );
        expect(
          find.text(
            AppStringsManager.getString(language, 'memory_no_children'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStringsManager.getString(language, 'memory_add_child')),
          findsOneWidget,
        );
        await tester.tap(
          find.text(AppStringsManager.getString(language, 'save')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            AppStringsManager.getString(language, 'memory_name_required'),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.text(AppStringsManager.getString(language, 'cancel')),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        final failed = AiMemoryService(
          accountStore: store,
          consent: memoryConsent,
          apiClient: BackendApiClient(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient(
              (_) async => http.Response('{"error":"RAW_PRIVATE_ECHO"}', 502),
            ),
          ),
        );
        await mount(tester, language, AiMemorySettingsScreen(service: failed));
        expect(
          find.text(
            AppStringsManager.getString(language, 'memory_load_failed'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('RAW_PRIVATE_ECHO'), findsNothing);
      },
    );
  }

  test(
    'specific question and quality retry have one consistent no-follow-up rule',
    () async {
      response = (_) async => http.Response(
        jsonEncode({
          'text': requests.length == 1
              ? 'Short fragment.'
              : _answers['en']!.replaceAll(
                  'What happens right before this situation?',
                  'Stay beside your child calmly.',
                ),
        }),
        200,
      );
      await reply(
        'My child is 3 years old and cries when bedtime starts. How can I support them?',
        'en',
      );
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(
          request['prompt'],
          contains(ChatPromptPolicy.followUp('en', false)),
        );
        expect(
          request['prompt'],
          isNot(contains(ChatPromptPolicy.followUp('en', true))),
        );
      }
    },
  );

  test(
    'prompt interpolation never reinterprets placeholders inside parent text',
    () {
      final prompt = ChatPromptPolicy.coaching(
        language: 'en',
        message: 'Please discuss {history} and {focus}.',
        topic: 'Schlaf',
        needsFollowUp: true,
        context: const [],
        history: const [],
      );
      expect(prompt, contains('Please discuss {history} and {focus}.'));
      expect(prompt, contains(ChatPromptPolicy.focus('Schlaf', 'en')));
    },
  );

  testWidgets('send tap has opaque hit behavior and sends one request', (
    tester,
  ) async {
    final memory = AiMemoryService(
      accountStore: store,
      consent: memoryConsent,
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient(
          (_) async => http.Response('{"enabled":false}', 200),
        ),
      ),
    );
    await mount(
      tester,
      'en',
      ChatScreen(chatBackend: backend, memoryService: memory),
    );
    await tester.enterText(
      find.byType(TextField),
      'Wie begleiten wir das Einschlafen abends?',
    );
    await tester.pump();
    final send = find.ancestor(
      of: find.byIcon(Icons.arrow_upward_rounded),
      matching: find.byType(GestureDetector),
    );
    expect(send, findsOneWidget);
    expect(
      tester.widget<GestureDetector>(send).behavior,
      HitTestBehavior.opaque,
    );
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
  });
}
