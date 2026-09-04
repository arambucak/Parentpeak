import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';
import 'package:parentpeak/services/weekly_reflection_service.dart';
import 'package:parentpeak/services/holiday_service.dart';

/// Smoke tests — verify core services don't crash.
/// These run in CI on every push to catch regressions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Core Services', () {
    test('APIConfig provides default values', () {
      expect(APIConfig.getContactEmail(), isNotNull);
      expect(APIConfig.getContactEmail(), contains('parentpeak'));
    });

    test('AIRateLimiter initializes without crash', () async {
      await AIRateLimiter.initialize();
      expect(AIRateLimiter.canMakeRequest(), isTrue);
      expect(AIRateLimiter.remainingRequests(), greaterThan(0));
      expect(AIRateLimiter.dailyLimit, equals(25));
    });

    test('AIRateLimiter statusText is formatted', () {
      expect(AIRateLimiter.statusText, contains('/25'));
    });

    test('ChatModerationService blocks profanity', () {
      final svc = ChatModerationService.instance;
      expect(svc.isSafe('Hallo, wie geht es dir?'), isTrue);
      expect(svc.isSafe('Du bist eine tolle Mama!'), isTrue);
      expect(svc.isSafe('fick dich'), isFalse);
      expect(svc.checkMessage('fick dich'), contains('respektvollen'));
    });

    test('ChatModerationService blocks spam', () {
      final svc = ChatModerationService.instance;
      expect(svc.isSafe('Hallo wie gehts'), isTrue); // 12 chars, not enough
      expect(svc.isSafe('aaaaaaaaaaaaaaaa'), isFalse); // 13+ repeated
      // Grossschreibung ist erlaubt (Emphase, kein Spam) - familienfreundlich.
      expect(svc.isSafe('DIES IST EIN GANZ NORMALER TEXT'), isTrue);
    });

    test('ChatModerationService blocks commercial content', () {
      final svc = ChatModerationService.instance;
      expect(svc.isSafe('Kennst du einen guten Kinderarzt?'), isTrue);
      expect(svc.isSafe('Kaufe jetzt mein Produkt!'), isFalse);
      expect(svc.isSafe('Verdiene geld von zuhause'), isFalse);
    });

    test('ChatModerationService warns about personal data', () {
      final svc = ChatModerationService.instance;
      expect(svc.isSafe('Treffen wir uns am Spielplatz?'), isTrue);
      expect(svc.isSafe('Meine Nummer ist +49 171 12345'), isFalse);
      expect(svc.checkMessage('+49 171 12345'), contains('persönlichen Daten'));
    });

    test('WeeklyReflectionService currentWeekId format', () {
      final id = WeeklyReflectionService.currentWeekId();
      expect(id, matches(RegExp(r'^\d{4}-W\d{2}$')));
    });

    test('HolidayService provides countries', () {
      expect(HolidayService.availableCountries, isNotEmpty);
      expect(
        HolidayService.availableCountries.any((c) => c['code'] == 'DE'),
        isTrue,
      );
    });

    test('HolidayService provides German regions', () {
      final regions = HolidayService.getRegionsForCountry('DE');
      expect(regions.length, equals(16));
      expect(regions.any((r) => r['code'] == 'NRW'), isTrue);
    });

    test('HolidayService returns holidays for 2026', () {
      final holidays = HolidayService.getHolidaysForMonth(2026, 12);
      expect(holidays, isNotEmpty);
      expect(holidays.any((h) => h.name.contains('Weihnacht')), isTrue);
    });
  });
}
