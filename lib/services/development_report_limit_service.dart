import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/services/premium_service.dart';

/// Verwaltet das Limit für KI-Entwicklungsberichte.
///
/// Free: 1 KI-Bericht pro Jahr pro Account.
/// Premium: Unbegrenzt.
///
/// Tracked über Firebase UID + SharedPreferences.
class DevelopmentReportLimitService {
  static final DevelopmentReportLimitService instance =
      DevelopmentReportLimitService._();
  DevelopmentReportLimitService._();

  static const String _lastReportKey = 'dev_report_limit.last_report_at';
  static const String _reportCountKey = 'dev_report_limit.count_this_year';
  static const String _yearKey = 'dev_report_limit.year';

  DateTime? _lastReportAt;
  int _reportCountThisYear = 0;
  int _trackedYear = 0;

  /// Maximale kostenlose Berichte pro Jahr
  static const int freeReportsPerYear = 1;

  /// Wann wurde der letzte Bericht erstellt?
  DateTime? get lastReportAt => _lastReportAt;

  /// Wie viele Berichte wurden dieses Jahr erstellt?
  int get reportCountThisYear => _reportCountThisYear;

  /// Ist das Limit aktiv? (Nur wenn Monetarisierung an + nicht Premium)
  bool get isLimitActive =>
      MonetizationConfig.enabled && !PremiumService.instance.isPremium;

  /// Hat der Nutzer sein Limit erreicht?
  bool get isLimitReached =>
      isLimitActive && _reportCountThisYear >= freeReportsPerYear;

  /// Kann der Nutzer einen Bericht erstellen?
  bool get canCreateReport => !isLimitActive || !isLimitReached;

  /// Verbleibende kostenlose Berichte dieses Jahr
  int get remaining {
    if (!isLimitActive) return 999;
    final r = freeReportsPerYear - _reportCountThisYear;
    return r > 0 ? r : 0;
  }

  /// Wann ist der nächste kostenlose Bericht verfügbar?
  String get nextFreeReportInfo {
    if (!isLimitReached) return '';
    final nextYear = _trackedYear + 1;
    return 'Nächster kostenloser Bericht: ab Januar $nextYear';
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final key = uid.isNotEmpty ? '$_lastReportKey.$uid' : _lastReportKey;
    final countKey = uid.isNotEmpty ? '$_reportCountKey.$uid' : _reportCountKey;
    final yearKey = uid.isNotEmpty ? '$_yearKey.$uid' : _yearKey;

    final lastMillis = prefs.getInt(key);
    if (lastMillis != null) {
      _lastReportAt = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    }
    _reportCountThisYear = prefs.getInt(countKey) ?? 0;
    _trackedYear = prefs.getInt(yearKey) ?? 0;

    // Jahreswechsel → Reset
    _checkYearReset();

    debugPrint('DevelopmentReportLimitService: count=$_reportCountThisYear, '
        'year=$_trackedYear, canCreate=$canCreateReport');
  }

  // ─── Report-Tracking ──────────────────────────────────────────────────────

  /// Registriere einen erstellten KI-Bericht. Returns true wenn erlaubt.
  Future<bool> recordReportCreated() async {
    if (isLimitActive) {
      _checkYearReset();
      if (_reportCountThisYear >= freeReportsPerYear) {
        return false;
      }
    }

    _reportCountThisYear++;
    _lastReportAt = DateTime.now();
    await _persist();
    debugPrint('DevelopmentReportLimitService: Report recorded '
        '($_reportCountThisYear/$freeReportsPerYear)');
    return true;
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  void _checkYearReset() {
    final currentYear = DateTime.now().year;
    if (_trackedYear != currentYear) {
      _reportCountThisYear = 0;
      _trackedYear = currentYear;
      _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final key = uid.isNotEmpty ? '$_lastReportKey.$uid' : _lastReportKey;
    final countKey = uid.isNotEmpty ? '$_reportCountKey.$uid' : _reportCountKey;
    final yearKey = uid.isNotEmpty ? '$_yearKey.$uid' : _yearKey;

    if (_lastReportAt != null) {
      await prefs.setInt(key, _lastReportAt!.millisecondsSinceEpoch);
    }
    await prefs.setInt(countKey, _reportCountThisYear);
    await prefs.setInt(yearKey, _trackedYear);
  }
}
