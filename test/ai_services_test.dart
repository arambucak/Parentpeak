import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/services/weekly_reflection_service.dart';
import 'package:parentpeak/config/api_config.dart';

/// Tests for AI services — rate limiting, reflection, Gemini config.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AIRateLimiter', () {
    test('initializes with 0 count', () async {
      await AIRateLimiter.initialize();
      expect(AIRateLimiter.todayCount(), equals(0));
    });

    test('canMakeRequest is true initially', () async {
      await AIRateLimiter.initialize();
      expect(AIRateLimiter.canMakeRequest(), isTrue);
    });

    test('records request increments count', () async {
      SharedPreferences.setMockInitialValues({});
      await AIRateLimiter.initialize();
      final before = AIRateLimiter.todayCount();
      await AIRateLimiter.recordRequest();
      expect(AIRateLimiter.todayCount(), equals(before + 1));
    });

    test('remaining decreases after request', () async {
      SharedPreferences.setMockInitialValues({});
      await AIRateLimiter.initialize();
      final before = AIRateLimiter.remainingRequests();
      await AIRateLimiter.recordRequest();
      expect(AIRateLimiter.remainingRequests(), equals(before - 1));
    });

    test('default daily limit is 50', () {
      expect(AIRateLimiter.dailyLimit, equals(50));
    });

    test('setDailyLimit changes limit', () {
      AIRateLimiter.setDailyLimit(75);
      expect(AIRateLimiter.dailyLimit, equals(75));
      AIRateLimiter.setDailyLimit(50); // reset
    });

    test('limitReachedMessage is user-friendly', () {
      expect(AIRateLimiter.limitReachedMessage, contains('Morgen'));
      expect(AIRateLimiter.limitReachedMessage, contains('50'));
    });

    test('statusText shows count/limit format', () {
      expect(AIRateLimiter.statusText, matches(RegExp(r'\d+/50 heute')));
    });
  });

  group('WeeklyReflectionService', () {
    test('currentWeekId returns ISO format', () {
      final id = WeeklyReflectionService.currentWeekId();
      expect(id, matches(RegExp(r'^\d{4}-W\d{2}$')));
    });

    test('loadAll returns empty list initially', () async {
      SharedPreferences.setMockInitialValues({});
      final all = await WeeklyReflectionService.loadAll();
      expect(all, isEmpty);
    });

    test('currentWeek returns null initially', () async {
      SharedPreferences.setMockInitialValues({});
      final current = await WeeklyReflectionService.currentWeek();
      expect(current, isNull);
    });

    test('save and load reflection works', () async {
      SharedPreferences.setMockInitialValues({});
      final reflection = WeeklyReflection(
        weekId: '2026-W33',
        createdAt: DateTime.now(),
        overallMood: 'Super',
        whatWentWell: 'Alles gut',
        whatWasChallenging: 'Wenig Schlaf',
        whatILearned: 'Geduld',
        lookingForwardTo: 'Wochenende',
      );
      await WeeklyReflectionService.save(reflection);
      final all = await WeeklyReflectionService.loadAll();
      expect(all.length, equals(1));
      expect(all.first.overallMood, equals('Super'));
      expect(all.first.whatWentWell, equals('Alles gut'));
    });

    test('delete removes reflection', () async {
      SharedPreferences.setMockInitialValues({});
      final reflection = WeeklyReflection(
        weekId: '2026-W30',
        createdAt: DateTime.now(),
        overallMood: 'Gut',
        whatWentWell: '',
        whatWasChallenging: '',
        whatILearned: '',
        lookingForwardTo: '',
      );
      await WeeklyReflectionService.save(reflection);
      await WeeklyReflectionService.delete('2026-W30');
      final all = await WeeklyReflectionService.loadAll();
      expect(all.where((r) => r.weekId == '2026-W30'), isEmpty);
    });
  });

  group('APIConfig', () {
    test('default contact email is set', () {
      final email = APIConfig.getContactEmail();
      expect(email, isNotNull);
      expect(email, contains('parentpeak'));
    });

    test('default support URL is set', () {
      final url = APIConfig.getContactSupportUrl();
      expect(url, isNotNull);
      expect(url, contains('parentpeak'));
    });

    test('Gemini model name has default', () {
      final model = APIConfig.getGeminiModelName();
      expect(model, isNotEmpty);
    });
  });
}
