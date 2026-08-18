import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/services/premium_service.dart';

/// Verwaltet das Events-Limit für Free-Nutzer.
///
/// Free: 3 Event-Details pro Woche ansehen.
/// Premium: Unbegrenzt.
///
/// Woche = Montag 00:00 bis Sonntag 23:59 (Reset jeden Montag).
class EventsLimitService {
  static final EventsLimitService instance = EventsLimitService._();
  EventsLimitService._();

  static const String _viewCountKey = 'events_limit.view_count';
  static const String _weekStartKey = 'events_limit.week_start';

  int _viewCount = 0;
  DateTime? _weekStart;

  /// Anzahl der diese Woche angesehenen Event-Details
  int get viewCount => _viewCount;

  /// Maximum pro Woche (Free)
  int get weeklyLimit => MonetizationConfig.freeEventsPerWeek;

  /// Verbleibende Views diese Woche
  int get remaining {
    if (!isLimitActive) return 999;
    final r = weeklyLimit - _viewCount;
    return r > 0 ? r : 0;
  }

  /// Ist das Limit aktiv? (Nur wenn Monetarisierung an + nicht Premium)
  bool get isLimitActive => PremiumService.instance.shouldLimitEvents;

  /// Hat der Nutzer sein Limit erreicht?
  bool get isLimitReached => isLimitActive && _viewCount >= weeklyLimit;

  /// Kann der Nutzer noch ein Event ansehen?
  bool get canViewEvent => !isLimitActive || _viewCount < weeklyLimit;

  /// Initialisiere aus SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _viewCount = prefs.getInt(_viewCountKey) ?? 0;

    final weekStartMillis = prefs.getInt(_weekStartKey);
    if (weekStartMillis != null) {
      _weekStart = DateTime.fromMillisecondsSinceEpoch(weekStartMillis);
    }

    // Prüfe ob neue Woche → Reset
    _checkWeekReset();

    debugPrint('EventsLimitService: viewCount=$_viewCount, '
        'remaining=$remaining, limitActive=$isLimitActive');
  }

  /// Registriere einen Event-Detail-View. Returns true wenn erlaubt.
  Future<bool> recordEventView() async {
    if (!isLimitActive) return true;

    _checkWeekReset();

    if (_viewCount >= weeklyLimit) {
      return false; // Limit erreicht
    }

    _viewCount++;
    await _persist();
    debugPrint('EventsLimitService: View recorded ($_viewCount/$weeklyLimit)');
    return true;
  }

  /// Reset für neue Woche (wird automatisch geprüft)
  void _checkWeekReset() {
    final now = DateTime.now();
    final currentWeekStart = _getWeekStart(now);

    if (_weekStart == null || currentWeekStart.isAfter(_weekStart!)) {
      _viewCount = 0;
      _weekStart = currentWeekStart;
      _persist();
    }
  }

  /// Montag 00:00 der aktuellen Woche
  DateTime _getWeekStart(DateTime date) {
    final daysToSubtract = date.weekday - 1; // Montag = 1
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_viewCountKey, _viewCount);
    if (_weekStart != null) {
      await prefs.setInt(_weekStartKey, _weekStart!.millisecondsSinceEpoch);
    }
  }
}
