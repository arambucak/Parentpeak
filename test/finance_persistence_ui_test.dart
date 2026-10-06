import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/benefit_guide_screen.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/ui/antragshelfer_screen.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'amounts and country selection wait for Ack; errors preserve last committed values',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => AuthService.instance.logout());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        FamilyFinanceStore.storageKey,
        jsonEncode({
          'accounts': {
            'guest': {
              'owner': 'guest',
              'data': {
                FamilyFinanceStore.countryKey: 'de',
                FamilyFinanceStore.amountsKey: {'kita': 321.0},
              },
            },
          },
        }),
      );
      Completer<bool>? pending;
      var throwWrite = false;
      var writeCount = 0;
      final store = FamilyFinanceStore(
        persist: (key, value) async {
          writeCount++;
          if (throwWrite) throw StateError('Simulated write error');
          final ack = pending == null ? true : await pending.future;
          if (ack) return prefs.setString(key, value);
          return false;
        },
      );
      Future<void> settle() async {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
      }

      Future<void> openFinance() async {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: FamilienGeldScreen(store: store),
          ),
        );
        await settle();
      }

      Finder input() => find.byType(TextField).first;
      Future<Map<String, dynamic>> data() =>
          store.read(expectedScope: store.scope);

      await openFinance();
      expect(tester.widget<TextField>(input()).controller!.text, '321');
      pending = Completer<bool>();
      await tester.enterText(input(), '12,34');
      await settle();
      expect((await data())[FamilyFinanceStore.amountsKey], {'kita': 321.0});
      expect(find.textContaining('321'), findsWidgets);
      pending.complete(false);
      await settle();
      expect((await data())[FamilyFinanceStore.amountsKey], {'kita': 321.0});
      expect(
        tester.widget<TextField>(input()).decoration!.errorText,
        isNotNull,
      );
      pending = null;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
      expect((await data())[FamilyFinanceStore.amountsKey], {'kita': 12.34});
      expect(tester.widget<TextField>(input()).decoration!.errorText, isNull);
      final writesBeforeInvalid = writeCount;
      for (final invalid in ['NaN', 'Infinity', '-1', 'abc', '1,234.00']) {
        await tester.enterText(input(), invalid);
        await settle();
        expect(
          tester.widget<TextField>(input()).decoration!.errorText,
          'Enter a valid non-negative amount with at most two decimal places.',
        );
        expect((await data())[FamilyFinanceStore.amountsKey], {'kita': 12.34});
      }
      expect(writeCount, writesBeforeInvalid);
      throwWrite = true;
      await tester.enterText(input(), '99');
      await settle();
      expect((await data())[FamilyFinanceStore.amountsKey], {'kita': 12.34});
      expect(
        tester.widget<TextField>(input()).decoration!.errorText,
        isNotNull,
      );
      throwWrite = false;
      await openFinance();
      expect(tester.widget<TextField>(input()).controller!.text, '12.34');

      await tester.tap(find.byIcon(Icons.language_rounded));
      await settle();
      pending = Completer<bool>();
      await tester.ensureVisible(find.text('Türkiye'));
      await tester.tap(find.text('Türkiye'));
      await settle();
      expect((await data())[FamilyFinanceStore.countryKey], 'de');
      expect(find.byType(TextField), findsNothing);
      pending.complete(false);
      await settle();
      expect(find.byType(TextField), findsNothing);
      expect((await data())[FamilyFinanceStore.countryKey], 'de');
      pending = null;
      await tester.tap(find.text('Türkiye'));
      await settle();
      expect((await data())[FamilyFinanceStore.countryKey], 'tr');
      expect(tester.widget<TextField>(input()).controller!.text, '');
      await tester.enterText(input(), '900');
      await settle();
      expect((await data())[FamilyFinanceStore.amountsKey], {'kita': 900.0});
      await tester.tap(find.byIcon(Icons.language_rounded));
      await settle();
      await tester.tap(find.text('Germany'));
      await settle();
      expect(tester.widget<TextField>(input()).controller!.text, '12.34');
      await openFinance();
      expect(tester.widget<TextField>(input()).controller!.text, '12.34');

      await tester.tap(find.text('Benefits'));
      await settle();
      await tester.ensureVisible(find.text('Leistungen filtern'));
      pending = Completer<bool>();
      await tester.tap(find.text('Leistungen filtern'));
      await settle();
      expect((await data())[FamilyFinanceStore.eligibilityKey], isNull);
      pending.complete(false);
      await settle();
      expect((await data())[FamilyFinanceStore.eligibilityKey], isNull);
      expect(find.text('Leistungen filtern'), findsOneWidget);
      pending = null;
      await tester.tap(find.text('Leistungen filtern'));
      await settle();
      expect((await data())[FamilyFinanceStore.eligibilityKey], isTrue);

      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home:
        AntragshelferScreen(benefit: BenefitApplicationDE.kindergeld, store: store)));
      await settle();
      final document = find.byType(CheckboxListTile).first;
      pending = Completer<bool>();
      await tester.tap(document);
      await settle();
      expect(tester.widget<CheckboxListTile>(document).value, isFalse);
      pending.complete(false);
      await settle();
      expect(tester.widget<CheckboxListTile>(document).value, isFalse);
      expect(await store.loadChecklist(FamilyFinanceStore.documentsKey('kindergeld'),
        expectedScope: store.scope), isEmpty);
      pending = null;
      await tester.tap(document);
      await settle();
      expect(tester.widget<CheckboxListTile>(document).value, isTrue);

      await BenefitGuideConsent.instance.grant(store.scope);
      final agent = BenefitGuideAgent(aiService: GeminiAIService(apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid', authToken: 'audit-token',
        httpClient: MockClient((request) async => http.Response(jsonEncode({
          'text': jsonEncode({'checklist': ['Guide test item']}),
        }), 200)),
      )));
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home:
        BenefitGuideScreen(country: CountryFinanceData.germany, agent: agent, store: store)));
      await settle();
      await tester.enterText(find.byType(TextField), 'Example situation');
      await tester.ensureVisible(find.byType(FilledButton).first);
      await tester.tap(find.byType(FilledButton).first);
      await settle();
      await tester.ensureVisible(find.text('Guide test item'));
      pending = Completer<bool>();
      await tester.tap(find.text('Guide test item'));
      await settle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      pending.complete(false);
      await settle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(await store.loadChecklist(FamilyFinanceStore.guideKey('de'),
        expectedScope: store.scope), isEmpty);
      pending = null;
      await tester.tap(find.text('Guide test item'));
      await settle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.runAsync(() => AuthService.instance.debugSeedSessionForTesting());
      final uid = AuthService.instance.currentUser!.uid;
      await prefs.setString(FamilyMatchProfile.storageKey(uid), jsonEncode({
        'ownerUserId': uid, 'profile': {
          'displayName': 'Parent', 'district': '',
          'children': [{'name': 'Child', 'birthDate': '2023-01-01T00:00:00.000'}],
        },
      }));
      await store.write({FamilyFinanceStore.countryKey: 'de'}, expectedScope: store.scope);
      await openFinance();
      await tester.tap(find.text('Milestones'));
      await settle();
      final savings = find.byWidgetPredicate((widget) => widget is TextField &&
        widget.decoration?.labelText == 'Saved so far');
      await tester.ensureVisible(savings);
      pending = Completer<bool>();
      await tester.enterText(savings, '45,67');
      await settle();
      expect((await data())[FamilyFinanceStore.savedKey], isNull);
      pending.complete(false);
      await settle();
      expect((await data())[FamilyFinanceStore.savedKey], isNull);
      pending = null;
      await tester.enterText(savings, '45.68');
      await settle();
      expect((await data())[FamilyFinanceStore.savedKey], 45.68);
      final goal = find.byWidgetPredicate((widget) => widget is TextField &&
        widget.decoration?.labelText == 'Savings rate/month');
      await tester.enterText(goal, '10,50');
      await settle();
      expect((await data())[FamilyFinanceStore.savingsGoalKey], 10.5);
      await tester.runAsync(() => AuthService.instance.logout());

      // An invalid persisted checklist must not paint an acknowledged document.
      await prefs.setString(
        FamilyFinanceStore.storageKey,
        jsonEncode({
          'accounts': {
            'guest': {
              'owner': 'guest',
              'data': {
                FamilyFinanceStore.documentsKey('kindergeld'): ['999'],
              },
            },
          },
        }),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: AntragshelferScreen(benefit: BenefitApplicationDE.kindergeld),
        ),
      );
      await settle();
      expect(
        find.text(
          'Local financial data could not be loaded. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
