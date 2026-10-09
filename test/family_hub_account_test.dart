import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/logic/fridge_recipe_service.dart';
import 'package:parentpeak/logic/fridge_photo_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/family_hub_migration.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late FamilyHubStore store;
  late KindDossierService dossiers;
  late ShoppingListService shopping;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    uid = 'owner-a';
    store = FamilyHubStore(userIdProvider: () => uid);
    dossiers = KindDossierService(store: store);
    shopping = ShoppingListService(store: store);
    await dossiers.load();
    await shopping.load();
  });

  Map<String, Object> legacy() => {
    FamilyHubStore.dossierKey: jsonEncode([
      {
        'childName': 'Legacy child',
        'ageMonths': 20,
        'allergies': ['Milch'],
        'doctorName': 'Legacy doctor',
        'emergencyPhone': '1234567',
      },
    ]),
    FamilyHubStore.activeKey: jsonEncode([
      ShoppingItem.fromInput('Legacy milk').toJson(),
    ]),
    FamilyHubStore.doneKey: jsonEncode([
      ShoppingItem.fromInput(
        'Legacy bread',
      ).copyWith(isDone: true, doneAt: DateTime.now()).toJson(),
    ]),
    FamilyHubStore.frequentKey: ['legacy milk'],
    FamilyHubStore.todoKey: jsonEncode([
      {'id': 42, 'text': 'Legacy task', 'done': false},
    ]),
    FamilyHubStore.allergyKey: ['Gluten'],
  };

  test(
    'all stores separate A, B and signed-out guest without clearing A on disk',
    () async {
      final a = store.scope;
      await dossiers.save([
        KindDossier(childName: 'A child', allergies: ['Milch']),
      ]);
      await shopping.addItem(ShoppingItem.fromInput('A milk'));
      await store.write({
        FamilyHubStore.todoKey: [
          {'text': 'A task', 'done': false},
        ],
      }, expectedScope: a);
      uid = 'owner-b';
      expect(dossiers.dossiers, isEmpty);
      expect(shopping.activeItems, isEmpty);
      expect(shopping.frequentItems, isEmpty);
      await dossiers.load();
      await shopping.load();
      expect(
        (await store.read(expectedScope: store.scope))[FamilyHubStore.todoKey],
        isNull,
      );
      await dossiers.save([KindDossier(childName: 'B child')]);
      uid = null;
      expect(dossiers.dossiers, isEmpty);
      await dossiers.load();
      await shopping.load();
      expect(dossiers.dossiers, isEmpty);
      await dossiers.save([KindDossier(childName: 'Guest child')]);
      uid = 'owner-a';
      await dossiers.load();
      await shopping.load();
      expect(dossiers.dossiers.single.childName, 'A child');
      expect(shopping.activeItems.single.name, 'A milk');
      expect((await store.read(expectedScope: a))[FamilyHubStore.todoKey], [
        {'text': 'A task', 'done': false},
      ]);
    },
  );

  test(
    'legacy data stays untouched and invisible until explicit claim',
    () async {
      final initial = legacy();
      SharedPreferences.setMockInitialValues(initial);
      await dossiers.load();
      await shopping.load();
      expect(dossiers.dossiers, isEmpty);
      expect(shopping.activeItems, isEmpty);
      expect(await store.hasUnassignedLegacy(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(FamilyHubStore.storageKey), isFalse);
      await claimFamilyHubLegacy(expectedScope: store.scope, store: store);
      await dossiers.load();
      await shopping.load();
      expect(dossiers.dossiers.single.doctorName, 'Legacy doctor');
      expect(dossiers.dossiers.single.emergencyPhone, '1234567');
      expect(dossiers.dossiers.single.allergies, ['Milch']);
      expect(shopping.activeItems.single.name, 'Legacy milk');
      expect(shopping.doneItems.single.name, 'Legacy bread');
      expect(shopping.frequentItems, ['legacy milk']);
      final data = await store.read(expectedScope: store.scope);
      expect(
        (data[FamilyHubStore.todoKey] as List).single['text'],
        'Legacy task',
      );
      expect(data[FamilyHubStore.allergyKey], ['Gluten']);
      for (final key in initial.keys) {
        expect(
          prefs.get(key),
          initial[key],
          reason: '$key original backup unchanged',
        );
      }
      expect(await store.hasUnassignedLegacy(), isFalse);
    },
  );

  test('claim is idempotent and cannot be repeated by another owner', () async {
    SharedPreferences.setMockInitialValues(legacy());
    await claimFamilyHubLegacy(expectedScope: store.scope, store: store);
    final before = await store.read(expectedScope: store.scope);
    await claimFamilyHubLegacy(expectedScope: store.scope, store: store);
    expect(await store.read(expectedScope: store.scope), before);
    uid = 'owner-b';
    expect(await store.hasUnassignedLegacy(), isFalse);
    await expectLater(
      claimFamilyHubLegacy(expectedScope: store.scope, store: store),
      throwsStateError,
    );
    await dossiers.load();
    expect(dossiers.dossiers, isEmpty);
  });

  test('claim keeps both existing and legacy data when IDs collide', () async {
    SharedPreferences.setMockInitialValues({
      FamilyHubStore.dossierKey: jsonEncode([
        {'id': 'same', 'childName': 'Legacy', 'ageMonths': 12},
      ]),
      FamilyHubStore.todoKey: jsonEncode([
        {'id': 1, 'text': 'Legacy task', 'done': false},
      ]),
    });
    await dossiers.save([KindDossier(id: 'same', childName: 'Current')]);
    await store.write({
      FamilyHubStore.todoKey: [
        {'id': 1, 'text': 'Current task', 'done': false},
      ],
    }, expectedScope: store.scope);
    await claimFamilyHubLegacy(expectedScope: store.scope, store: store);
    await dossiers.load();
    expect(dossiers.dossiers.map((d) => d.childName), ['Current', 'Legacy']);
    expect(dossiers.dossiers.map((d) => d.id).toSet(), hasLength(2));
    final todos =
        (await store.read(expectedScope: store.scope))[FamilyHubStore.todoKey]
            as List;
    expect(todos.map((t) => t['text']), ['Current task', 'Legacy task']);
    expect(todos.map((t) => t['id']).toSet(), hasLength(2));
  });

  test(
    'signed-out and stale-owner claims are rejected without assigning data',
    () async {
      SharedPreferences.setMockInitialValues(legacy());
      final a = store.scope;
      uid = null;
      await expectLater(
        claimFamilyHubLegacy(expectedScope: a, store: store),
        throwsA(isA<FamilyHubAccountChanged>()),
      );
      await expectLater(
        claimFamilyHubLegacy(expectedScope: store.scope, store: store),
        throwsStateError,
      );
      expect(await store.hasUnassignedLegacy(), isTrue);
    },
  );

  test(
    'corrupt legacy blocks the whole claim without losing another domain',
    () async {
      final original = legacy()..[FamilyHubStore.todoKey] = '[invalid';
      SharedPreferences.setMockInitialValues(original);
      await expectLater(
        claimFamilyHubLegacy(expectedScope: store.scope, store: store),
        throwsFormatException,
      );
      expect(await store.hasUnassignedLegacy(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(FamilyHubStore.storageKey), isFalse);
      expect(
        prefs.getString(FamilyHubStore.dossierKey),
        original[FamilyHubStore.dossierKey],
      );
    },
  );

  test('failed claim write assigns nothing and is retryable', () async {
    SharedPreferences.setMockInitialValues(legacy());
    final failing = FamilyHubStore(
      userIdProvider: () => uid,
      persist: (key, value) async => false,
    );
    await expectLater(
      claimFamilyHubLegacy(expectedScope: failing.scope, store: failing),
      throwsStateError,
    );
    expect(await store.hasUnassignedLegacy(), isTrue);
    await claimFamilyHubLegacy(expectedScope: store.scope, store: store);
    expect(await store.hasUnassignedLegacy(), isFalse);
  });

  test(
    'missing or corrupt account data never keeps previous dossier health data',
    () async {
      await dossiers.save([
        KindDossier(childName: 'A', allergies: ['Milch']),
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(FamilyHubStore.storageKey);
      await dossiers.load();
      expect(dossiers.dossiers, isEmpty);
      await dossiers.save([
        KindDossier(childName: 'A', allergies: ['Milch']),
      ]);
      await prefs.setString(FamilyHubStore.storageKey, '{invalid');
      await expectLater(dossiers.load(), throwsFormatException);
      expect(dossiers.dossiers, isEmpty);
    },
  );

  test(
    'owner envelope mismatch is rejected and does not expose dossiers',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        FamilyHubStore.storageKey,
        jsonEncode({
          'accounts': {
            store.scope: {
              'owner': 'account.someone-else',
              'data': {FamilyHubStore.dossierKey: []},
            },
          },
        }),
      );
      await expectLater(dossiers.load(), throwsFormatException);
      expect(dossiers.dossiers, isEmpty);
    },
  );

  test('queued mutations bind to the original account', () async {
    final a = store.scope;
    final pending = store.write({FamilyHubStore.todoKey: []}, expectedScope: a);
    uid = 'owner-b';
    await expectLater(pending, throwsA(isA<FamilyHubAccountChanged>()));
    expect(await store.read(expectedScope: store.scope), isEmpty);
  });

  test('shared write queue preserves separate domains', () async {
    final other = FamilyHubStore(userIdProvider: () => uid);
    await Future.wait([
      store.write({FamilyHubStore.todoKey: []}, expectedScope: store.scope),
      other.write({FamilyHubStore.activeKey: []}, expectedScope: other.scope),
    ]);
    expect(await store.read(expectedScope: store.scope), {
      FamilyHubStore.todoKey: [],
      FamilyHubStore.activeKey: [],
    });
  });

  test(
    'both recipe consumers only transmit explicitly assigned account allergies',
    () async {
      SharedPreferences.setMockInitialValues(legacy());
      await AuthService.instance.debugSeedSessionForTesting();
      final prompts = <String>[];
      final ai = GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'audit-token',
          httpClient: MockClient((request) async {
            prompts.add((jsonDecode(request.body) as Map)['prompt'] as String);
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
      );
      final recipeService = FamilyRecipeService(aiService: ai);
      final fridgeService = FridgeRecipeService(aiService: ai);
      final fridgeConsent = FridgePhotoConsent.instance;
      await fridgeConsent.grant(fridgeConsent.scope);
      await FamilyRecipeConsent.instance.grant(
        FamilyRecipeConsent.instance.scope,
      );
      await recipeService.initialize();
      await recipeService.generateRecipe();
      await fridgeService.generateFromIngredients([
        'Rice',
      ], expectedScope: fridgeConsent.scope);
      expect(prompts, hasLength(2));
      for (final prompt in prompts) {
        expect(prompt, contains('Keine bekannten Allergien'));
        expect(prompt, isNot(contains('Milch, Gluten')));
      }
      await claimFamilyHubLegacy(expectedScope: FamilyHubStore.instance.scope);
      await recipeService.initialize();
      await recipeService.generateRecipe();
      await fridgeService.generateFromIngredients([
        'Rice',
      ], expectedScope: fridgeConsent.scope);
      for (final prompt in prompts.skip(2)) {
        expect(prompt, contains('Milch, Gluten'));
        expect(prompt, isNot(contains('Legacy child')));
        expect(prompt, isNot(contains('Legacy doctor')));
      }
      await AuthService.instance.logout();
      await expectLater(
        fridgeService.generateFromIngredients([
          'Rice',
        ], expectedScope: fridgeConsent.scope),
        throwsA(isA<FridgePhotoConsentRequiredException>()),
      );
      await fridgeConsent.grant(fridgeConsent.scope);
      await fridgeService.generateFromIngredients([
        'Rice',
      ], expectedScope: fridgeConsent.scope);
      expect(prompts.last, contains('Keine bekannten Allergien'));
      expect(prompts.last, isNot(contains('Milch, Gluten')));
    },
  );

  testWidgets(
    'central decline retains unassigned legacy and logout removes visible health data',
    (tester) async {
      SharedPreferences.setMockInitialValues(legacy());
      await AuthService.instance.debugSeedSessionForTesting();
      await tester.pumpWidget(
        const MaterialApp(home: FamilienZentraleScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Claim local legacy data'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('health and emergency details'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await FamilyHubStore.instance.hasUnassignedLegacy(), isTrue);
      await tester.tap(find.byTooltip('Claim local legacy data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belongs to my account – claim data'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(await FamilyHubStore.instance.hasUnassignedLegacy(), isFalse);
      await tester.tap(find.text('Children'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy child'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Legacy doctor'), findsOneWidget);
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.text('Legacy doctor'), findsNothing);
      expect(find.text('Legacy child'), findsNothing);
      expect(KindDossierService.instance.dossiers, isEmpty);
      expect(
        find.text('The account has changed. Please close this view.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
