import 'package:shared_preferences/shared_preferences.dart';

/// Wird geworfen, wenn das tägliche KI-Limit erreicht ist. Erlaubt der UI,
/// eine freundliche, spezifische Meldung statt einer generischen zu zeigen.
class AiRateLimitException implements Exception {
  final String message;
  const AiRateLimitException(this.message);
  @override
  String toString() => message;
}

/// Rate limiter for Gemini AI requests.
/// Prevents API key exhaustion at scale.
///
/// Strategy:
/// - Local per-device daily limit (25 requests/day default)
/// - Resets at midnight
/// - Graceful degradation with friendly message
/// - Ready for server-side enforcement when backend proxy is added
class AIRateLimiter {
  static const String _countKey = 'ai_rate.daily_count';
  static const String _dateKey = 'ai_rate.date';
  static const int defaultDailyLimit = 50;

  static int _dailyLimit = defaultDailyLimit;
  static int _todayCount = 0;
  static String _todayDate = '';

  /// Initialize (call once at app start or before first AI request)
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_dateKey) ?? '';
    final today = _todayString();

    if (savedDate == today) {
      _todayCount = prefs.getInt(_countKey) ?? 0;
      _todayDate = today;
    } else {
      // New day — reset counter
      _todayCount = 0;
      _todayDate = today;
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, 0);
    }
  }

  /// Check if user can make another AI request
  static bool canMakeRequest() {
    _ensureTodayReset();
    return _todayCount < _dailyLimit;
  }

  /// How many requests remaining today
  static int remainingRequests() {
    _ensureTodayReset();
    final remaining = _dailyLimit - _todayCount;
    return remaining < 0 ? 0 : remaining;
  }

  /// Record a successful AI request
  static Future<void> recordRequest() async {
    _ensureTodayReset();
    _todayCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, _todayCount);
    await prefs.setString(_dateKey, _todayDate);
  }

  /// Get current count (for UI display)
  static int todayCount() => _todayCount;

  /// Get the daily limit
  static int get dailyLimit => _dailyLimit;

  /// Override daily limit (for future server-side configuration)
  static void setDailyLimit(int limit) {
    _dailyLimit = limit;
  }

  /// User-friendly message when limit is reached
  static String get limitReachedMessage =>
      'Du hast heute schon viele tolle Fragen gestellt! '
      'Dein tägliches KI-Limit ($_dailyLimit Anfragen) ist erreicht. '
      'Morgen geht\'s weiter — ruh dich aus! 💜';

  /// Short status for UI badges
  static String get statusText => '$_todayCount/$_dailyLimit heute';

  // ─── Private ──────────────────────────────────────────────────────────────

  static void _ensureTodayReset() {
    final today = _todayString();
    if (_todayDate != today) {
      _todayCount = 0;
      _todayDate = today;
    }
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
