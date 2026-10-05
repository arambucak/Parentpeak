import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/config/country_finance_data.dart';

void main() {
  group('CountryFinanceConfig.formatAmount — Tausendertrennung', () {
    const de = CountryFinanceData.germany; // Symbol €
    const tr = CountryFinanceData.turkey; // Symbol ₺

    test('fügt Tausenderpunkte korrekt ein', () {
      expect(de.formatAmount(15000), '15.000€');
      expect(de.formatAmount(1500000), '1.500.000€');
      expect(tr.formatAmount(15000), '15.000₺');
    });

    test('kleine Beträge bleiben ohne Punkt', () {
      expect(de.formatAmount(0), '0€');
      expect(de.formatAmount(250), '250€');
      expect(de.formatAmount(999), '999€');
    });

    test('rundet auf ganze Einheiten', () {
      expect(de.formatAmount(1234.56), '1.235€');
      expect(de.formatAmount(1000.4), '1.000€');
    });

    test('negative Beträge behalten das Vorzeichen', () {
      expect(de.formatAmount(-1500), '-1.500€');
    });
  });
}
