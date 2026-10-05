import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/models/child_development_data.dart';

void main() {
  group('ChildProfile.monthsBetween (Tag-korrekte Altersberechnung)', () {
    test('1 Tag altes Kind ist 0 Monate, nicht 1', () {
      // Regression: früher ergab (year*12 + month-diff) fälschlich 1 Monat.
      final birth = DateTime(2024, 12, 31);
      final now = DateTime(2025, 1, 1);
      expect(ChildProfile.monthsBetween(birth, now), 0);
    });

    test('real 11 Monate altes Kind wird nicht als 12 gezählt', () {
      // Grenzfall 0-12m -> 1-2y: Geburtstag im Monat noch nicht erreicht.
      final birth = DateTime(2024, 1, 20);
      final now = DateTime(2025, 1, 5);
      expect(ChildProfile.monthsBetween(birth, now), 11);
    });

    test('am Geburtstag selbst zählt der Monat als voll', () {
      final birth = DateTime(2024, 1, 20);
      final now = DateTime(2025, 1, 20);
      expect(ChildProfile.monthsBetween(birth, now), 12);
    });

    test('exakt ein Monat nach der Geburt', () {
      expect(
          ChildProfile.monthsBetween(DateTime(2025, 1, 15), DateTime(2025, 2, 15)),
          1);
      expect(
          ChildProfile.monthsBetween(DateTime(2025, 1, 15), DateTime(2025, 2, 14)),
          0);
    });

    test('negative Differenz (Zukunftsgeburtsdatum) ergibt 0', () {
      expect(
          ChildProfile.monthsBetween(DateTime(2025, 6, 1), DateTime(2025, 1, 1)),
          0);
    });
  });

  group('ChildProfile.ageGroupId an den Grenzen', () {
    // Baut ein Profil, dessen Geburtsdatum so gesetzt ist, dass es relativ zum
    // echten Jetzt eine bestimmte Monatszahl ergibt — getestet über die
    // Grenzwerte der Altersgruppen-Zuordnung.
    String groupForMonths(int months) {
      final now = DateTime.now();
      // Geburtsdatum: exakt `months` Monate vor jetzt, Tag beibehalten.
      final birth = DateTime(now.year, now.month - months, now.day);
      return ChildProfile(
        name: 'Test',
        birthDate: birth,
        careType: 'zuhause',
      ).ageGroupId;
    }

    test('11 Monate -> 0-12m, 12 Monate -> 1-2y', () {
      expect(groupForMonths(11), '0-12m');
      expect(groupForMonths(12), '1-2y');
    });

    test('23 Monate -> 1-2y, 24 Monate -> 2-3y', () {
      expect(groupForMonths(23), '1-2y');
      expect(groupForMonths(24), '2-3y');
    });

    test('ältere Grenzen', () {
      expect(groupForMonths(72), '6-10y');
      expect(groupForMonths(120), '10-14y');
      expect(groupForMonths(168), '14-18y');
    });
  });
}
