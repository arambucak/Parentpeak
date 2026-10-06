import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/benefit_guide_screen.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real cards, savings, five years, share and guide use birthday timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(
      () => AuthService.instance.debugSeedSessionForTesting(),
    );
    final uid = AuthService.instance.currentUser!.uid;
    final prefs = await SharedPreferences.getInstance();
    final store = FamilyFinanceStore.instance;
    await store.write({
      FamilyFinanceStore.countryKey: 'de',
    }, expectedScope: store.scope);
    var now = DateTime(2026, 10, 6);

    Future<void> children(List<String> births) async {
      await prefs.setString(
        FamilyMatchProfile.storageKey(uid),
        jsonEncode({
          'ownerUserId': uid,
          'profile': {
            'displayName': 'Parent',
            'district': '',
            'children': [
              for (var i = 0; i < births.length; i++)
                {'name': 'Child $i', 'birthDate': births[i]},
            ],
          },
        }),
      );
    }

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
          home: FamilienGeldScreen(now: () => now),
        ),
      );
      await settle();
      await tester.tap(find.text('Milestones'));
      await settle();
    }

    await children(['2023-03-06']);
    await openFinance();
    expect(find.textContaining('First bicycle'), findsNWidgets(2));
    expect(find.text('Estimated in 5 months (2027)'), findsOneWidget);
    expect(
      find.textContaining('Estimated in 5 months (2027) · ~250'),
      findsOneWidget,
    );
    expect(find.text('Recommendation: save 50€/month.'), findsOneWidget);
    expect(find.textContaining('About 600€ in costs'), findsOneWidget);
    final bicycleY = tester.getTopLeft(find.text('First bicycle')).dy;
    final schoolY = tester.getTopLeft(find.text('Starting school')).dy;
    expect(bicycleY, lessThan(schoolY));

    String? shared;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        expect(call.method, 'share');
        shared = (call.arguments as Map)['text'] as String;
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        null,
      ),
    );
    await tester.tap(find.byTooltip('Share overview'));
    await settle();
    expect(
      shared,
      contains('First bicycle · ~250€ (Estimated in 5 months (2027))'),
    );
    expect(
      shared!.indexOf('First bicycle'),
      lessThan(shared!.indexOf('Starting school')),
    );
    await store.write({
      FamilyFinanceStore.savedKey: 100.0,
      FamilyFinanceStore.savingsGoalKey: 60.0,
    }, expectedScope: store.scope);
    await openFinance();
    expect(
      find.text(
        'At 60€/month, you are on track to reach the estimated goal within 5 months.',
      ),
      findsOneWidget,
    );
    await store.write({
      FamilyFinanceStore.savingsGoalKey: 20.0,
    }, expectedScope: store.scope);
    await openFinance();
    expect(
      find.text(
        'At 20€/month, you are not yet on track to reach the estimated goal in 5 months.',
      ),
      findsOneWidget,
    );
    await store.write({
      FamilyFinanceStore.savedKey: 0.0,
      FamilyFinanceStore.savingsGoalKey: 0.0,
    }, expectedScope: store.scope);

    await BenefitGuideConsent.instance.grant(store.scope);
    String? prompt;
    final agent = BenefitGuideAgent(
      aiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'audit-token',
          httpClient: MockClient((request) async {
            prompt =
                (jsonDecode(request.body) as Map<String, dynamic>)['prompt']
                    as String;
            return http.Response(
              jsonEncode({
                'text': jsonEncode({
                  'checklist': ['Age boundary checked'],
                }),
              }),
              200,
            );
          }),
        ),
      ),
    );
    Future<void> askGuide() async {
      prompt = null;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: BenefitGuideScreen(
            country: CountryFinanceData.germany,
            agent: agent,
            now: () => now,
          ),
        ),
      );
      await settle();
      await tester.enterText(find.byType(TextField), 'Example situation');
      await tester.ensureVisible(find.byType(FilledButton).first);
      await tester.tap(find.byType(FilledButton).first);
      await settle();
    }

    await askGuide();
    expect(prompt, contains('3 J.'));
    expect(prompt, isNot(contains('4 J.')));
    expect(prompt, isNot(contains('2023-03-06')));

    // The older child's school birthday is sooner than the younger child's bicycle.
    await children(['2023-03-06', '2020-12-20']);
    await openFinance();
    expect(find.textContaining('Starting school'), findsWidgets);
    expect(
      find.textContaining('Estimated in 3 months (2026) · ~350'),
      findsOneWidget,
    );
    expect(find.text('Recommendation: save 117€/month.'), findsOneWidget);

    // The bicycle remains visible until its birthday, even in the same calendar year.
    await children(['2022-12-20']);
    now = DateTime(2026, 12, 19);
    await openFinance();
    expect(find.text('Estimated in 1 month (2026)'), findsOneWidget);
    expect(find.text('Recommendation: save 250€/month.'), findsOneWidget);
    expect(find.textContaining('About 600€ in costs'), findsOneWidget);
    shared = null;
    await tester.tap(find.byTooltip('Share overview'));
    await settle();
    expect(
      shared,
      contains('First bicycle · ~250€ (Estimated in 1 month (2026))'),
    );
    await askGuide();
    expect(prompt, contains('3 J.'));
    expect(prompt, isNot(contains('4 J.')));
    now = DateTime(2026, 12, 20);
    await openFinance();
    expect(find.text('First bicycle'), findsNothing);
    expect(
      find.textContaining('Estimated in 24 months (2028) · ~350'),
      findsOneWidget,
    );
    expect(find.textContaining('About 750€ in costs'), findsOneWidget);
    shared = null;
    await tester.tap(find.byTooltip('Share overview'));
    await settle();
    expect(shared, isNot(contains('First bicycle')));
    expect(
      shared,
      contains('Starting school · ~350€ (Estimated in 24 months (2028))'),
    );
    await askGuide();
    expect(prompt, contains('4 J.'));
    expect(prompt, isNot(contains('3 J.')));

    // A profile-free overview is still chronological, without an invented due date.
    await children([]);
    await openFinance();
    expect(find.text('First bicycle'), findsOneWidget);
    expect(find.textContaining('Estimated in'), findsNothing);
    expect(
      tester.getTopLeft(find.text('First bicycle')).dy,
      lessThan(tester.getTopLeft(find.text('Starting school')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => AuthService.instance.logout());
  });
}
