import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/ritual_ai_service.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/ui/ritual_ruhe_screen.dart';
import 'package:parentpeak/ui/widgets/account_ai_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late AccountAiConsent consent;
  late List<http.Request> requests;
  const prefix = 'ritual.ai_consent.v1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.a';
    consent = AccountAiConsent(
      storagePrefix: prefix,
      scopeProvider: () => scope,
    );
    requests = [];
  });

  RitualAiService service({
    Future<String?> Function()? token,
    Future<String?> Function()? refresh,
    Future<http.Response> Function(http.Request)? respond,
    AccountAiConsent? approval,
  }) => RitualAiService(
    consent: approval ?? consent,
    aiService: GeminiAIService(
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        authTokenProvider: token ?? () async => 'test-token',
        forceRefreshTokenProvider: refresh,
        requireAuthToken: true,
        httpClient: MockClient((request) async {
          requests.add(request);
          return respond == null
              ? http.Response('{"text":"A calm story"}', 200)
              : await respond(request);
        }),
      ),
    ),
  );

  Future<String> generate(RitualAiService ai) => ai.generate(
    'A ritual for a child aged 5',
    systemInstruction: 'Gentle rituals',
    languageCode: 'de',
    expectedScope: 'account.a',
    requestGuard: () {},
  );

  test(
    'no consent or unrelated feature approval means no Gemini request',
    () async {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'familykueche.ai_recipe_consent.v1.$scope',
        'fridge.ai_photo_consent.v1.$scope',
        'weekly_reflection.ai_consent.v1.$scope',
        'ritual.ai_consent.$scope',
      ]) {
        await prefs.setBool(key, true);
      }
      await expectLater(
        generate(service()),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test('approval is persisted, versioned and account scoped', () async {
    await consent.grant(scope);
    expect(
      await AccountAiConsent(
        storagePrefix: prefix,
        scopeProvider: () => scope,
      ).hasConsent(),
      isTrue,
    );
    scope = 'account.b';
    expect(await consent.hasConsent(), isFalse);
    await expectLater(
      generate(service()),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'approved request uses real proxy with no child memory profile',
    () async {
      await consent.grant(scope);
      expect(await generate(service()), 'A calm story');
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/ai/generate');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['prompt'], 'A ritual for a child aged 5');
      expect(body['language'], 'de');
      expect(body.containsKey('childProfileId'), isFalse);
    },
  );

  for (final change in [
    'account',
    'revoke',
    'persisted revoke',
    'token failure',
  ]) {
    test('$change during token lookup prevents HTTP', () async {
      await consent.grant(scope);
      final ai = service(
        token: () async {
          if (change == 'account') scope = 'account.b';
          if (change == 'revoke') await consent.revoke(scope);
          if (change == 'persisted revoke') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('$prefix.$scope', false);
          }
          return change == 'token failure' ? null : 'test-token';
        },
      );
      await expectLater(
        generate(ai),
        change == 'token failure'
            ? throwsStateError
            : throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    });
  }

  test(
    'revocation during 401 refresh prevents a second HTTP request',
    () async {
      await consent.grant(scope);
      final ai = service(
        respond: (_) async => http.Response('{}', 401),
        refresh: () async {
          await consent.revoke(scope);
          return 'refreshed-token';
        },
      );
      await expectLater(
        generate(ai),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test('revocation discards an in-flight response', () async {
    await consent.grant(scope);
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final pending = generate(
      service(
        respond: (_) {
          sent.complete();
          return response.future;
        },
      ),
    );
    final check = expectLater(
      pending,
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    await sent.future;
    await consent.revoke(scope);
    response.complete(http.Response('{"text":"Must not appear"}', 200));
    await check;
  });

  Future<void> openScreen(WidgetTester tester, RitualAiService ai) async {
    await tester.runAsync(
      () => KindDossierService.instance.save([
        KindDossier(childName: 'Sensitive child', ageMonths: 60),
      ]),
    );
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: RitualRuheScreen(aiService: ai),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectSection(WidgetTester tester, String section) async {
    final picker = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    picker.onSelectionChanged!({section});
    await tester.pumpAndSettle();
  }

  for (final section in ['morning', 'night']) {
    for (final dismiss in [false, true]) {
      testWidgets(
        '$section ${dismiss ? 'dismissal' : 'refusal'} sends nothing',
        (tester) async {
          await openScreen(tester, service());
          await selectSection(tester, section);
          final button = find.widgetWithIcon(
            FilledButton,
            Icons.auto_awesome_rounded,
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(requests, isEmpty);
          if (dismiss) {
            Navigator.of(tester.element(find.byType(AlertDialog))).pop();
          } else {
            await tester.tap(find.text('Abbrechen'));
          }
          await tester.pumpAndSettle();
          expect(requests, isEmpty);
          expect(await consent.hasConsent(), isFalse);
          expect(
            find.text(
              AppStringsManager.getString('de', 'ritual_ai_consent_declined'),
            ),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('$section approval enables the guarded screen request', (
      tester,
    ) async {
      await openScreen(
        tester,
        service(
          respond: (_) async => http.Response(
            jsonEncode({
              'text': section == 'night'
                  ? 'A calm story'
                  : jsonEncode({
                      'name': 'Gentle morning',
                      'time': '07:30',
                      'weekdays': [1, 2, 3, 4, 5],
                      'steps': [
                        {
                          'title': 'Wake up',
                          'subtitle': 'Gently',
                          'icon': 'sun',
                          'timerSeconds': 0,
                        },
                      ],
                    }),
            }),
            200,
          ),
        ),
      );
      await selectSection(tester, section);
      final button = find.widgetWithIcon(
        FilledButton,
        Icons.auto_awesome_rounded,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          AppStringsManager.getString('de', 'ritual_ai_consent_accept'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(requests, hasLength(1));
      expect(requests.single.body, isNot(contains('Sensitive child')));
      expect(requests.single.body, isNot(contains('birthDate')));
      if (section == 'night') {
        expect(find.text('A calm story'), findsOneWidget);
      } else {
        expect(
          find.widgetWithText(TextField, 'Gentle morning'),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(TextField).first)).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$section failed consent persistence sends nothing', (
      tester,
    ) async {
      final failingConsent = AccountAiConsent(
        storagePrefix: prefix,
        scopeProvider: () => scope,
        persist: (_, __) async => false,
      );
      await openScreen(tester, service(approval: failingConsent));
      await selectSection(tester, section);
      final button = find.widgetWithIcon(
        FilledButton,
        Icons.auto_awesome_rounded,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          AppStringsManager.getString('de', 'ritual_ai_consent_accept'),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(await failingConsent.hasConsent(), isFalse);
      expect(
        find.text(
          AppStringsManager.getString('de', 'ritual_ai_consent_failed'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final invalidation in ['section change', 'unmount']) {
      testWidgets('$section $invalidation discards a late response', (
        tester,
      ) async {
        await tester.runAsync(() => consent.grant(scope));
        final response = Completer<http.Response>();
        await openScreen(tester, service(respond: (_) => response.future));
        await selectSection(tester, section);
        final button = find.widgetWithIcon(
          FilledButton,
          Icons.auto_awesome_rounded,
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(requests, hasLength(1));
        if (invalidation == 'section change') {
          final picker = tester.widget<SegmentedButton<String>>(
            find.byType(SegmentedButton<String>),
          );
          picker.onSelectionChanged!({
            section == 'night' ? 'morning' : 'night',
          });
          await tester.pump();
        } else {
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        }
        response.complete(http.Response('{"text":"Must not appear"}', 200));
        await tester.pumpAndSettle();
        expect(find.text('Must not appear'), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final language in AppLanguages.launchReady) {
    testWidgets('${language.code} consent dialog fits enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language.code),
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ensureAccountAiConsent(
                  context,
                  consent: consent,
                  titleKey: 'ritual_ai_consent_title',
                  bodyKey: 'ritual_ai_consent_body',
                  acceptKey: 'ritual_ai_consent_accept',
                  failedKey: 'ritual_ai_consent_failed',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final catalog = AppStringsManager.allStrings[language.code]!;
      for (final key in [
        'ritual_ai_consent_title',
        'ritual_ai_consent_body',
        'ritual_ai_consent_accept',
        'ritual_ai_consent_failed',
        'ritual_ai_consent_declined',
      ]) {
        expect(catalog[key]?.trim(), isNotEmpty);
        if (language.code != 'en') {
          expect(catalog[key], isNot(AppStringsManager.allStrings['en']![key]));
        }
      }
      expect(find.text(catalog['ritual_ai_consent_title']!), findsOneWidget);
      final accept = find.text(catalog['ritual_ai_consent_accept']!);
      await tester.ensureVisible(accept);
      expect(accept.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop(false);
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
    });
  }
}
