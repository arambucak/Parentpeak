import 'package:intl/date_symbol_data_local.dart';

/// Reine, UI-unabhängige Kalender-Logik.
///
/// Hier liegen die testbaren Funktionen für Natural-Language-Parsing,
/// Recurrence-Expansion, Monats-Grid-Berechnung und die Locale-Zuordnung
/// für `intl`. Keine Flutter-Abhängigkeiten, damit alles im Unit-Test
/// ohne Widget-Binding läuft.
class CalendarLogic {
  const CalendarLogic._();

  // ───────────────────────────────────────────────────────────────────────
  // Locale / i18n
  // ───────────────────────────────────────────────────────────────────────

  /// Mapt einen App-Sprachcode auf einen von `intl` unterstützten
  /// `DateFormat`-Locale-Tag. Sprachen ohne eigene intl-Daten (z.B. Kurmancî
  /// `ku`, Soranî `ckb`) fallen auf eine passende verfügbare Locale zurück.
  static String localeTag(String appLanguageCode) {
    switch (appLanguageCode) {
      case 'ku': // Kurmancî — keine intl-Daten, nächstliegend türkisch/englisch
        return 'en';
      case 'ckb': // Soranî — arabische Schrift
        return 'ar';
      default:
        return appLanguageCode;
    }
  }

  static bool _dateFormattingInitialized = false;

  /// Initialisiert die `intl`-Locale-Daten einmalig. Muss vor der ersten
  /// Verwendung lokalisierter `DateFormat`-Instanzen aufgerufen werden.
  static Future<void> ensureDateFormattingInitialized() async {
    if (_dateFormattingInitialized) return;
    await initializeDateFormatting();
    _dateFormattingInitialized = true;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Monats-Grid
  // ───────────────────────────────────────────────────────────────────────

  /// Liefert alle Tage, die im Monats-Grid gezeigt werden: führende Tage des
  /// Vormonats, alle Tage des Monats und nachlaufende Tage des Folgemonats,
  /// sodass das Grid immer mit vollständigen 7er-Wochenzeilen (Montag–Sonntag)
  /// endet.
  ///
  /// Schaltjahr- und Jahreswechsel-sicher, da ausschließlich `DateTime`
  /// genutzt wird (Dart normalisiert Monats-/Jahresüberläufe korrekt).
  static List<DateTime> daysInMonthGrid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysBefore = (first.weekday + 6) % 7; // Montag = 0 … Sonntag = 6
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final days = <DateTime>[];
    for (int i = 0; i < daysBefore; i++) {
      days.add(DateTime(month.year, month.month, 1 - (daysBefore - i)));
    }
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    // Auf volle Wochen (Vielfaches von 7) mit Folgemonats-Tagen auffüllen.
    final remainder = days.length % 7;
    if (remainder != 0) {
      final trailing = 7 - remainder;
      for (int i = 1; i <= trailing; i++) {
        days.add(DateTime(month.year, month.month, daysInMonth + i));
      }
    }
    return days;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ───────────────────────────────────────────────────────────────────────
  // Recurrence-Expansion
  // ───────────────────────────────────────────────────────────────────────

  /// Berechnet die Startzeitpunkte einer Terminserie (inkl. erstem Termin).
  ///
  /// `monthly`/`yearly` werden kalendergenau fortgeschrieben (nicht via 30-
  /// bzw. 365-Tage-Approximation), sodass Schalttage und Jahreswechsel korrekt
  /// behandelt werden. Fällt ein monatlicher Termin auf einen nicht
  /// existierenden Tag (z.B. 31. im Februar), wird auf den letzten gültigen
  /// Tag des Monats geklemmt.
  ///
  /// [recurrence] akzeptiert die deutschen UI-Werte sowie englische Aliase.
  static List<DateTime> expandRecurrenceStarts({
    required DateTime start,
    required String recurrence,
    String endMode = 'Kein Ende',
    DateTime? endDate,
    int? count,
    int openEndedLimit = 12,
  }) {
    final result = <DateTime>[start];
    final kind = _normalizeRecurrence(recurrence);
    if (kind == _Recurrence.once) return result;

    final useCount = endMode.contains('Termine') || endMode.contains('occur');
    final useDate = endMode == 'Datum wählen' || endMode == 'Until date';
    final maxOccurrences = useCount ? (count ?? 2) : null;

    int i = 1;
    while (true) {
      if (maxOccurrences != null && result.length >= maxOccurrences) break;
      final next = _advance(start, kind, i);
      if (useDate && endDate != null && next.isAfter(endDate)) break;
      result.add(next);
      i++;
      if (!useCount && !useDate && result.length >= openEndedLimit) break;
      // Harte Obergrenze als Sicherheitsnetz gegen Endlosschleifen.
      if (result.length >= 1000) break;
    }
    return result;
  }

  static DateTime _advance(DateTime start, _Recurrence kind, int step) {
    switch (kind) {
      case _Recurrence.daily:
        return start.add(Duration(days: step));
      case _Recurrence.weekly:
        return start.add(Duration(days: 7 * step));
      case _Recurrence.monthly:
        final targetMonth = start.month + step;
        final year = start.year + ((targetMonth - 1) ~/ 12);
        final month = ((targetMonth - 1) % 12) + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        final day = start.day > lastDay ? lastDay : start.day;
        return DateTime(
            year, month, day, start.hour, start.minute, start.second);
      case _Recurrence.yearly:
        final year = start.year + step;
        // 29. Februar auf 28. klemmen in Nicht-Schaltjahren.
        final lastDay = DateTime(year, start.month + 1, 0).day;
        final day = start.day > lastDay ? lastDay : start.day;
        return DateTime(year, start.month, day, start.hour, start.minute,
            start.second);
      case _Recurrence.once:
        return start;
    }
  }

  static _Recurrence _normalizeRecurrence(String value) {
    switch (value) {
      case 'Täglich':
      case 'Daily':
        return _Recurrence.daily;
      case 'Wöchentlich':
      case 'Weekly':
        return _Recurrence.weekly;
      case 'Monatlich':
      case 'Monthly':
        return _Recurrence.monthly;
      case 'Jährlich':
      case 'Yearly':
        return _Recurrence.yearly;
      default:
        return _Recurrence.once;
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Natural-Language-Parsing (Quick-Add)
  // ───────────────────────────────────────────────────────────────────────

  static const Map<String, int> _dayMap = {
    'montag': 1,
    'mo': 1,
    'mon': 1,
    'dienstag': 2,
    'di': 2,
    'tue': 2,
    'tues': 2,
    'mittwoch': 3,
    'mi': 3,
    'wed': 3,
    'donnerstag': 4,
    'do': 4,
    'thu': 4,
    'thur': 4,
    'freitag': 5,
    'fr': 5,
    'fri': 5,
    'samstag': 6,
    'sa': 6,
    'sat': 6,
    'sonntag': 7,
    'so': 7,
    'sun': 7,
  };

  static const List<String> _birthdayKeywords = [
    'geburtstag',
    'birthday',
    'bday',
    'doğum günü',
    'dogum gunu',
    'rojbûn',
    'rojbun',
  ];

  /// Parst eine Freitext-Schnelleingabe wie `Arzt Mo 10:00` oder
  /// `Oma Geburtstag 25.12.`.
  ///
  /// Robust gegen ungültige Eingaben: Uhrzeiten außerhalb 00:00–23:59 und
  /// unplausible Datumsangaben (z.B. `31.02.`) werden verworfen statt still
  /// in einen falschen Tag normalisiert. Leere/zu kurze Eingaben liefern ein
  /// Ergebnis mit `isValid == false`.
  static QuickAddResult parseQuickInput(
    String input, {
    required DateTime selectedDay,
    required DateTime now,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return QuickAddResult.invalid('empty');
    }

    final lower = trimmed.toLowerCase();
    String working = trimmed;

    bool isBirthday = false;
    String? person;
    for (final kw in _birthdayKeywords) {
      if (lower.contains(kw)) {
        isBirthday = true;
        person = birthdayPersonKey;
        break;
      }
    }

    // 1) Uhrzeit: "10:00" / "14:30" bevorzugt, sonst "10 Uhr".
    int hour = 10;
    int minute = 0;
    bool timeFound = false;

    final timeColon = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(working);
    final timeUhr = RegExp(r'\b(\d{1,2})\s*[Uu]hr\b').firstMatch(working);
    if (timeColon != null) {
      final h = int.parse(timeColon.group(1)!);
      final m = int.parse(timeColon.group(2)!);
      if (h > 23 || m > 59) {
        return QuickAddResult.invalid('time_out_of_range');
      }
      hour = h;
      minute = m;
      timeFound = true;
      working = working.replaceFirst(timeColon.group(0)!, ' ');
    } else if (timeUhr != null) {
      final h = int.parse(timeUhr.group(1)!);
      if (h > 23) {
        return QuickAddResult.invalid('time_out_of_range');
      }
      hour = h;
      minute = 0;
      timeFound = true;
      working = working.replaceFirst(timeUhr.group(0)!, ' ');
    }

    // 2) Datum: "25.12." oder "25.12.2026" hat Vorrang vor Wochentag.
    DateTime? targetDate;
    final dateMatch =
        RegExp(r'\b(\d{1,2})\.(\d{1,2})\.(\d{4})?').firstMatch(working);
    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final year =
          dateMatch.group(3) != null ? int.parse(dateMatch.group(3)!) : now.year;
      if (!_isPlausibleDate(year, month, day)) {
        return QuickAddResult.invalid('date_invalid');
      }
      targetDate = DateTime(year, month, day);
      working = working.replaceFirst(dateMatch.group(0)!, ' ');
    }

    // 3) Wochentag (nur wenn kein explizites Datum): nächstes Vorkommen.
    if (targetDate == null) {
      for (final entry in _dayMap.entries) {
        final pattern = RegExp('\\b${entry.key}\\b', caseSensitive: false);
        if (pattern.hasMatch(working)) {
          final targetWeekday = entry.value;
          int daysAhead = targetWeekday - now.weekday;
          if (daysAhead <= 0) daysAhead += 7;
          targetDate =
              DateTime(now.year, now.month, now.day).add(Duration(days: daysAhead));
          working = working.replaceFirst(pattern, ' ');
          break;
        }
      }
    }

    targetDate ??= DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    // 4) Titel bereinigen.
    var title = working.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Alleinstehende Satzzeichen/Reste entfernen.
    title = title.replaceAll(RegExp(r'^[\s\.,;:-]+|[\s\.,;:-]+$'), '').trim();
    if (title.isEmpty) {
      // Falls nach dem Entfernen aller Tokens nichts bleibt, erstes Wort nehmen.
      final firstWord = trimmed.split(RegExp(r'\s+')).first;
      title = firstWord.replaceAll(RegExp(r'[\d:\.]+'), '').trim();
      if (title.isEmpty) {
        return QuickAddResult.invalid('no_title');
      }
    }

    final dateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    return QuickAddResult(
      isValid: true,
      title: title,
      dateTime: dateTime,
      person: person,
      isBirthday: isBirthday,
      timeExplicit: timeFound,
    );
  }

  /// Interner Schlüssel für die reservierte Geburtstags-Person.
  static const String birthdayPersonKey = '\u{1F382} Geburtstag';

  static bool _isPlausibleDate(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1) return false;
    if (year < 1970 || year > 3000) return false;
    final lastDay = DateTime(year, month + 1, 0).day;
    return day <= lastDay;
  }
}

enum _Recurrence { once, daily, weekly, monthly, yearly }

/// Ergebnis des Quick-Add-Parsers.
class QuickAddResult {
  const QuickAddResult({
    required this.isValid,
    this.title = '',
    DateTime? dateTime,
    this.person,
    this.isBirthday = false,
    this.timeExplicit = false,
    this.errorCode,
  }) : _dateTime = dateTime;

  QuickAddResult.invalid(String code)
      : isValid = false,
        title = '',
        _dateTime = null,
        person = null,
        isBirthday = false,
        timeExplicit = false,
        errorCode = code;

  final bool isValid;
  final String title;
  final DateTime? _dateTime;
  final String? person;
  final bool isBirthday;
  final bool timeExplicit;
  final String? errorCode;

  /// Nur gültig abrufbar, wenn [isValid] true ist.
  DateTime get dateTime => _dateTime!;
}
