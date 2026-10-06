import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late FamilyFinanceStore store;
  final guide = FamilyFinanceStore.guideKey('de');
  final docs = FamilyFinanceStore.documentsKey('kindergeld');

  Map<String, Object> legacy() => {
    FamilyFinanceStore.countryKey: 'de',
    FamilyFinanceStore.amountsKey: jsonEncode({'food': 321.0, 'rent': 654.0}),
    FamilyFinanceStore.eligibilityKey: true,
    FamilyFinanceStore.employeeKey: false,
    FamilyFinanceStore.singleParentKey: true,
    FamilyFinanceStore.incomeKey: 2,
    FamilyFinanceStore.savingsGoalKey: 100.0,
    FamilyFinanceStore.savedKey: 500.0,
    guide: ['Contact authority'],
    docs: ['0', '2'],
    FamilyFinanceStore.documentsKey('unknown_old_benefit'): ['1'],
    'famgeld.ai_guide_consent.v1.account.a': true,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = FamilyFinanceStore(userIdProvider: () => uid);
  });

  test(
    'every financial value and both checklists separate A, B and guest',
    () async {
      final a = store.scope;
      await store.write({
        ...legacy()..remove('famgeld.ai_guide_consent.v1.account.a'),
        FamilyFinanceStore.amountsKey: {'food': 321.0},
      }, expectedScope: a);
      uid = 'b';
      expect(await store.read(expectedScope: store.scope), isEmpty);
      await store.saveChecklist(docs, {'1'}, expectedScope: store.scope);
      uid = null;
      expect(await store.read(expectedScope: store.scope), isEmpty);
      await store.write({
        FamilyFinanceStore.countryKey: 'tr',
      }, expectedScope: store.scope);
      uid = 'a';
      final data = await store.read(expectedScope: a);
      expect(data[FamilyFinanceStore.amountsKey], {'food': 321.0});
      expect(data[FamilyFinanceStore.singleParentKey], isTrue);
      expect(await store.loadChecklist(guide, expectedScope: a), {
        'Contact authority',
      });
      expect(await store.loadChecklist(docs, expectedScope: a), {'0', '2'});
      expect(data.keys, containsAll(FamilyFinanceStore.valueKeys));
    },
  );

  test(
    'global data is invisible and unchanged until atomic explicit claim',
    () async {
      final original = legacy();
      SharedPreferences.setMockInitialValues(original);
      final scope = store.scope;
      expect(await store.read(expectedScope: scope), isEmpty);
      expect(await store.hasUnassignedLegacy(expectedScope: scope), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(FamilyFinanceStore.storageKey), isFalse);
      await store.claimLegacy(expectedScope: scope);
      final data = await store.read(expectedScope: scope);
      expect(data[FamilyFinanceStore.amountsKey], {
        'food': 321.0,
        'rent': 654.0,
      });
      expect(data[docs], ['0', '2']);
      expect(data[FamilyFinanceStore.documentsKey('unknown_old_benefit')], [
        '1',
      ]);
      expect(
        data.containsKey('famgeld.ai_guide_consent.v1.account.a'),
        isFalse,
      );
      for (final key in original.keys) {
        expect(
          prefs.get(key),
          original[key],
          reason: 'Backup $key must survive',
        );
      }
      final root = jsonDecode(prefs.getString(FamilyFinanceStore.storageKey)!);
      expect(root['legacyOwner'], scope);
    },
  );

  test(
    'finance claim is independent of an already claimed central envelope',
    () async {
      SharedPreferences.setMockInitialValues({
        ...legacy(),
        FamilyHubStore.storageKey: jsonEncode({
          'accounts': {},
          'legacyOwner': 'account.other',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final centralBefore = prefs.getString(FamilyHubStore.storageKey);
      await store.claimLegacy(expectedScope: store.scope);
      expect(prefs.getString(FamilyHubStore.storageKey), centralBefore);
      expect((await store.read(expectedScope: store.scope))[docs], ['0', '2']);
    },
  );

  test(
    'finance claim neither claims central legacy nor imports guide consent',
    () async {
      SharedPreferences.setMockInitialValues({
        ...legacy(),
        FamilyHubStore.todoKey: '[]',
      });
      await store.claimLegacy(expectedScope: store.scope);
      final hub = FamilyHubStore(userIdProvider: () => uid);
      expect(await hub.hasUnassignedLegacy(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(FamilyHubStore.storageKey), isFalse);
    },
  );

  test('claim merges checklists and retains existing account values', () async {
    SharedPreferences.setMockInitialValues(legacy());
    await store.write({
      FamilyFinanceStore.countryKey: 'de',
      FamilyFinanceStore.amountsKey: {'food': 99.0},
      FamilyFinanceStore.savedKey: 42.0,
      docs: ['1', '2'],
      guide: ['Current step'],
    }, expectedScope: store.scope);
    await store.claimLegacy(expectedScope: store.scope);
    final data = await store.read(expectedScope: store.scope);
    expect(data[FamilyFinanceStore.amountsKey], {'food': 99.0, 'rent': 654.0});
    expect(data[FamilyFinanceStore.savedKey], 42.0);
    expect((data[docs] as List).toSet(), {'0', '1', '2'});
    expect((data[guide] as List).toSet(), {
      'Current step',
      'Contact authority',
    });
  });

  test(
    'claim does not reinterpret legacy money as another country currency',
    () async {
      SharedPreferences.setMockInitialValues(legacy());
      await store.write({
        FamilyFinanceStore.countryKey: 'tr',
      }, expectedScope: store.scope);
      await store.claimLegacy(expectedScope: store.scope);
      final data = await store.read(expectedScope: store.scope);
      expect(data[FamilyFinanceStore.countryKey], 'tr');
      for (final key in [
        FamilyFinanceStore.amountsKey,
        FamilyFinanceStore.savedKey,
        FamilyFinanceStore.savingsGoalKey,
        FamilyFinanceStore.incomeKey,
      ]) {
        expect(data.containsKey(key), isFalse);
      }
      expect(data[guide], ['Contact authority']);
    },
  );

  test('claim is idempotent and cannot be imported by B or guest', () async {
    SharedPreferences.setMockInitialValues(legacy());
    final a = store.scope;
    await store.claimLegacy(expectedScope: a);
    final before = await store.read(expectedScope: a);
    await store.claimLegacy(expectedScope: a);
    expect(await store.read(expectedScope: a), before);
    uid = 'b';
    await expectLater(
      store.claimLegacy(expectedScope: store.scope),
      throwsStateError,
    );
    expect(
      await store.hasUnassignedLegacy(expectedScope: store.scope),
      isFalse,
    );
    expect(await store.read(expectedScope: store.scope), isEmpty);
    uid = null;
    await expectLater(
      store.claimLegacy(expectedScope: store.scope),
      throwsStateError,
    );
  });

  test(
    'guest and stale owner cannot claim unassigned financial data',
    () async {
      SharedPreferences.setMockInitialValues(legacy());
      final a = store.scope;
      uid = null;
      await expectLater(
        store.claimLegacy(expectedScope: a),
        throwsA(isA<FamilyHubAccountChanged>()),
      );
      await expectLater(
        store.claimLegacy(expectedScope: store.scope),
        throwsStateError,
      );
      expect(
        await store.hasUnassignedLegacy(expectedScope: store.scope),
        isTrue,
      );
    },
  );

  test(
    'corrupt legacy rejects the whole claim without assigning anything',
    () async {
      SharedPreferences.setMockInitialValues(
        legacy()..[FamilyFinanceStore.amountsKey] = '{invalid',
      );
      await expectLater(
        store.claimLegacy(expectedScope: store.scope),
        throwsFormatException,
      );
      expect(await store.read(expectedScope: store.scope), isEmpty);
      expect(
        await store.hasUnassignedLegacy(expectedScope: store.scope),
        isTrue,
      );
    },
  );

  test(
    'negative or thrown persistence keeps claim unassigned and retryable',
    () async {
      SharedPreferences.setMockInitialValues(legacy());
      for (final throws in [false, true]) {
        final failed = FamilyFinanceStore(
          userIdProvider: () => uid,
          persist: (key, value) async {
            if (throws) throw StateError('Storage failure');
            return false;
          },
        );
        await expectLater(
          failed.claimLegacy(expectedScope: failed.scope),
          throwsStateError,
        );
        expect(
          await store.hasUnassignedLegacy(expectedScope: store.scope),
          isTrue,
        );
        expect(await store.read(expectedScope: store.scope), isEmpty);
      }
      await store.claimLegacy(expectedScope: store.scope);
      expect(
        await store.hasUnassignedLegacy(expectedScope: store.scope),
        isFalse,
      );
    },
  );

  test('queued stale writes never land in the new account', () async {
    final pending = Completer<bool>();
    final started = Completer<void>();
    final slow = FamilyFinanceStore(
      userIdProvider: () => uid,
      persist: (key, value) {
        started.complete();
        return pending.future;
      },
    );
    final a = slow.scope;
    final first = slow.write({
      FamilyFinanceStore.countryKey: 'de',
    }, expectedScope: a);
    final rejected = expectLater(
      first,
      throwsA(isA<FamilyHubAccountChanged>()),
    );
    await started.future;
    final second = store.saveChecklist(docs, {'0'}, expectedScope: a);
    final rejectedSecond = expectLater(
      second,
      throwsA(isA<FamilyHubAccountChanged>()),
    );
    uid = 'b';
    pending.complete(true);
    await rejected;
    await rejectedSecond;
    expect(await store.read(expectedScope: store.scope), isEmpty);
    await store.saveChecklist(docs, {'1'}, expectedScope: store.scope);
    expect(await store.loadChecklist(docs, expectedScope: store.scope), {'1'});
  });

  test('serialized independent checklist writes retain both domains', () async {
    final a = store.scope;
    await Future.wait([
      store.saveChecklist(docs, {'0'}, expectedScope: a),
      store.saveChecklist(guide, {'Guide step'}, expectedScope: a),
      store.write({FamilyFinanceStore.countryKey: 'de'}, expectedScope: a),
    ]);
    final data = await store.read(expectedScope: a);
    expect(data[docs], ['0']);
    expect(data[guide], ['Guide step']);
    expect(data[FamilyFinanceStore.countryKey], 'de');
  });

  test(
    'invalid envelope owner never falls back to global financial data',
    () async {
      SharedPreferences.setMockInitialValues({
        ...legacy(),
        FamilyFinanceStore.storageKey: jsonEncode({
          'accounts': {
            'account.a': {'owner': 'account.b', 'data': {}},
          },
        }),
      });
      await expectLater(
        store.read(expectedScope: store.scope),
        throwsFormatException,
      );
    },
  );
}
