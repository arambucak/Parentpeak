import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/services/holiday_service.dart';

/// Tests for Calendar functionality — holidays, school breaks, persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('HolidayService', () {
    test('German holidays 2026 are correct', () {
      HolidayService.setCountry('DE');
      final jan = HolidayService.getHolidaysForMonth(2026, 1);
      expect(jan.any((h) => h.name == 'Neujahr'), isTrue);

      final oct = HolidayService.getHolidaysForMonth(2026, 10);
      expect(oct.any((h) => h.name == 'Tag der Deutschen Einheit'), isTrue);

      final dec = HolidayService.getHolidaysForMonth(2026, 12);
      expect(dec.any((h) => h.name.contains('Weihnacht')), isTrue);
    });

    test('Austrian holidays exist', () {
      HolidayService.setCountry('AT');
      final oct = HolidayService.getHolidaysForMonth(2026, 10);
      expect(oct.any((h) => h.name == 'Nationalfeiertag'), isTrue);
    });

    test('Turkish holidays exist', () {
      HolidayService.setCountry('TR');
      final apr = HolidayService.getHolidaysForMonth(2026, 4);
      expect(apr, isNotEmpty);
    });

    test('UK holidays exist', () {
      HolidayService.setCountry('GB');
      final dec = HolidayService.getHolidaysForMonth(2026, 12);
      expect(dec.any((h) => h.name == 'Christmas Day'), isTrue);
    });

    test('Swiss holidays exist', () {
      HolidayService.setCountry('CH');
      final aug = HolidayService.getHolidaysForMonth(2026, 8);
      expect(aug.any((h) => h.name == 'Bundesfeiertag'), isTrue);
    });

    test('School holidays NRW 2026 summer', () {
      HolidayService.setCountry('DE');
      HolidayService.setRegion('NRW');
      final july = HolidayService.getSchoolHolidaysForMonth(2026, 7);
      expect(july.any((h) => h.name == 'Sommerferien'), isTrue);
    });

    test('School holidays Bayern 2026', () {
      HolidayService.setCountry('DE');
      HolidayService.setRegion('BY');
      final feb = HolidayService.getSchoolHolidaysForMonth(2026, 2);
      expect(feb.any((h) => h.name == 'Winterferien'), isTrue);
    });

    test('Holiday for specific day returns correct result', () {
      HolidayService.setCountry('DE');
      final holiday = HolidayService.getHolidayForDay(DateTime(2026, 1, 1));
      expect(holiday, isNotNull);
      expect(holiday!.name, equals('Neujahr'));
    });

    test('Non-holiday day returns null', () {
      HolidayService.setCountry('DE');
      final holiday = HolidayService.getHolidayForDay(DateTime(2026, 3, 15));
      expect(holiday, isNull);
    });

    test('Regions for all countries are populated', () {
      for (final country in ['DE', 'AT', 'CH', 'TR', 'GB']) {
        final regions = HolidayService.getRegionsForCountry(country);
        expect(regions, isNotEmpty, reason: 'No regions for $country');
      }
    });

    test('Germany has 16 Bundesländer', () {
      final regions = HolidayService.getRegionsForCountry('DE');
      expect(regions.length, equals(16));
    });
  });
}
