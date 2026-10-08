import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/development_report_consent.dart';
import 'package:parentpeak/logic/development_report_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/services/development_report_limit_service.dart';
import 'package:parentpeak/ui/widgets/account_ai_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late DevelopmentReportConsent consent;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.a';
    consent = DevelopmentReportConsent(scopeProvider: () => scope);
  });

  DevelopmentReportService service(
    Future<http.Response> Function(http.Request) handle, {
    Future<String?> Function()? token,
    Future<String?> Function()? refresh,
  }) => DevelopmentReportService(
    consent: consent,
    aiService: GeminiAIService(
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient(handle),
        authTokenProvider: token,
        forceRefreshTokenProvider: refresh,
      ),
    ),
  );

  http.Response answer() => http.Response(
    jsonEncode({'text': 'Bericht fuer [KIND]', 'groundingUrls': []}),
    200,
  );

  test('legacy global consent does not authorize an HTTP request', () async {
    SharedPreferences.setMockInitialValues({'dev.ai_report_consent': true});
    var calls = 0;
    final reports = service((_) async {
      calls++;
      return answer();
    });
    await expectLater(
      reports.generate('Kind: [KIND]', expectedScope: scope),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(calls, 0);
  });

  test('consent is versioned and separate for guest and accounts', () async {
    await consent.grant(scope);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dev.ai_report_consent.v1.account.a'), isTrue);
    scope = 'account.b';
    expect(await consent.hasConsent(), isFalse);
    scope = 'guest';
    expect(await consent.hasConsent(), isFalse);
    await consent.grant(scope);
    scope = 'account.a';
    expect(await consent.hasConsent(), isTrue);
  });

  test('failed write ack never authorizes consent', () async {
    consent = DevelopmentReportConsent(
      scopeProvider: () => scope,
      persist: (key, value) async => false,
    );
    await expectLater(consent.grant(scope), throwsStateError);
    expect(await consent.hasConsent(), isFalse);
  });

  test('thrown consent write error remains a failure', () async {
    consent = DevelopmentReportConsent(
      scopeProvider: () => scope,
      persist: (key, value) async => throw StateError('Storage unavailable'),
    );
    await expectLater(consent.grant(scope), throwsStateError);
    expect(await consent.hasConsent(), isFalse);
  });

  test('invalidated request cannot write report-limit metadata', () async {
    var checks = 0;
    await expectLater(
      DevelopmentReportLimitService.instance.recordReportCreated(
        requestGuard: () {
          if (++checks >= 2) throw StateError('Account changed');
        },
      ),
      throwsStateError,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.startsWith('dev_report_limit.')), isEmpty);
  });

  test('account change while saving consent is rejected', () async {
    consent = DevelopmentReportConsent(
      scopeProvider: () => scope,
      persist: (key, value) async {
        scope = 'account.b';
        return true;
      },
    );
    await expectLater(
      consent.grant('account.a'),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(await consent.hasConsent(), isFalse);
  });

  test('real HTTP payload and account-scoped result persistence', () async {
    await consent.grant(scope);
    http.Request? sent;
    final reports = service((request) async {
      sent = request;
      return answer();
    });
    final text = await reports.generate(
      'Kind: [KIND], Alter: 4 Jahre',
      expectedScope: scope,
    );
    expect(sent!.url.path, '/ai/generate');
    final payload = jsonDecode(sent!.body) as Map<String, dynamic>;
    expect(payload['prompt'], contains('[KIND]'));
    expect(payload.containsKey('childProfileId'), isFalse);
    await reports.saveReport(text, expectedScope: scope, requestGuard: () {});
    expect(await reports.loadReport(scope), text);
    expect(await reports.loadHistory(scope), hasLength(1));
    scope = 'account.b';
    expect(await reports.loadReport(scope), isNull);
    expect(await reports.loadHistory(scope), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('dev.ai_report.v3'), isFalse);
    expect(prefs.containsKey('dev.report_history'), isFalse);
  });

  test(
    'unassigned legacy report and history are preserved but not adopted',
    () async {
      SharedPreferences.setMockInitialValues({
        'dev.ai_report.v3': 'Legacy report',
        'dev.report_history': ['legacy|||report'],
      });
      final reports = service((_) async => answer());
      expect(await reports.loadReport(scope), isNull);
      expect(await reports.loadHistory(scope), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dev.ai_report.v3'), 'Legacy report');
    },
  );

  test('account change during token retrieval prevents HTTP', () async {
    await consent.grant(scope);
    var calls = 0;
    final reports = service(
      (_) async {
        calls++;
        return answer();
      },
      token: () async {
        scope = 'account.b';
        return 'token';
      },
    );
    await expectLater(
      reports.generate('Kind: [KIND]', expectedScope: 'account.a'),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(calls, 0);
  });

  test(
    'account change after response prevents result and persistence',
    () async {
      await consent.grant(scope);
      final reports = service((_) async {
        scope = 'account.b';
        return answer();
      });
      await expectLater(
        reports.generate('Kind: [KIND]', expectedScope: 'account.a'),
        throwsA(isA<DevelopmentReportConsentRequiredException>()),
      );
      expect(await reports.loadReport(scope), isNull);
      expect(await reports.loadHistory(scope), isEmpty);
    },
  );

  test('account change during 401 refresh prevents retry', () async {
    await consent.grant(scope);
    var calls = 0;
    final reports = service(
      (_) async {
        calls++;
        return http.Response('{"error":"expired"}', 401);
      },
      token: () async => 'old',
      refresh: () async {
        scope = 'account.b';
        return 'new';
      },
    );
    await expectLater(
      reports.generate('Kind: [KIND]', expectedScope: 'account.a'),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(calls, 1);
  });

  test('consent removal during refresh prevents retry', () async {
    await consent.grant(scope);
    var calls = 0;
    final reports = service(
      (_) async {
        calls++;
        return http.Response('{}', 401);
      },
      token: () async => 'old',
      refresh: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('dev.ai_report_consent.v1.account.a');
        return 'new';
      },
    );
    await expectLater(
      reports.generate('Kind: [KIND]', expectedScope: scope),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(calls, 1);
  });

  test('consent removal after HTTP rejects response', () async {
    await consent.grant(scope);
    final reports = service((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dev.ai_report_consent.v1.account.a');
      return answer();
    });
    await expectLater(
      reports.generate('Kind: [KIND]', expectedScope: scope),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(await reports.loadReport(scope), isNull);
  });

  test('normal 401 retry retains the consent guard', () async {
    await consent.grant(scope);
    var calls = 0;
    final reports = service(
      (_) async => ++calls == 1 ? http.Response('{}', 401) : answer(),
      token: () async => 'old',
      refresh: () async => 'new',
    );
    expect(
      await reports.generate('Kind: [KIND]', expectedScope: scope),
      'Bericht fuer [KIND]',
    );
    expect(calls, 2);
  });

  test('stale result cannot be saved under the new account', () async {
    await consent.grant(scope);
    final reports = service((_) async => answer());
    final text = await reports.generate('Kind: [KIND]', expectedScope: scope);
    scope = 'account.b';
    await consent.grant(scope);
    await expectLater(
      reports.saveReport(text, expectedScope: 'account.a', requestGuard: () {}),
      throwsA(isA<DevelopmentReportConsentRequiredException>()),
    );
    expect(await reports.loadReport(scope), isNull);
    expect(await reports.loadHistory(scope), isEmpty);
  });

  test(
    'generation epoch invalidation rejects a switched-back account',
    () async {
      await consent.grant(scope);
      var epoch = 0;
      final reports = service((_) async {
        epoch += 2;
        return answer();
      });
      await expectLater(
        reports.generate(
          'Kind: [KIND]',
          expectedScope: scope,
          requestGuard: () {
            if (epoch != 0) {
              throw const DevelopmentReportConsentRequiredException();
            }
          },
        ),
        throwsA(isA<DevelopmentReportConsentRequiredException>()),
      );
    },
  );

  test('history retains the existing twelve-report limit', () async {
    await consent.grant(scope);
    final reports = service((_) async => answer());
    for (var i = 0; i < 14; i++) {
      await reports.saveReport(
        'Report $i',
        expectedScope: scope,
        requestGuard: () {},
      );
    }
    final history = await reports.loadHistory(scope);
    expect(history, hasLength(12));
    expect(history.first, endsWith('|||Report 13'));
  });

  Future<void> showConsent(
    WidgetTester tester,
    void Function(bool) result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result(
                await ensureAccountAiConsent(
                  context,
                  consent: consent,
                  titleKey: 'development_consent_title',
                  bodyKey: 'development_consent_body',
                  acceptKey: 'development_consent_accept',
                  failedKey: 'development_consent_save_failed',
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
  }

  testWidgets('write failure is visible and no report is authorized', (
    tester,
  ) async {
    consent = DevelopmentReportConsent(
      scopeProvider: () => scope,
      persist: (key, value) async => false,
    );
    bool? accepted;
    await showConsent(tester, (value) => accepted = value);
    await tester.tap(
      find.text(
        AppStringsManager.getString('en', 'development_consent_accept'),
      ),
    );
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    expect(
      find.text(
        AppStringsManager.getString('en', 'development_consent_save_failed'),
      ),
      findsOneWidget,
    );
    expect(await consent.hasConsent(), isFalse);
  });

  testWidgets('declining consent does not persist consent', (tester) async {
    bool? accepted;
    await showConsent(tester, (value) => accepted = value);
    await tester.tap(find.text(AppStringsManager.getString('en', 'cancel')));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    expect(await consent.hasConsent(), isFalse);
  });

  testWidgets('account change while dialog is open rejects acceptance', (
    tester,
  ) async {
    bool? accepted;
    await showConsent(tester, (value) => accepted = value);
    scope = 'account.b';
    await tester.tap(
      find.text(
        AppStringsManager.getString('en', 'development_consent_accept'),
      ),
    );
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    expect(await consent.hasConsent(), isFalse);
  });
}
