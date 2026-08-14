import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A public holiday entry
class PublicHoliday {
  final DateTime date;
  final String name;
  final String country; // DE, AT, CH, TR, GB
  final bool isNational; // true = ganzes Land, false = regional

  const PublicHoliday({
    required this.date,
    required this.name,
    required this.country,
    this.isNational = true,
  });
}

/// A school holiday period
class SchoolHolidayPeriod {
  final DateTime start;
  final DateTime end;
  final String name;
  final String region; // z.B. "NRW", "Bayern", "Berlin"
  final String country;

  const SchoolHolidayPeriod({
    required this.start,
    required this.end,
    required this.name,
    required this.region,
    required this.country,
  });

  bool containsDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }
}

class HolidayService {
  static const _countryKey = 'holiday.country';
  static const _regionKey = 'holiday.region';

  static String _country = 'DE';
  static String _region = 'NRW';

  static String get country => _country;
  static String get region => _region;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _country = prefs.getString(_countryKey) ?? 'DE';
    _region = prefs.getString(_regionKey) ?? 'NRW';
  }

  static Future<void> setCountry(String c) async {
    _country = c;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKey, c);
  }

  static Future<void> setRegion(String r) async {
    _region = r;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionKey, r);
  }

  /// Get public holidays for a given month
  static List<PublicHoliday> getHolidaysForMonth(int year, int month) {
    return _allHolidays
        .where((h) =>
            h.country == _country &&
            h.date.year == year &&
            h.date.month == month)
        .toList();
  }

  /// Get public holiday for a specific day (or null)
  static PublicHoliday? getHolidayForDay(DateTime day) {
    try {
      return _allHolidays.firstWhere((h) =>
          h.country == _country &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day);
    } catch (_) {
      return null;
    }
  }

  /// Get school holiday periods that overlap with a given month
  static List<SchoolHolidayPeriod> getSchoolHolidaysForMonth(
      int year, int month) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    return _allSchoolHolidays
        .where((p) =>
            p.country == _country &&
            p.region == _region &&
            !p.end.isBefore(monthStart) &&
            !p.start.isAfter(monthEnd))
        .toList();
  }

  /// Check if a day is in school holidays
  static SchoolHolidayPeriod? getSchoolHolidayForDay(DateTime day) {
    try {
      return _allSchoolHolidays.firstWhere((p) =>
          p.country == _country && p.region == _region && p.containsDay(day));
    } catch (_) {
      return null;
    }
  }

  /// Available countries
  static const List<Map<String, String>> availableCountries = [
    {'code': 'DE', 'name': 'Deutschland', 'flag': '\u{1F1E9}\u{1F1EA}'},
    {'code': 'AT', 'name': 'Österreich', 'flag': '\u{1F1E6}\u{1F1F9}'},
    {'code': 'CH', 'name': 'Schweiz', 'flag': '\u{1F1E8}\u{1F1ED}'},
    {'code': 'TR', 'name': 'Türkei', 'flag': '\u{1F1F9}\u{1F1F7}'},
    {'code': 'GB', 'name': 'Großbritannien', 'flag': '\u{1F1EC}\u{1F1E7}'},
  ];

  /// Available regions per country
  static List<Map<String, String>> getRegionsForCountry(String country) {
    switch (country) {
      case 'DE':
        return _deRegions;
      case 'AT':
        return [
          {'code': 'Wien', 'name': 'Wien'},
          {'code': 'NÖ', 'name': 'Niederösterreich'},
          {'code': 'OÖ', 'name': 'Oberösterreich'},
          {'code': 'Sbg', 'name': 'Salzburg'},
          {'code': 'Tirol', 'name': 'Tirol'},
          {'code': 'Vbg', 'name': 'Vorarlberg'},
          {'code': 'Stmk', 'name': 'Steiermark'},
          {'code': 'Ktn', 'name': 'Kärnten'},
          {'code': 'Bgld', 'name': 'Burgenland'},
        ];
      case 'CH':
        return [
          {'code': 'ZH', 'name': 'Zürich'},
          {'code': 'BE', 'name': 'Bern'},
          {'code': 'BS', 'name': 'Basel-Stadt'},
          {'code': 'AG', 'name': 'Aargau'},
          {'code': 'SG', 'name': 'St. Gallen'},
        ];
      case 'TR':
        return [
          {'code': 'TR', 'name': 'Türkei (national)'},
        ];
      case 'GB':
        return [
          {'code': 'ENG', 'name': 'England'},
          {'code': 'SCO', 'name': 'Scotland'},
          {'code': 'WAL', 'name': 'Wales'},
        ];
      default:
        return [];
    }
  }

  static const _deRegions = [
    {'code': 'NRW', 'name': 'Nordrhein-Westfalen'},
    {'code': 'BY', 'name': 'Bayern'},
    {'code': 'BW', 'name': 'Baden-Württemberg'},
    {'code': 'NI', 'name': 'Niedersachsen'},
    {'code': 'HE', 'name': 'Hessen'},
    {'code': 'SN', 'name': 'Sachsen'},
    {'code': 'RP', 'name': 'Rheinland-Pfalz'},
    {'code': 'BE', 'name': 'Berlin'},
    {'code': 'HH', 'name': 'Hamburg'},
    {'code': 'SH', 'name': 'Schleswig-Holstein'},
    {'code': 'BB', 'name': 'Brandenburg'},
    {'code': 'TH', 'name': 'Thüringen'},
    {'code': 'SA', 'name': 'Sachsen-Anhalt'},
    {'code': 'MV', 'name': 'Mecklenburg-Vorpommern'},
    {'code': 'HB', 'name': 'Bremen'},
    {'code': 'SL', 'name': 'Saarland'},
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC HOLIDAYS DATA 2026-2027
  // ═══════════════════════════════════════════════════════════════════════════

  static final List<PublicHoliday> _allHolidays = [
    // ─── DEUTSCHLAND 2026 ─────────────────────────────────────────────
    PublicHoliday(date: DateTime(2026, 1, 1), name: 'Neujahr', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 4, 3), name: 'Karfreitag', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 4, 6), name: 'Ostermontag', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 5, 1), name: 'Tag der Arbeit', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 5, 14), name: 'Christi Himmelfahrt', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 5, 25), name: 'Pfingstmontag', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 10, 3), name: 'Tag der Deutschen Einheit', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 12, 25), name: '1. Weihnachtstag', country: 'DE'),
    PublicHoliday(date: DateTime(2026, 12, 26), name: '2. Weihnachtstag', country: 'DE'),
    // 2027
    PublicHoliday(date: DateTime(2027, 1, 1), name: 'Neujahr', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 3, 26), name: 'Karfreitag', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 3, 29), name: 'Ostermontag', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 5, 1), name: 'Tag der Arbeit', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 5, 6), name: 'Christi Himmelfahrt', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 5, 17), name: 'Pfingstmontag', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 10, 3), name: 'Tag der Deutschen Einheit', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 12, 25), name: '1. Weihnachtstag', country: 'DE'),
    PublicHoliday(date: DateTime(2027, 12, 26), name: '2. Weihnachtstag', country: 'DE'),

    // ─── ÖSTERREICH 2026 ──────────────────────────────────────────────
    PublicHoliday(date: DateTime(2026, 1, 1), name: 'Neujahr', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 1, 6), name: 'Heilige Drei Könige', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 4, 6), name: 'Ostermontag', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 5, 1), name: 'Staatsfeiertag', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 5, 14), name: 'Christi Himmelfahrt', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 5, 25), name: 'Pfingstmontag', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 6, 4), name: 'Fronleichnam', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 8, 15), name: 'Mariä Himmelfahrt', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 10, 26), name: 'Nationalfeiertag', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 11, 1), name: 'Allerheiligen', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 12, 8), name: 'Mariä Empfängnis', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 12, 25), name: 'Christtag', country: 'AT'),
    PublicHoliday(date: DateTime(2026, 12, 26), name: 'Stefanitag', country: 'AT'),

    // ─── SCHWEIZ 2026 ─────────────────────────────────────────────────
    PublicHoliday(date: DateTime(2026, 1, 1), name: 'Neujahr', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 4, 3), name: 'Karfreitag', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 4, 6), name: 'Ostermontag', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 5, 14), name: 'Auffahrt', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 5, 25), name: 'Pfingstmontag', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 8, 1), name: 'Bundesfeiertag', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 12, 25), name: 'Weihnachten', country: 'CH'),
    PublicHoliday(date: DateTime(2026, 12, 26), name: 'Stephanstag', country: 'CH'),

    // ─── TÜRKEI 2026 ──────────────────────────────────────────────────
    PublicHoliday(date: DateTime(2026, 1, 1), name: 'Yılbaşı', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 4, 23), name: 'Ulusal Egemenlik ve Çocuk Bayramı', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 5, 1), name: 'Emek ve Dayanışma Günü', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 5, 19), name: 'Atatürk\'ü Anma Gençlik ve Spor Bayramı', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 6, 16), name: 'Ramazan Bayramı (1. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 6, 17), name: 'Ramazan Bayramı (2. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 6, 18), name: 'Ramazan Bayramı (3. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 7, 15), name: 'Demokrasi ve Millî Birlik Günü', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 8, 23), name: 'Kurban Bayramı (1. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 8, 24), name: 'Kurban Bayramı (2. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 8, 25), name: 'Kurban Bayramı (3. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 8, 26), name: 'Kurban Bayramı (4. Tag)', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 8, 30), name: 'Zafer Bayramı', country: 'TR'),
    PublicHoliday(date: DateTime(2026, 10, 29), name: 'Cumhuriyet Bayramı', country: 'TR'),

    // ─── GROßBRITANNIEN 2026 ─────────────────────────────────────────
    PublicHoliday(date: DateTime(2026, 1, 1), name: 'New Year\'s Day', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 4, 3), name: 'Good Friday', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 4, 6), name: 'Easter Monday', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 5, 4), name: 'Early May Bank Holiday', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 5, 25), name: 'Spring Bank Holiday', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 8, 31), name: 'Summer Bank Holiday', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 12, 25), name: 'Christmas Day', country: 'GB'),
    PublicHoliday(date: DateTime(2026, 12, 28), name: 'Boxing Day (substitute)', country: 'GB'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SCHOOL HOLIDAYS DATA 2026 (Germany — main Bundesländer)
  // ═══════════════════════════════════════════════════════════════════════════

  static final List<SchoolHolidayPeriod> _allSchoolHolidays = [
    // ─── NRW 2026 ─────────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 6), name: 'Weihnachtsferien', region: 'NRW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 3, 30), end: DateTime(2026, 4, 11), name: 'Osterferien', region: 'NRW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 26), end: DateTime(2026, 5, 26), name: 'Pfingstferien', region: 'NRW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 6, 29), end: DateTime(2026, 8, 11), name: 'Sommerferien', region: 'NRW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 12), end: DateTime(2026, 10, 24), name: 'Herbstferien', region: 'NRW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 23), end: DateTime(2027, 1, 6), name: 'Weihnachtsferien', region: 'NRW', country: 'DE'),

    // ─── Bayern 2026 ──────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 5), name: 'Weihnachtsferien', region: 'BY', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 2, 16), end: DateTime(2026, 2, 20), name: 'Winterferien', region: 'BY', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 3, 30), end: DateTime(2026, 4, 11), name: 'Osterferien', region: 'BY', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 26), end: DateTime(2026, 6, 5), name: 'Pfingstferien', region: 'BY', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 30), end: DateTime(2026, 9, 14), name: 'Sommerferien', region: 'BY', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 11, 2), end: DateTime(2026, 11, 6), name: 'Herbstferien', region: 'BY', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 23), end: DateTime(2027, 1, 7), name: 'Weihnachtsferien', region: 'BY', country: 'DE'),

    // ─── Baden-Württemberg 2026 ───────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 5), name: 'Weihnachtsferien', region: 'BW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 4, 2), end: DateTime(2026, 4, 11), name: 'Osterferien', region: 'BW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 26), end: DateTime(2026, 6, 6), name: 'Pfingstferien', region: 'BW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 30), end: DateTime(2026, 9, 12), name: 'Sommerferien', region: 'BW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 26), end: DateTime(2026, 10, 31), name: 'Herbstferien', region: 'BW', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 23), end: DateTime(2027, 1, 9), name: 'Weihnachtsferien', region: 'BW', country: 'DE'),

    // ─── Berlin 2026 ──────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 3), name: 'Weihnachtsferien', region: 'BE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 2, 2), end: DateTime(2026, 2, 7), name: 'Winterferien', region: 'BE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 3, 30), end: DateTime(2026, 4, 11), name: 'Osterferien', region: 'BE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 15), end: DateTime(2026, 5, 15), name: 'Pfingstferien', region: 'BE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 9), end: DateTime(2026, 8, 22), name: 'Sommerferien', region: 'BE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 31), name: 'Herbstferien', region: 'BE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 23), end: DateTime(2027, 1, 2), name: 'Weihnachtsferien', region: 'BE', country: 'DE'),

    // ─── Hamburg 2026 ─────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 2), name: 'Weihnachtsferien', region: 'HH', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 2, 2), end: DateTime(2026, 2, 6), name: 'Winterferien', region: 'HH', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 3, 2), end: DateTime(2026, 3, 13), name: 'Osterferien', region: 'HH', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 11), end: DateTime(2026, 5, 15), name: 'Pfingstferien', region: 'HH', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 6, 25), end: DateTime(2026, 8, 5), name: 'Sommerferien', region: 'HH', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 30), name: 'Herbstferien', region: 'HH', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 21), end: DateTime(2027, 1, 2), name: 'Weihnachtsferien', region: 'HH', country: 'DE'),

    // ─── Hessen 2026 ──────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 10), name: 'Weihnachtsferien', region: 'HE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 4, 6), end: DateTime(2026, 4, 18), name: 'Osterferien', region: 'HE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 6), end: DateTime(2026, 8, 14), name: 'Sommerferien', region: 'HE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 31), name: 'Herbstferien', region: 'HE', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 23), end: DateTime(2027, 1, 9), name: 'Weihnachtsferien', region: 'HE', country: 'DE'),

    // ─── Niedersachsen 2026 ───────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 5), name: 'Weihnachtsferien', region: 'NI', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 2, 2), end: DateTime(2026, 2, 3), name: 'Winterferien', region: 'NI', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 3, 23), end: DateTime(2026, 4, 7), name: 'Osterferien', region: 'NI', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 14), end: DateTime(2026, 5, 26), name: 'Pfingstferien', region: 'NI', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 2), end: DateTime(2026, 8, 12), name: 'Sommerferien', region: 'NI', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 31), name: 'Herbstferien', region: 'NI', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 23), end: DateTime(2027, 1, 6), name: 'Weihnachtsferien', region: 'NI', country: 'DE'),

    // ─── Sachsen 2026 ─────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 2), end: DateTime(2026, 1, 3), name: 'Weihnachtsferien', region: 'SN', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 2, 9), end: DateTime(2026, 2, 21), name: 'Winterferien', region: 'SN', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 4, 3), end: DateTime(2026, 4, 11), name: 'Osterferien', region: 'SN', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 14), end: DateTime(2026, 5, 14), name: 'Pfingstferien', region: 'SN', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 6, 27), end: DateTime(2026, 8, 8), name: 'Sommerferien', region: 'SN', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 12), end: DateTime(2026, 10, 24), name: 'Herbstferien', region: 'SN', country: 'DE'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 21), end: DateTime(2027, 1, 2), name: 'Weihnachtsferien', region: 'SN', country: 'DE'),

    // ─── Österreich (Wien) 2026 ───────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 2, 2), end: DateTime(2026, 2, 8), name: 'Semesterferien', region: 'Wien', country: 'AT'),
    SchoolHolidayPeriod(start: DateTime(2026, 3, 28), end: DateTime(2026, 4, 7), name: 'Osterferien', region: 'Wien', country: 'AT'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 23), end: DateTime(2026, 5, 26), name: 'Pfingstferien', region: 'Wien', country: 'AT'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 4), end: DateTime(2026, 9, 6), name: 'Sommerferien', region: 'Wien', country: 'AT'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 26), end: DateTime(2026, 11, 2), name: 'Herbstferien', region: 'Wien', country: 'AT'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 24), end: DateTime(2027, 1, 6), name: 'Weihnachtsferien', region: 'Wien', country: 'AT'),

    // ─── GB (England) 2026 ────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 2, 16), end: DateTime(2026, 2, 20), name: 'Half Term', region: 'ENG', country: 'GB'),
    SchoolHolidayPeriod(start: DateTime(2026, 4, 2), end: DateTime(2026, 4, 17), name: 'Easter Holidays', region: 'ENG', country: 'GB'),
    SchoolHolidayPeriod(start: DateTime(2026, 5, 25), end: DateTime(2026, 5, 29), name: 'Half Term', region: 'ENG', country: 'GB'),
    SchoolHolidayPeriod(start: DateTime(2026, 7, 22), end: DateTime(2026, 9, 2), name: 'Summer Holidays', region: 'ENG', country: 'GB'),
    SchoolHolidayPeriod(start: DateTime(2026, 10, 26), end: DateTime(2026, 10, 30), name: 'Half Term', region: 'ENG', country: 'GB'),
    SchoolHolidayPeriod(start: DateTime(2026, 12, 21), end: DateTime(2027, 1, 2), name: 'Christmas Holidays', region: 'ENG', country: 'GB'),

    // ─── Türkei 2026 ─────────────────────────────────────────────────
    SchoolHolidayPeriod(start: DateTime(2026, 1, 26), end: DateTime(2026, 2, 7), name: 'Yarıyıl Tatili', region: 'TR', country: 'TR'),
    SchoolHolidayPeriod(start: DateTime(2026, 6, 19), end: DateTime(2026, 9, 14), name: 'Yaz Tatili', region: 'TR', country: 'TR'),
  ];
}
