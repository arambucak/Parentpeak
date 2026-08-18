import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/services/premium_service.dart';

/// Verwaltet das Anbieter-Paket (Theater, Vereine, Familienzentren).
///
/// Free: 3 Events pro Monat erstellen.
/// Anbieter-Paket (9,99€/Monat): Unbegrenzt Events + Stats.
///
/// Nutzer markieren sich selbst als "Anbieter" im Profil.
class ProviderPackageService {
  static final ProviderPackageService instance = ProviderPackageService._();
  ProviderPackageService._();

  static const String _isProviderKey = 'provider.is_provider';
  static const String _eventCountKey = 'provider.event_count_month';
  static const String _monthKey = 'provider.current_month';

  bool _isProvider = false;
  int _eventsThisMonth = 0;
  int _currentMonth = 0;

  /// Ist der Nutzer als Anbieter markiert?
  bool get isProvider => _isProvider;

  /// Anzahl erstellter Events diesen Monat
  int get eventsThisMonth => _eventsThisMonth;

  /// Maximum Events/Monat (Free-Anbieter)
  int get monthlyLimit => MonetizationConfig.freeProviderEventsPerMonth;

  /// Verbleibende kostenlose Events
  int get remaining {
    if (!isLimitActive) return 999;
    final r = monthlyLimit - _eventsThisMonth;
    return r > 0 ? r : 0;
  }

  /// Ist das Anbieter-Limit aktiv?
  bool get isLimitActive =>
      MonetizationConfig.enabled &&
      MonetizationConfig.providerPackageEnabled &&
      _isProvider &&
      !PremiumService.instance.isProvider;

  /// Hat der Anbieter sein Free-Limit erreicht?
  bool get isLimitReached => isLimitActive && _eventsThisMonth >= monthlyLimit;

  /// Kann der Anbieter noch ein Event erstellen?
  bool get canCreateEvent => !isLimitActive || _eventsThisMonth < monthlyLimit;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isProvider = prefs.getBool(_isProviderKey) ?? false;
    _eventsThisMonth = prefs.getInt(_eventCountKey) ?? 0;
    _currentMonth = prefs.getInt(_monthKey) ?? 0;

    _checkMonthReset();

    debugPrint('ProviderPackageService: isProvider=$_isProvider, '
        'eventsThisMonth=$_eventsThisMonth');
  }

  // ─── Provider-Status ──────────────────────────────────────────────────────

  /// Markiere Nutzer als Anbieter (z.B. aus Profil-Einstellungen)
  Future<void> setProviderStatus(bool isProvider) async {
    _isProvider = isProvider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProviderKey, isProvider);
  }

  // ─── Event-Tracking ───────────────────────────────────────────────────────

  /// Registriere ein erstelltes Event. Returns true wenn erlaubt.
  Future<bool> recordEventCreated() async {
    if (!isLimitActive) return true;

    _checkMonthReset();

    if (_eventsThisMonth >= monthlyLimit) {
      return false;
    }

    _eventsThisMonth++;
    await _persist();
    debugPrint('ProviderPackageService: Event erstellt '
        '($_eventsThisMonth/$monthlyLimit)');
    return true;
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  void _checkMonthReset() {
    final now = DateTime.now();
    final currentYearMonth = now.year * 12 + now.month;

    if (_currentMonth != currentYearMonth) {
      _eventsThisMonth = 0;
      _currentMonth = currentYearMonth;
      _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eventCountKey, _eventsThisMonth);
    await prefs.setInt(_monthKey, _currentMonth);
  }
}
