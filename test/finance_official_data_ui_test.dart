import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tax illustration and all-country benefits remain honest after the quick check',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => AuthService.instance.logout());
      final store = FamilyFinanceStore.instance;

      Future<void> settle() async {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
      }

      Future<void> openCountry(String country, double childcare) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => store.write({
            FamilyFinanceStore.countryKey: country,
            FamilyFinanceStore.amountsKey: {'kita': childcare},
            FamilyFinanceStore.eligibilityKey: true,
            FamilyFinanceStore.employeeKey: false,
            FamilyFinanceStore.singleParentKey: false,
            FamilyFinanceStore.incomeKey: 2,
          }, expectedScope: store.scope),
        );
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: FamilienGeldScreen(store: store),
          ),
        );
        await settle();
      }

      await openCountry('de', 300);
      expect(find.textContaining('2.880€'), findsOneWidget);
      expect(find.textContaining('864€'), findsOneWidget);
      expect(find.textContaining('assumed 30%'), findsOneWidget);
      expect(find.textContaining('Example for one child'), findsOneWidget);
      await tester.ensureVisible(find.text('Potential tax savings'));
      await tester.tap(find.text('Potential tax savings'));
      await settle();
      expect(find.text('Qualifying share (80%)'), findsOneWidget);
      expect(find.text('2.880€'), findsNWidgets(2));
      await openCountry('de', 1000);
      expect(find.textContaining('4.800€'), findsOneWidget);
      expect(find.textContaining('1.440€'), findsOneWidget);

      for (final country in CountryFinanceData.availableCountries) {
        await openCountry(country.code, 0);
        await tester.tap(find.text('Benefits'));
        await settle();
        expect(
          find.textContaining('All benefits remain visible'),
          findsOneWidget,
        );
        final expectedNames = switch (country.code) {
          'de' => [
            'Child Benefit',
            'Child Supplement (KiZ)',
            'Housing Benefit',
            'Advance Maintenance Payment',
            'Care Allowance',
          ],
          _ => country.benefits.map((benefit) => benefit.name).toList(),
        };
        for (final name in expectedNames) {
          expect(
            find.text(name),
            findsWidgets,
            reason: '${country.code}/$name',
          );
        }
        if (country.code == 'de') {
          expect(find.textContaining('297/child/month'), findsOneWidget);
          expect(find.textContaining('347 / 599 / 800 / 990'), findsOneWidget);
        }
        if (country.code == 'gb') {
          expect(find.textContaining('27.05/week'), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
