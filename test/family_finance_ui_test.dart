import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/antragshelfer_screen.dart';
import 'package:parentpeak/ui/benefit_guide_screen.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'explicit finance claim, document persistence and logout remove account RAM',
    (tester) async {
      final original = <String, Object>{
        FamilyFinanceStore.countryKey: 'de',
        FamilyFinanceStore.amountsKey: jsonEncode({'kita': 321.0}),
        FamilyFinanceStore.singleParentKey: true,
        FamilyFinanceStore.documentsKey('kindergeld'): ['0'],
        FamilyFinanceStore.guideKey('de'): ['Private guide step'],
        FamilyHubStore.storageKey: jsonEncode({
          'accounts': {},
          'legacyOwner': 'account.other',
        }),
      };
      SharedPreferences.setMockInitialValues(original);
      await tester.runAsync(
        () => AuthService.instance.debugSeedSessionForTesting(),
      );
      final uid = AuthService.instance.currentUser!.uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        FamilyMatchProfile.storageKey(uid),
        jsonEncode({
          'ownerUserId': uid,
          'profile': {
            'displayName': 'Parent',
            'district': '',
            'children': [
              {'name': 'Private child', 'birthDate': '2023-01-01T00:00:00.000'},
            ],
          },
        }),
      );

      Future<void> open(Widget screen) async {
        await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: screen));
        await tester.pumpAndSettle();
      }

      await open(const FamilienGeldScreen());
      expect(find.text('Claim local financial data'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Claim local financial data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs.containsKey(FamilyFinanceStore.storageKey), isFalse);
      await tester.tap(find.text('Claim local financial data'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.text('Belongs to my account \u2013 claim data'), findsNothing);
      expect(prefs.containsKey(FamilyFinanceStore.storageKey), isFalse);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.runAsync(() => AuthService.instance.debugSeedSessionForTesting());
      await open(const FamilienGeldScreen());
      await tester.tap(find.text('Claim local financial data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belongs to my account \u2013 claim data'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('Claim local financial data'), findsNothing);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, isNotEmpty);
      expect(fields.any((field) => field.controller?.text == '321'), isTrue);
      final controllers = fields.map((field) => field.controller!).toList();
      await tester.tap(find.text('Milestones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Private child'), findsWidgets);
      final owner = FamilyFinanceStore.instance.scope;
      expect(
        (await FamilyFinanceStore.instance.read(
          expectedScope: owner,
        ))[FamilyFinanceStore.singleParentKey],
        isTrue,
      );
      expect(
        prefs.getString(FamilyHubStore.storageKey),
        original[FamilyHubStore.storageKey],
      );
      for (final key in original.keys) {
        expect(prefs.get(key), original[key]);
      }
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Private child'), findsNothing);
      for (final controller in controllers) {
        expect(() => controller.addListener(() {}), throwsFlutterError);
      }
      expect(
        await FamilyFinanceStore.instance.read(
          expectedScope: FamilyFinanceStore.instance.scope,
        ),
        isEmpty,
      );
      await open(const FamilienGeldScreen());
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Claim local financial data'), findsNothing);

      await tester.runAsync(
        () => AuthService.instance.debugSeedSessionForTesting(),
      );
      await open(
        const AntragshelferScreen(benefit: BenefitApplicationDE.kindergeld),
      );
      final firstDocument = find.byType(CheckboxListTile).first;
      expect(tester.widget<CheckboxListTile>(firstDocument).value, isTrue);
      await tester.tap(firstDocument);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(firstDocument).value, isFalse);
      expect(
        await FamilyFinanceStore.instance.loadChecklist(
          FamilyFinanceStore.documentsKey('kindergeld'),
          expectedScope: owner,
        ),
        isEmpty,
      );
      await tester.tap(firstDocument);
      await tester.pumpAndSettle();
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.text('The account has changed. Please close this view.'),
        findsOneWidget,
      );
      await open(
        const AntragshelferScreen(benefit: BenefitApplicationDE.kindergeld),
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isFalse,
      );

      await tester.runAsync(
        () => AuthService.instance.debugSeedSessionForTesting(),
      );
      final consent = BenefitGuideConsent.instance;
      await consent.grant(consent.scope);
      final agent = BenefitGuideAgent(aiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid', authToken: 'audit-token',
          httpClient: MockClient((request) async => http.Response(jsonEncode({
            'text': jsonEncode({'checklist': ['Private guide step']}),
          }), 200)),
        ),
      ));
      await open(BenefitGuideScreen(country: CountryFinanceData.germany, agent: agent));
      final input = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await tester.enterText(find.byType(TextField), 'Private income');
      final askButton = find.byType(FilledButton).first;
      await tester.ensureVisible(askButton);
      await tester.tap(askButton);
      await tester.pumpAndSettle();
      await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.ensureVisible(find.text('Private guide step'));
      await tester.tap(find.text('Private guide step'));
      await tester.pumpAndSettle();
      expect(await FamilyFinanceStore.instance.loadChecklist(
        FamilyFinanceStore.guideKey('de'), expectedScope: owner), isEmpty);
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(() => input.addListener(() {}), throwsFlutterError);
      expect(tester.takeException(), isNull);

      await prefs.setString(FamilyFinanceStore.storageKey, '{invalid');
      await open(const FamilienGeldScreen());
      expect(find.text('Local financial data could not be loaded. Please try again.'),
        findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await open(const AntragshelferScreen(benefit: BenefitApplicationDE.kindergeld));
      expect(find.text('Local financial data could not be loaded. Please try again.'),
        findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await open(const BenefitGuideScreen(country: CountryFinanceData.germany));
      expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed, isNull);
      expect(prefs.getString(FamilyFinanceStore.storageKey), '{invalid');
      expect(tester.takeException(), isNull);
    },
  );
}
