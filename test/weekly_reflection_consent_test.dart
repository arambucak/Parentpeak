import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/weekly_reflection_ai_service.dart';
import 'package:parentpeak/services/weekly_reflection_service.dart';
import 'package:parentpeak/ui/wochenrueckblick_screen.dart';
import 'package:parentpeak/ui/widgets/account_ai_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late AccountAiConsent consent;
  late WeeklyReflectionService reflections;
  const prefix = 'weekly_reflection.ai_consent.v1';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.a';
    consent = AccountAiConsent(
      storagePrefix: prefix,
      scopeProvider: () => scope,
    );
    reflections = WeeklyReflectionService(scopeProvider: () => scope);
  });

  WeeklyReflection entry({String text = 'A good week'}) => WeeklyReflection(
        weekId: WeeklyReflectionService.currentWeekId(),
        createdAt: DateTime(2026, 10, 23),
        overallMood: 'Gut',
        whatWentWell: text,
        whatWasChallenging: 'A challenge',
        whatILearned: '',
        lookingForwardTo: '',
      );

  WeeklyReflectionAiService ai(
    Future<http.Response> Function(http.Request) handle, {
    Future<String?> Function()? token,
    Future<String?> Function()? refresh,
    bool requireToken = false,
  }) =>
      WeeklyReflectionAiService(
        consent: consent,
        aiService: GeminiAIService(
          apiClient: BackendApiClient(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient(handle),
            authTokenProvider: token,
            forceRefreshTokenProvider: refresh,
            requireAuthToken: requireToken,
          ),
        ),
      );

  Future<String> generate(WeeklyReflectionAiService service) =>
      service.generate(
        'A weekly reflection',
        expectedScope: 'account.a',
        languageCode: 'de',
        requestGuard: () {},
      );
  http.Response answer() => http.Response('{"text":"Warm feedback"}', 200);

  test('missing consent and unrelated approvals never authorize HTTP',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat.ai_consent.v1.$scope', true);
    await prefs.setBool('weekly_reflection.ai_consent.$scope', true);
    var calls = 0;
    await expectLater(
      generate(ai((_) async {
        calls++;
        return answer();
      })),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    expect(calls, 0);
  });

  test('consent is versioned and account scoped', () async {
    await consent.grant(scope);
    expect(await consent.hasConsent(), isTrue);
    scope = 'account.b';
    expect(await consent.hasConsent(), isFalse);
    scope = 'account.a';
    expect(await consent.hasConsent(), isTrue);
  });

  test('valid approval sends guarded request and no memory profile', () async {
    await consent.grant(scope);
    http.Request? sent;
    expect(
        await generate(ai((request) async {
          sent = request;
          return answer();
        })),
        'Warm feedback');
    final body = jsonDecode(sent!.body) as Map<String, dynamic>;
    expect(sent!.url.path, '/ai/generate');
    expect(body['language'], 'de');
    expect(body['prompt'], contains('weekly reflection'));
    expect(body.containsKey('childProfileId'), isFalse);
  });

  test('token failure never falls back to an unauthenticated HTTP request',
      () async {
    await consent.grant(scope);
    var calls = 0;
    await expectLater(
        generate(ai((_) async {
          calls++;
          return answer();
        }, token: () async => null, requireToken: true)),
        throwsStateError);
    expect(calls, 0);
  });

  test('account change during token lookup prevents HTTP', () async {
    await consent.grant(scope);
    var calls = 0;
    final service = ai((_) async {
      calls++;
      return answer();
    }, token: () async {
      scope = 'account.b';
      return 'token';
    });
    await expectLater(
        generate(service), throwsA(isA<AccountAiConsentRequiredException>()));
    expect(calls, 0);
  });

  test('revocation during token lookup prevents HTTP', () async {
    await consent.grant(scope);
    var calls = 0;
    final service = ai((_) async {
      calls++;
      return answer();
    }, token: () async {
      await consent.revoke(scope);
      return 'token';
    });
    await expectLater(
        generate(service), throwsA(isA<AccountAiConsentRequiredException>()));
    expect(calls, 0);
  });

  test('revocation then regrant does not resurrect in-flight request',
      () async {
    await consent.grant(scope);
    final service = ai((_) async {
      await consent.revoke(scope);
      await consent.grant(scope);
      return answer();
    });
    await expectLater(
        generate(service), throwsA(isA<AccountAiConsentRequiredException>()));
    expect(await consent.hasConsent(), isTrue);
  });

  for (final change in ['account', 'revoke', 'raw removal']) {
    test('$change during 401 refresh prevents retry', () async {
      await consent.grant(scope);
      var calls = 0;
      final service = ai(
          (_) async {
            calls++;
            return http.Response('{}', 401);
          },
          token: () async => 'old',
          refresh: () async {
            if (change == 'account') {
              scope = 'account.b';
            } else if (change == 'revoke') {
              await consent.revoke(scope);
            } else {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('$prefix.$scope');
            }
            return 'new';
          });
      await expectLater(
          generate(service), throwsA(isA<AccountAiConsentRequiredException>()));
      expect(calls, 1);
    });
  }

  test('normal token refresh retains guard and succeeds', () async {
    await consent.grant(scope);
    var calls = 0;
    final service = ai(
        (_) async => ++calls == 1 ? http.Response('{}', 401) : answer(),
        token: () async => 'old',
        refresh: () async => 'new');
    expect(await generate(service), 'Warm feedback');
    expect(calls, 2);
  });

  test('raw consent removal after response rejects result', () async {
    await consent.grant(scope);
    await expectLater(generate(ai((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$prefix.$scope');
      return answer();
    })), throwsA(isA<AccountAiConsentRequiredException>()));
  });

  test('failed revocation stays blocked in memory and reports error', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$prefix.$scope', true);
    consent = AccountAiConsent(
      storagePrefix: prefix,
      scopeProvider: () => scope,
      persist: (_, value) async => value,
    );
    await expectLater(consent.revoke(scope), throwsStateError);
    expect(await consent.hasConsent(), isFalse);
    await expectLater(generate(ai((_) async => answer())),
        throwsA(isA<AccountAiConsentRequiredException>()));
  });

  test('revocation wins over an unfinished consent grant', () async {
    final pending = Completer<bool>();
    final started = Completer<void>();
    final prefs = await SharedPreferences.getInstance();
    consent = AccountAiConsent(
      storagePrefix: prefix,
      scopeProvider: () => scope,
      persist: (key, value) async {
        if (value) {
          started.complete();
          await pending.future;
        }
        return prefs.setBool(key, value);
      },
    );
    final grant = consent.grant(scope);
    final rejected = expectLater(
      grant,
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    await started.future;
    final revoke = consent.revoke(scope);
    pending.complete(true);
    await rejected;
    await revoke;
    expect(await consent.hasConsent(), isFalse);
    final reloaded = AccountAiConsent(
      storagePrefix: prefix,
      scopeProvider: () => scope,
    );
    expect(await reloaded.hasConsent(), isFalse);
  });

  test('local reflections and deletes are isolated per account', () async {
    await reflections.save(entry(text: 'Account A'));
    scope = 'account.b';
    expect(await reflections.loadAll(), isEmpty);
    await reflections.save(entry(text: 'Account B'));
    await reflections.delete(entry().weekId);
    expect(await reflections.loadAll(), isEmpty);
    scope = 'account.a';
    expect((await reflections.loadAll()).single.whatWentWell, 'Account A');
    await expectLater(
      reflections.save(entry(), expectedScope: 'account.b'),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
  });

  test('legacy data remains untouched until explicit claim', () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([entry(text: 'Legacy').toJson()]);
    await prefs.setString('weekly_reflections.v1', raw);
    expect(await reflections.loadAll(), isEmpty);
    expect(await reflections.hasLegacy(), isTrue);
    await reflections.claimLegacy(expectedScope: scope, requestGuard: () {});
    expect((await reflections.loadAll()).single.whatWentWell, 'Legacy');
    expect(await reflections.hasLegacy(), isFalse);
    expect(prefs.getString('weekly_reflections.v1'), raw);
    scope = 'account.b';
    expect(await reflections.loadAll(), isEmpty);
    expect(await reflections.hasLegacy(), isFalse);
    await expectLater(
      reflections.claimLegacy(expectedScope: scope, requestGuard: () {}),
      throwsStateError,
    );
  });

  test('legacy import never overwrites newer entries for the same week',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'weekly_reflections.v1', jsonEncode([entry(text: 'Legacy').toJson()]));
    await reflections.save(entry(text: 'New'));
    await reflections.claimLegacy(expectedScope: scope, requestGuard: () {});
    expect((await reflections.loadAll()).single.whatWentWell, 'New');
  });

  test('failed import is retryable only by the reserved owner', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'weekly_reflections.v1', jsonEncode([entry().toJson()]));
    reflections = WeeklyReflectionService(
      scopeProvider: () => scope,
      persist: (key, raw) async {
        if (key.startsWith('${WeeklyReflectionService.storagePrefix}.')) {
          return false;
        }
        return prefs.setString(key, raw);
      },
    );
    await expectLater(
      reflections.claimLegacy(expectedScope: scope, requestGuard: () {}),
      throwsStateError,
    );
    expect(await reflections.hasLegacy(), isTrue);
    scope = 'account.b';
    expect(await reflections.hasLegacy(), isFalse);
    scope = 'account.a';
    reflections = WeeklyReflectionService(scopeProvider: () => scope);
    await reflections.claimLegacy(expectedScope: scope, requestGuard: () {});
    expect(await reflections.loadAll(), hasLength(1));
  });

  test('corrupt legacy data is preserved without assigning an owner', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weekly_reflections.v1', '{');
    await expectLater(
      reflections.claimLegacy(expectedScope: scope, requestGuard: () {}),
      throwsFormatException,
    );
    expect(prefs.getString('weekly_reflections.v1'), '{');
    expect(prefs.getString(WeeklyReflectionService.legacyOwnerKey), isNull);
    expect(await reflections.loadAll(), isEmpty);
  });

  test('corrupt local data and failed persistence are not success-shaped',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '${WeeklyReflectionService.storagePrefix}.$scope', '{');
    await expectLater(reflections.loadAll(), throwsFormatException);
    await prefs.remove('${WeeklyReflectionService.storagePrefix}.$scope');
    reflections = WeeklyReflectionService(
      scopeProvider: () => scope,
      persist: (_, raw) async => false,
    );
    await expectLater(reflections.save(entry()), throwsStateError);
    expect(await reflections.loadAll(), isEmpty);
  });

  test('concurrent saves keep both weeks and the 52-week limit', () async {
    WeeklyReflection week(int number) => WeeklyReflection(
          weekId: '2025-W$number',
          createdAt: DateTime(2025, 1, number),
          overallMood: 'Gut',
          whatWentWell: '',
          whatWasChallenging: '',
          whatILearned: '',
          lookingForwardTo: '',
        );
    await Future.wait([for (var i = 0; i < 55; i++) reflections.save(week(i))]);
    final all = await reflections.loadAll();
    expect(all, hasLength(52));
    expect(all.first.weekId, '2025-W3');
    expect(all.last.weekId, '2025-W54');
  });

  Future<void> showSummary(
      WidgetTester tester, WeeklyReflectionAiService service) async {
    await reflections.save(entry());
    await tester.pumpWidget(MaterialApp(
      home:
          WochenrueckblickScreen(reflections: reflections, aiService: service),
    ));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('weekly-generate-feedback')));
    await tester.pumpAndSettle();
  }

  Future<void> requestFeedback(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('weekly-generate-feedback')));
    await tester.pumpAndSettle();
  }

  for (final dismiss in ['cancel', 'barrier']) {
    testWidgets('$dismiss consent never calls HTTP; local reflection remains',
        (tester) async {
      var calls = 0;
      await showSummary(tester, ai((_) async {
        calls++;
        return answer();
      }));
      expect(calls, 0);
      await requestFeedback(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      if (dismiss == 'cancel') {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      } else {
        await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(await consent.hasConsent(), isFalse);
      expect((await reflections.loadAll()).single.aiFeedback, isNull);
    });
  }

  testWidgets('finishing wizard saves locally without any AI request or dialog',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: WochenrueckblickScreen(
        reflections: reflections,
        aiService: ai((_) async {
          calls++;
          return answer();
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gut'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weekly-next')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Local only');
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('weekly-next')));
      await tester.pumpAndSettle();
    }
    expect(calls, 0);
    expect(find.byType(AlertDialog), findsNothing);
    final saved = (await reflections.loadAll()).single;
    expect(saved.whatWentWell, 'Local only');
    expect(saved.aiFeedback, isNull);
  });

  testWidgets('legacy import requires confirmation and never generates AI',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([entry(text: 'Legacy personal entry').toJson()]);
    await prefs.setString('weekly_reflections.v1', raw);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: WochenrueckblickScreen(
      reflections: reflections,
      aiService: ai((_) async {
        calls++;
        return answer();
      }),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Legacy personal entry'), findsNothing);
    await tester.tap(find.text('Alte Rückblicke übernehmen'));
    await tester.pumpAndSettle();
    expect(await reflections.loadAll(), isEmpty);
    await tester
        .tap(find.widgetWithText(FilledButton, 'Alte Rückblicke übernehmen'));
    await tester.pumpAndSettle();
    expect((await reflections.loadAll()).single.whatWentWell,
        'Legacy personal entry');
    expect(calls, 0);
    expect(prefs.getString('weekly_reflections.v1'), raw);
  });
  testWidgets('approval displays and persists actual feedback', (tester) async {
    var calls = 0;
    await showSummary(tester, ai((_) async {
      calls++;
      return answer();
    }));
    await requestFeedback(tester);
    await tester.tap(find.text('Agree and create feedback'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Warm feedback'), findsOneWidget);
    expect((await reflections.loadAll()).single.aiFeedback, 'Warm feedback');
  });

  testWidgets('failed consent persistence does not send a request',
      (tester) async {
    consent = AccountAiConsent(
      storagePrefix: prefix,
      scopeProvider: () => scope,
      persist: (_, value) async => false,
    );
    var calls = 0;
    await showSummary(tester, ai((_) async {
      calls++;
      return answer();
    }));
    await requestFeedback(tester);
    await tester.tap(find.text('Agree and create feedback'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('missing token shows honest failure without HTTP or feedback',
      (tester) async {
    await consent.grant(scope);
    var calls = 0;
    await showSummary(
        tester,
        ai((_) async {
          calls++;
          return answer();
        }, token: () async => null, requireToken: true));
    await requestFeedback(tester);
    expect(calls, 0);
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
    expect(find.textContaining('lokaler Rückblick'), findsOneWidget);
    expect(find.textContaining('Firebase session'), findsNothing);
  });

  testWidgets('empty provider response is not persisted as successful feedback',
      (tester) async {
    await consent.grant(scope);
    await showSummary(
        tester, ai((_) async => http.Response('{"text":""}', 200)));
    await requestFeedback(tester);
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
    expect(find.textContaining('lokaler Rückblick'), findsOneWidget);
  });

  testWidgets('provider failure offers retry, never displays raw error',
      (tester) async {
    await consent.grant(scope);
    var calls = 0;
    await showSummary(tester, ai((_) async {
      calls++;
      return calls == 1
          ? http.Response('{"error":"PRIVATE provider detail"}', 503)
          : answer();
    }));
    await requestFeedback(tester);
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.textContaining('lokaler Rückblick'), findsOneWidget);
    await requestFeedback(tester);
    expect(calls, 2);
    expect((await reflections.loadAll()).single.aiFeedback, 'Warm feedback');
  });

  testWidgets('withdraw while pending discards late response', (tester) async {
    await consent.grant(scope);
    final pending = Completer<http.Response>();
    await showSummary(tester, ai((_) => pending.future));
    await tester.tap(find.byKey(const ValueKey('weekly-generate-feedback')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .ensureVisible(find.byKey(const ValueKey('weekly-revoke-consent')));
    await tester.tap(find.byKey(const ValueKey('weekly-revoke-consent')));
    await tester.pumpAndSettle();
    pending.complete(answer());
    await tester.pumpAndSettle();
    expect(await consent.hasConsent(), isFalse);
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
    expect(find.text('Warm feedback'), findsNothing);
  });

  testWidgets('account switch back cannot resurrect old request or form',
      (tester) async {
    await consent.grant(scope);
    final pending = Completer<http.Response>();
    await showSummary(tester, ai((_) => pending.future));
    await tester.tap(find.byKey(const ValueKey('weekly-generate-feedback')));
    await tester.pump();
    scope = 'account.b';
    AuthService.instance.notifyListeners();
    await tester.pump();
    scope = 'account.a';
    AuthService.instance.notifyListeners();
    pending.complete(answer());
    await tester.pumpAndSettle();
    expect(find.text('Warm feedback'), findsNothing);
    expect(find.text('A good week'), findsNothing);
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
  });

  testWidgets('unmounting while pending never saves late feedback',
      (tester) async {
    await consent.grant(scope);
    final pending = Completer<http.Response>();
    await showSummary(tester, ai((_) => pending.future));
    await tester.tap(find.byKey(const ValueKey('weekly-generate-feedback')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(answer());
    await tester.pumpAndSettle();
    expect((await reflections.loadAll()).single.aiFeedback, isNull);
    expect(tester.takeException(), isNull);
  });

  test('all consent and legacy messages exist in eight launch languages', () {
    const keys = [
      'weekly_ai_consent_title',
      'weekly_ai_consent_body',
      'weekly_ai_consent_accept',
      'weekly_ai_generate',
      'weekly_ai_revoke',
      'weekly_ai_failed',
      'weekly_local_saved',
      'weekly_legacy_unassigned',
      'weekly_legacy_import',
      'weekly_legacy_confirm',
    ];
    for (final code in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
      for (final key in keys) {
        final copy = AppStringsManager.allStrings[code]![key];
        expect(copy, isNotNull, reason: '$code:$key');
        expect(copy!.trim(), isNotEmpty, reason: '$code:$key');
        if (code != 'en') {
          expect(copy, isNot(AppStringsManager.allStrings['en']![key]));
        }
      }
      expect(AppStringsManager.allStrings[code]!['weekly_ai_consent_body'],
          contains('Google Gemini'));
    }
  });

  for (final code in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
    testWidgets('$code consent dialog fits mobile with enlarged text',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? accepted;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(              textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
            body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              accepted = await ensureAccountAiConsent(
                context,
                consent: consent,
                titleKey: 'weekly_ai_consent_title',
                bodyKey: 'weekly_ai_consent_body',
                acceptKey: 'weekly_ai_consent_accept',
                failedKey: 'request_failed_retry',
              );
            },
            child: const Text('Open consent'),
          ),
        )),
      ));
      await tester.tap(find.text('Open consent'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(AlertDialog))),
          code == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(accepted, isFalse);
      expect(await consent.hasConsent(), isFalse);
    });
  }
}
