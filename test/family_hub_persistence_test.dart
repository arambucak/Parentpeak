import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_hub_todos.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/logic/fridge_recipe_service.dart';
import 'package:parentpeak/logic/fridge_photo_consent.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FamilyHubStore store;
  late FamilyHubStore failing;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FamilyHubStore(userIdProvider: () => 'owner');
    failing = FamilyHubStore(
      userIdProvider: () => 'owner',
      persist: (key, value) async => false,
    );
  });

  test('failed dossier mutation keeps both RAM and disk unchanged', () async {
    final original = KindDossier(
      id: 'child',
      childName: 'Original',
      allergies: ['Milch'],
    );
    await KindDossierService(store: store).save([original]);
    final service = KindDossierService(store: failing);
    await service.load();
    await expectLater(
      service.addOrUpdate(original.copyWith(childName: 'Changed')),
      throwsStateError,
    );
    expect(service.dossiers.single.childName, 'Original');
    final persisted = KindDossierService(store: store);
    await persisted.load();
    expect(persisted.dossiers.single.childName, 'Original');
  });

  test('failed exam toggle does not publish the new completed state', () async {
    await KindDossierService(store: store).save([
      KindDossier(
        id: 'child',
        childName: 'Child',
        uExams: UExaminationData.generateForChild(24),
      ),
    ]);
    final service = KindDossierService(store: failing);
    await service.load();
    await expectLater(
      service.setUExamDone('child', 'u3', true),
      throwsStateError,
    );
    expect(
      service.dossiers.single.uExams
          .firstWhere((exam) => exam.id == 'u3')
          .isDone,
      isFalse,
    );
  });

  test(
    'failed shopping add and toggle do not publish unconfirmed items',
    () async {
      final good = ShoppingListService(store: store);
      await good.load();
      final original = ShoppingItem.fromInput('Milk');
      await good.addItem(original);
      final service = ShoppingListService(store: failing);
      await service.load();
      await expectLater(
        service.addItem(ShoppingItem.fromInput('Bread')),
        throwsStateError,
      );
      expect(service.activeItems.map((item) => item.name), ['Milk']);
      expect(service.frequentItems, ['milk']);
      await expectLater(service.toggleDone(original.id), throwsStateError);
      expect(service.activeItems.single.isDone, isFalse);
      expect(service.doneItems, isEmpty);
    },
  );

  test(
    'concurrent dossier additions from independent services are preserved',
    () async {
      final first = KindDossierService(store: store);
      final second = KindDossierService(store: store);
      await first.load();
      await second.load();
      await Future.wait([
        first.addOrUpdate(KindDossier(childName: 'First')),
        second.addOrUpdate(KindDossier(childName: 'Second')),
      ]);
      await first.load();
      expect(first.dossiers.map((child) => child.childName), [
        'First',
        'Second',
      ]);
    },
  );

  test(
    'concurrent shopping additions and duplicate recipe ingredients are serialized',
    () async {
      final first = ShoppingListService(store: store);
      final second = ShoppingListService(store: store);
      await first.load();
      await second.load();
      await Future.wait([
        first.addItemsFromRecipe(['Rice', 'Carrot']),
        second.addItemsFromRecipe(['Rice', 'Milk']),
      ]);
      await first.load();
      expect(first.activeItems.map((item) => item.name).toSet(), {
        'Rice',
        'Carrot',
        'Milk',
      });
      expect(first.activeItems, hasLength(3));
    },
  );

  test(
    'todo add toggle and remove keep all concurrent changes after reload',
    () async {
      final service = FamilyHubTodos(store: store);
      await Future.wait([
        service.add(store.scope, 'First'),
        service.add(store.scope, 'Second'),
      ]);
      var todos = await service.load(store.scope);
      expect(todos, hasLength(2));
      expect(todos.map((todo) => todo['id']).toSet(), hasLength(2));
      await service.toggle(store.scope, todos.first['id']);
      todos = await service.load(store.scope);
      expect(todos.first['done'], isTrue);
      await service.remove(store.scope, todos.first['id']);
      expect(await service.load(store.scope), hasLength(1));
    },
  );

  test('failed todo mutation preserves committed state', () async {
    final service = FamilyHubTodos(store: store);
    final original = await service.add(store.scope, 'Original');
    await expectLater(
      FamilyHubTodos(
        store: failing,
      ).toggle(failing.scope, original.single['id']),
      throwsStateError,
    );
    expect(await service.load(store.scope), original);
  });

  test(
    'thrown platform write errors propagate and the queue stays usable',
    () async {
      final broken = FamilyHubStore(
        userIdProvider: () => 'owner',
        persist: (key, value) async => throw StateError('Disk failure'),
      );
      await expectLater(
        broken.write({}, expectedScope: broken.scope),
        throwsStateError,
      );
      await FamilyHubTodos(store: store).add(store.scope, 'Recovery');
      expect(
        await FamilyHubTodos(store: store).load(store.scope),
        hasLength(1),
      );
    },
  );

  test(
    'invalid todo types and malformed health dates are not silent defaults',
    () async {
      await store.write({
        FamilyHubStore.todoKey: [
          {'id': 1, 'text': 'Task', 'done': 'yes'},
        ],
      }, expectedScope: store.scope);
      await expectLater(
        FamilyHubTodos(store: store).load(store.scope),
        throwsFormatException,
      );
      expect(
        () => KindDossier.fromJson({
          'childName': 'Child',
          'birthDate': 'not-a-date',
        }),
        throwsFormatException,
      );
      expect(
        () =>
            ShoppingItem.fromJson({'name': 'Milk', 'createdAt': 'not-a-date'}),
        throwsFormatException,
      );
    },
  );

  test(
    'corrupt dossier storage stops both recipe consumers instead of assuming no allergies',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FamilyHubStore.storageKey, '{invalid');
      await FridgePhotoConsent.instance.grant(FridgePhotoConsent.instance.scope);
      await expectLater(
        FamilyRecipeService().initialize(),
        throwsFormatException,
      );
      await expectLater(
        FridgeRecipeService().generateFromIngredients(
          ['Rice'], expectedScope: FridgePhotoConsent.instance.scope),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'malformed profile import shows load failure instead of silently continuing',
    (tester) async {
      await tester.runAsync(() async {
        await AuthService.instance.debugSeedSessionForTesting();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          FamilyMatchProfile.storageKey(AuthService.instance.currentUser!.uid),
          '{invalid',
        );
      });
      await tester.pumpWidget(
        const MaterialApp(home: FamilienZentraleScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => AuthService.instance.logout());
    },
  );

  testWidgets(
    'malformed todo storage shows load failure, not an empty successful screen',
    (tester) async {
      final hub = FamilyHubStore.instance;
      await tester.runAsync(() => hub.write({
        FamilyHubStore.todoKey: [
          {'id': 1, 'text': 42},
        ],
      }, expectedScope: hub.scope));
      await tester.pumpWidget(
        const MaterialApp(home: FamilienZentraleScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
