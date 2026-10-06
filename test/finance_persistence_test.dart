import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/finance_number.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FamilyFinanceStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FamilyFinanceStore(userIdProvider: () => 'a');
  });

  test(
    'decimal comma and dot parse without interpreting grouping separators',
    () {
      expect(FinanceNumber.parse('12,34'), 12.34);
      expect(FinanceNumber.parse(' 12.34 '), 12.34);
      expect(FinanceNumber.parse(''), 0);
      expect(FinanceNumber.parse('0'), 0);
      expect(FinanceNumber.parse('9007199254740991'), FinanceNumber.maxAmount);
      for (final input in [
        'NaN',
        'Infinity',
        '-1',
        '1e300',
        '1,234.00',
        '1.234,00',
        '1,234',
        '12,',
        '.',
        'abc',
        '9007199254740992',
      ]) {
        expect(
          () => FinanceNumber.parse(input),
          throwsFormatException,
          reason: input,
        );
      }
    },
  );

  test(
    'invalid types, ranges and non-finite values reject writes before encoding',
    () async {
      for (final value in [
        -1,
        double.nan,
        double.infinity,
        '12',
        FinanceNumber.maxAmount + 1,
      ]) {
        await expectLater(
          Future.sync(
            () => store.write({
              FamilyFinanceStore.savedKey: value,
            }, expectedScope: store.scope),
          ),
          throwsFormatException,
        );
        await expectLater(
          Future.sync(
            () => store.write({
              FamilyFinanceStore.amountsKey: {'kita': value},
            }, expectedScope: store.scope),
          ),
          throwsFormatException,
        );
      }
      for (final value in [-1, 3, 1.5, '1']) {
        await expectLater(
          Future.sync(
            () => store.write({
              FamilyFinanceStore.incomeKey: value,
            }, expectedScope: store.scope),
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        Future.sync(
          () => store.write({
            FamilyFinanceStore.countryKey: 'unknown',
          }, expectedScope: store.scope),
        ),
        throwsFormatException,
      );
      expect(await store.read(expectedScope: store.scope), isEmpty);
    },
  );

  test(
    'DE TRY switch and reopen preserve amounts, savings and eligibility independently',
    () async {
      final de = {
        FamilyFinanceStore.countryKey: 'de',
        FamilyFinanceStore.amountsKey: {'kita': 12.34},
        FamilyFinanceStore.savedKey: 100.0,
        FamilyFinanceStore.savingsGoalKey: 20.0,
        FamilyFinanceStore.incomeKey: 2,
        FamilyFinanceStore.eligibilityKey: true,
        FamilyFinanceStore.singleParentKey: true,
      };
      await store.write(de, expectedScope: store.scope);
      await store.write({
        FamilyFinanceStore.countryKey: 'tr',
      }, expectedScope: store.scope);
      var data = await store.read(expectedScope: store.scope);
      for (final key in FamilyFinanceStore.countryValueKeys) {
        expect(data.containsKey(key), isFalse, reason: key);
      }
      await store.write({
        FamilyFinanceStore.amountsKey: {'kita': 900.0},
        FamilyFinanceStore.savedKey: 10.0,
      }, expectedScope: store.scope);
      await store.write({
        FamilyFinanceStore.countryKey: 'de',
      }, expectedScope: store.scope);
      final reopened = FamilyFinanceStore(userIdProvider: () => 'a');
      data = await reopened.read(expectedScope: reopened.scope);
      for (final entry in de.entries) {
        expect(data[entry.key], entry.value);
      }
      await store.write({
        FamilyFinanceStore.countryKey: 'tr',
      }, expectedScope: store.scope);
      data = await reopened.read(expectedScope: reopened.scope);
      expect(data[FamilyFinanceStore.amountsKey], {'kita': 900.0});
      expect(data[FamilyFinanceStore.savedKey], 10.0);
    },
  );

  test(
    'pre-country account envelope stays in original country, never reinterpreted',
    () async {
      SharedPreferences.setMockInitialValues({
        FamilyFinanceStore.storageKey: jsonEncode({
          'legacyOwner': 'account.a',
          'accounts': {
            'account.a': {
              'owner': 'account.a',
              'data': {
                FamilyFinanceStore.countryKey: 'de',
                FamilyFinanceStore.amountsKey: {'kita': 321.0},
                FamilyFinanceStore.savedKey: 45.0,
              },
            },
          },
        }),
      });
      await store.write({
        FamilyFinanceStore.countryKey: 'tr',
      }, expectedScope: store.scope);
      expect(
        (await store.read(
          expectedScope: store.scope,
        )).containsKey(FamilyFinanceStore.amountsKey),
        isFalse,
      );
      await store.write({
        FamilyFinanceStore.countryKey: 'de',
      }, expectedScope: store.scope);
      expect(
        (await store.read(
          expectedScope: store.scope,
        ))[FamilyFinanceStore.amountsKey],
        {'kita': 321.0},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString(FamilyFinanceStore.storageKey)!,
        )['legacyOwner'],
        'account.a',
      );
    },
  );

  test(
    'invalid nested country data blocks reads without overwriting storage',
    () async {
      final invalid = jsonEncode({
        'accounts': {
          'account.a': {
            'owner': 'account.a',
            'data': {
              FamilyFinanceStore.countryKey: 'de',
              FamilyFinanceStore.countriesKey: {
                'tr': {FamilyFinanceStore.savedKey: -1},
              },
            },
          },
        },
      });
      SharedPreferences.setMockInitialValues({
        FamilyFinanceStore.storageKey: invalid,
      });
      await expectLater(
        store.read(expectedScope: store.scope),
        throwsFormatException,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FamilyFinanceStore.storageKey), invalid);
    },
  );

  test(
    'concurrent category updates merge inside the queue without losing a field',
    () async {
      await store.write({
        FamilyFinanceStore.countryKey: 'de',
      }, expectedScope: store.scope);
      await Future.wait([
        store.write(
          {
            FamilyFinanceStore.amountsKey: {'kita': 12.34},
          },
          expectedScope: store.scope,
          mergeAmounts: true,
        ),
        store.write(
          {
            FamilyFinanceStore.amountsKey: {'food': 56.78},
          },
          expectedScope: store.scope,
          mergeAmounts: true,
        ),
        store.write({
          FamilyFinanceStore.savedKey: 90.0,
        }, expectedScope: store.scope),
      ]);
      final data = await store.read(expectedScope: store.scope);
      expect(data[FamilyFinanceStore.amountsKey], {
        'kita': 12.34,
        'food': 56.78,
      });
      expect(data[FamilyFinanceStore.savedKey], 90.0);
    },
  );

  test(
    'failed category draft is not persisted by a successful other field',
    () async {
      final failed = FamilyFinanceStore(
        userIdProvider: () => 'a',
        persist: (key, value) async => false,
      );
      await expectLater(
        failed.write(
          {
            FamilyFinanceStore.amountsKey: {'kita': 99.0},
          },
          expectedScope: failed.scope,
          mergeAmounts: true,
        ),
        throwsStateError,
      );
      await store.write(
        {
          FamilyFinanceStore.amountsKey: {'food': 42.0},
        },
        expectedScope: store.scope,
        mergeAmounts: true,
      );
      expect(
        (await store.read(
          expectedScope: store.scope,
        ))[FamilyFinanceStore.amountsKey],
        {'food': 42.0},
      );
    },
  );

  test(
    'account values without a chosen country stay in the original DE default',
    () async {
      SharedPreferences.setMockInitialValues({
        FamilyFinanceStore.storageKey: jsonEncode({
          'accounts': {
            'account.a': {
              'owner': 'account.a',
              'data': {
                FamilyFinanceStore.amountsKey: {'kita': 321.0},
              },
            },
          },
        }),
      });
      await store.write({
        FamilyFinanceStore.countryKey: 'tr',
      }, expectedScope: store.scope);
      expect(
        (await store.read(
          expectedScope: store.scope,
        )).containsKey(FamilyFinanceStore.amountsKey),
        isFalse,
      );
      await store.write({
        FamilyFinanceStore.countryKey: 'de',
      }, expectedScope: store.scope);
      expect(
        (await store.read(
          expectedScope: store.scope,
        ))[FamilyFinanceStore.amountsKey],
        {'kita': 321.0},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FamilyFinanceStore.countryKey, 'tr');
      await prefs.setString(
        FamilyFinanceStore.amountsKey,
        jsonEncode({'kita': 999.0}),
      );
      await store.claimLegacy(expectedScope: store.scope);
      final claimed = await store.read(expectedScope: store.scope);
      expect(claimed[FamilyFinanceStore.countryKey], 'de');
      expect(claimed[FamilyFinanceStore.amountsKey], {'kita': 321.0});
    },
  );

  test(
    'negative acknowledgement preserves the selected country and values',
    () async {
      await store.write({
        FamilyFinanceStore.countryKey: 'de',
        FamilyFinanceStore.savedKey: 10.0,
      }, expectedScope: store.scope);
      final failed = FamilyFinanceStore(
        userIdProvider: () => 'a',
        persist: (key, value) async => false,
      );
      await expectLater(
        failed.write({
          FamilyFinanceStore.countryKey: 'tr',
        }, expectedScope: failed.scope),
        throwsStateError,
      );
      expect(
        (await store.read(
          expectedScope: store.scope,
        ))[FamilyFinanceStore.countryKey],
        'de',
      );
      expect(
        (await store.read(
          expectedScope: store.scope,
        ))[FamilyFinanceStore.savedKey],
        10.0,
      );
    },
  );
}
