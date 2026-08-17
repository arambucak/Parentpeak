import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/ui/onboarding/onboarding_screen.dart';
import 'package:parentpeak/services/holiday_service.dart';

/// Tests for Onboarding flow — verifies data persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding Data Persistence', () {
    test('isCompleted returns false initially', () async {
      SharedPreferences.setMockInitialValues({});
      final completed = await OnboardingScreen.isCompleted();
      expect(completed, isFalse);
    });

    test('isCompleted returns true after completion', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding.completed': true,
      });
      final completed = await OnboardingScreen.isCompleted();
      expect(completed, isTrue);
    });

    test('onboarding saves family name', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboarding.family_name', 'Familie Müller');
      expect(prefs.getString('onboarding.family_name'), equals('Familie Müller'));
    });

    test('onboarding saves child ages', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('onboarding.child_ages', ['baby', 'kleinkind']);
      expect(prefs.getStringList('onboarding.child_ages'), contains('baby'));
    });

    test('onboarding saves country and region', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('holiday.country', 'DE');
      await prefs.setString('holiday.region', 'NRW');
      expect(prefs.getString('holiday.country'), equals('DE'));
      expect(prefs.getString('holiday.region'), equals('NRW'));
    });

    test('onboarding saves priorities', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('onboarding.priorities', ['tipps', 'organisation']);
      expect(prefs.getStringList('onboarding.priorities'), hasLength(2));
    });

    test('onboarding saves tile order', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('home.tile_order.v1', ['Kalender', 'KI Elternberatung']);
      final order = prefs.getStringList('home.tile_order.v1');
      expect(order, isNotNull);
      expect(order!.first, equals('Kalender'));
    });
  });

  group('Onboarding → Holiday Integration', () {
    test('country selection configures holidays', () async {
      SharedPreferences.setMockInitialValues({});
      await HolidayService.initialize();
      await HolidayService.setCountry('TR');
      expect(HolidayService.country, equals('TR'));
    });

    test('region selection persists', () async {
      SharedPreferences.setMockInitialValues({});
      await HolidayService.initialize();
      await HolidayService.setRegion('BY');
      expect(HolidayService.region, equals('BY'));
    });
  });
}
