import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/allergen_guard.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/ui/familien_kueche_screen.dart';
import 'package:parentpeak/ui/widgets/family_recipe_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingConsent extends FamilyRecipeConsent {
  _FailingConsent() : super(scopeProvider: () => 'account.audit-a');

  @override
  Future<void> grant(String requestedScope) async {
    throw StateError('Simulated consent persistence failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late FamilyRecipeConsent consent;
  late FamilyRecipeService service;
  late List<http.Request> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.audit-a';
    consent = FamilyRecipeConsent(scopeProvider: () => scope);
    requests = [];
    await KindDossierService.instance.save([
      KindDossier(
        childName: 'Sensitive child',
        allergies: ['Milch'],
        doctorName: 'Sensitive doctor',
        emergencyContact: 'Sensitive emergency contact',
      ),
    ]);
    service = FamilyRecipeService(
      consent: consent,
      aiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'audit-token',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'text': jsonEncode({
                  'title': 'Rice',
                  'ingredients': ['Rice', 'Carrots'],
                  'steps': ['Cook'],
                  'minChildAge': 0,
                }),
              }),
              200,
            );
          }),
        ),
      ),
    );
    await service.initialize();
  });

  test(
    'both generation entry points reject requests without consent',
    () async {
      await expectLater(
        service.generateRecipe(),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      await expectLater(
        service.generateRecipeFor('Rice'),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      await expectLater(
        service.generateRecipeFor(''),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test('local inspiration preserves allergy safety without any request', () {
    for (final language in ['de', 'en', 'tr', 'ku']) {
      final recipe = service.localRecipe(languageCode: language);
      expect(recipe, isNotNull);
      expect(AllergenGuard.isRecipeSafe(recipe!, {'milch'}), isTrue);
      expect(recipe.minChildAge, lessThanOrEqualTo(3));
    }
    expect(requests, isEmpty);
  });

  testWidgets('kitchen opening prompts before AI and refusal displays local inspiration',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FamilienKuecheScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(await FamilyRecipeConsent.instance.hasConsent(), isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Local recipe inspiration: No data was sent to AI.'), findsOneWidget);
    expect(await FamilyRecipeConsent.instance.hasConsent(), isFalse);
    expect(tester.takeException(), isNull);
  });

  test(
    'accepted consent is persisted and enables both real HTTP paths',
    () async {
      await consent.grant(scope);
      expect(
        await FamilyRecipeConsent(scopeProvider: () => scope).hasConsent(),
        isTrue,
      );
      await service.generateRecipe();
      await service.generateRecipeFor('Rice');
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.url.path, '/ai/generate');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['prompt'], contains('Milch'));
        expect(body['prompt'], isNot(contains('Sensitive child')));
        expect(body['prompt'], isNot(contains('Sensitive doctor')));
        expect(body['prompt'], isNot(contains('Sensitive emergency contact')));
      }
    },
  );

  test(
    'consent and loaded context cannot be reused after account changes',
    () async {
      await consent.grant(scope);
      scope = 'account.audit-b';
      expect(await consent.hasConsent(), isFalse);
      await expectLater(
        service.generateRecipe(),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      await consent.grant(scope);
      await expectLater(
        service.generateRecipeFor('Rice'),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'a dialog from the previous account cannot grant the new account',
    () async {
      final previousScope = scope;
      scope = 'account.audit-b';
      await expectLater(
        consent.grant(previousScope),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      expect(await consent.hasConsent(), isFalse);
    },
  );

  test(
    'existing fridge photo approval does not approve separate recipe AI',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fridge.ai_photo_consent', true);
      expect(await consent.hasConsent(), isFalse);
      await expectLater(
        service.generateRecipe(),
        throwsA(isA<RecipeAiConsentRequiredException>()),
      );
      expect(requests, isEmpty);
    },
  );

  testWidgets(
    'declining or dismissing the dialog sends no request and saves no approval',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await ensureFamilyRecipeConsent(
                  context,
                  consent: consent,
                ),
                child: const Text('Open consent'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open consent'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google Gemini'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(await consent.hasConsent(), isFalse);
      await tester.tap(find.text('Open consent'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(await consent.hasConsent(), isFalse);
      expect(requests, isEmpty);
    },
  );

  testWidgets(
    'accepting is explicit and the same account is not prompted again',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await ensureFamilyRecipeConsent(
                  context,
                  consent: consent,
                ),
                child: const Text('Open consent'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open consent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and use AI recipes'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(await consent.hasConsent(), isTrue);
      await tester.tap(find.text('Open consent'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isTrue);
      expect(requests, isEmpty);
    },
  );

  testWidgets('consent persistence errors are visible and leave AI disabled',
      (tester) async {
    bool? result;
    final failingConsent = _FailingConsent();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await ensureFamilyRecipeConsent(
              context,
              consent: failingConsent,
            ),
            child: const Text('Open consent'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open consent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and use AI recipes'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Your consent could not be saved safely. AI remains switched off.'), findsOneWidget);
    expect(await failingConsent.hasConsent(), isFalse);
    await expectLater(service.generateRecipe(), throwsA(isA<RecipeAiConsentRequiredException>()));
    expect(requests, isEmpty);
  });
}
