import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/ui/benefit_guide_screen.dart';
import 'package:parentpeak/ui/widgets/account_ai_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late BenefitGuideConsent consent;
  late List<http.Request> requests;
  var changeAccountOnResponse = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.a';
    consent = BenefitGuideConsent(scopeProvider: () => scope);
    requests = [];
    changeAccountOnResponse = false;
  });

  BenefitGuideAgent agentFor(BenefitGuideConsent owner) => BenefitGuideAgent(
    consent: owner,
    aiService: GeminiAIService(
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        authToken: 'audit-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (changeAccountOnResponse) scope = 'account.b';
          return http.Response(
            jsonEncode({
              'text': jsonEncode({
                'matched': [
                  {'benefitId': 'kindergeld', 'name': 'Child benefit'},
                ],
                'nextSteps': ['Contact the authority'],
              }),
            }),
            200,
          );
        }),
      ),
    ),
  );

  Future<Object> ask(BenefitGuideAgent agent, {String? expected}) =>
      agent.guide(
        country: CountryFinanceData.germany,
        situation: 'Income has fallen',
        childAgesYears: const [3],
        isSingleParent: true,
        expectedScope: expected ?? scope,
      );

  test(
    'service blocks sensitive requests without a confirmed guide consent',
    () async {
      await expectLater(
        ask(agentFor(consent)),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'consent persists per account and permits the real HTTP payload',
    () async {
      await consent.grant(scope);
      expect(
        await BenefitGuideConsent(scopeProvider: () => scope).hasConsent(),
        isTrue,
      );
      await ask(agentFor(consent));
      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requests.single.url.path, '/ai/generate');
      expect(body['prompt'], contains('Income has fallen'));
      expect(body['prompt'], contains('3 J.'));
      expect(body['prompt'], contains('Alleinerziehend: ja'));
      expect(body['useGoogleSearch'], isTrue);
    },
  );

  test(
    'new account consent never authorizes the previous account context',
    () async {
      await consent.grant(scope);
      scope = 'account.b';
      expect(await consent.hasConsent(), isFalse);
      await consent.grant(scope);
      await expectLater(
        ask(agentFor(consent), expected: 'account.a'),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test('guest, guide and recipe consents are independent', () async {
    await FamilyRecipeConsent(scopeProvider: () => scope).grant(scope);
    expect(await consent.hasConsent(), isFalse);
    await consent.grant(scope);
    scope = 'guest';
    expect(await consent.hasConsent(), isFalse);
    await consent.grant(scope);
    scope = 'account.b';
    expect(await consent.hasConsent(), isFalse);
  });

  test('negative write acknowledgement leaves AI disabled', () async {
    final failed = BenefitGuideConsent(
      scopeProvider: () => scope,
      persist: (key, value) async => false,
    );
    await expectLater(failed.grant(scope), throwsStateError);
    expect(await failed.hasConsent(), isFalse);
    await expectLater(
      ask(agentFor(failed)),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    expect(requests, isEmpty);
  });

  test('thrown consent persistence errors remain explicit', () async {
    final failed = BenefitGuideConsent(
      scopeProvider: () => scope,
      persist: (key, value) async => throw StateError('Storage failure'),
    );
    await expectLater(failed.grant(scope), throwsStateError);
    expect(await failed.hasConsent(), isFalse);
  });

  test(
    'account change during the response is not returned as local success',
    () async {
      await consent.grant(scope);
      final expected = scope;
      changeAccountOnResponse = true;
      await expectLater(
        ask(agentFor(consent), expected: expected),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  testWidgets('failed consent is visible and a changed account cannot accept',
      (tester) async {
    bool? accepted;
    final failed = BenefitGuideConsent(
      scopeProvider: () => scope,
      persist: (key, value) async => false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          accepted = await ensureAccountAiConsent(
            context,
            consent: failed,
            titleKey: 'benefit_ai_consent_title',
            bodyKey: 'benefit_ai_consent_body',
            acceptKey: 'benefit_ai_consent_accept',
            failedKey: 'benefit_ai_consent_failed',
          );
        },
        child: const Text('Open consent'),
      ))),
    ));
    await tester.tap(find.text('Open consent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and use AI'));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    expect(find.text('Consent could not be saved. No AI request was started.'),
      findsOneWidget);
    expect(await failed.hasConsent(), isFalse);
    await tester.tap(find.text('Open consent'));
    await tester.pumpAndSettle();
    scope = 'account.b';
    await tester.runAsync(() => AuthService.instance.logout());
    await tester.pumpAndSettle();
    expect(find.text('Agree and use AI'), findsNothing);
    expect(find.text('The account has changed. Please close this view.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    expect(await failed.hasConsent(), isFalse);
    await tester.runAsync(() => AuthService.instance.logout());
  });

  testWidgets(
    'screen refusal sends nothing; acceptance is once per account; logout hides input',
    (tester) async {
      await tester.runAsync(
        () => AuthService.instance.debugSeedSessionForTesting(),
      );
      final realConsent = BenefitGuideConsent.instance;
      await tester.pumpWidget(
        MaterialApp(
          home: BenefitGuideScreen(
            country: CountryFinanceData.germany,
            agent: agentFor(realConsent),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Private income situation',
      );
      final askButton = find.byType(FilledButton).first;
      await tester.ensureVisible(askButton);
      await tester.tap(askButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Google Gemini'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await realConsent.hasConsent(), isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Private income situation',
      );
      await tester.tap(askButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and use AI'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(await realConsent.hasConsent(), isTrue);
      expect(requests, hasLength(1));
      await tester.ensureVisible(askButton);
      await tester.tap(askButton);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(requests, hasLength(2));
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text('The account has changed. Please close this view.'),
        findsOneWidget,
      );
      expect(await realConsent.hasConsent(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
