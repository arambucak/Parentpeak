import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/calendar_logic.dart';

/// Unit-Tests für die reine Kalender-Logik (NLP-Parser, Recurrence-Expansion,
/// Monats-Grid-Berechnung, Locale-Mapping).
void main() {
  group('CalendarLogic.parseQuickInput', () {
    // Fester Referenzzeitpunkt: Mittwoch, 1. Oktober 2025, 09:00.
    final now = DateTime(2025, 10, 1, 9, 0);
    final selected = DateTime(2025, 10, 15);

    test('Titel + Uhrzeit (HH:mm)', () {
      final r = CalendarLogic.parseQuickInput('Arzt 10:30',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.title, 'Arzt');
      expect(r.dateTime.hour, 10);
      expect(r.dateTime.minute, 30);
      // Ohne Wochentag/Datum fällt es auf den ausgewählten Tag zurück.
      expect(r.dateTime.year, 2025);
      expect(r.dateTime.month, 10);
      expect(r.dateTime.day, 15);
    });

    test('Uhrzeit im "Uhr"-Format', () {
      final r = CalendarLogic.parseQuickInput('Treffen 14 Uhr',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.title, 'Treffen');
      expect(r.dateTime.hour, 14);
      expect(r.dateTime.minute, 0);
    });

    test('Wochentag berechnet nächstes Vorkommen', () {
      // "Mo" von Mittwoch aus → kommender Montag = 6. Oktober 2025.
      final r = CalendarLogic.parseQuickInput('Zahnarzt Mo 09:00',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.title, 'Zahnarzt');
      expect(r.dateTime.weekday, DateTime.monday);
      expect(r.dateTime, DateTime(2025, 10, 6, 9, 0));
    });

    test('gleicher Wochentag springt eine Woche weiter', () {
      // "Mi" von Mittwoch aus → nächster Mittwoch (nicht heute).
      final r = CalendarLogic.parseQuickInput('Sport Mi',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.dateTime, DateTime(2025, 10, 8, 10, 0));
    });

    test('explizites Datum hat Vorrang vor Wochentag', () {
      final r = CalendarLogic.parseQuickInput('Oma 25.12.2025 Mo',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.dateTime.year, 2025);
      expect(r.dateTime.month, 12);
      expect(r.dateTime.day, 25);
    });

    test('Datum ohne Jahr nutzt aktuelles Jahr', () {
      final r = CalendarLogic.parseQuickInput('Fest 03.11.',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.dateTime, DateTime(2025, 11, 3, 10, 0));
    });

    test('Geburtstags-Keyword setzt Person + Flag', () {
      final r = CalendarLogic.parseQuickInput('Lena Geburtstag 20.05.',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.isBirthday, isTrue);
      expect(r.person, CalendarLogic.birthdayPersonKey);
    });

    test('leere Eingabe ist ungültig', () {
      final r = CalendarLogic.parseQuickInput('   ',
          selectedDay: selected, now: now);
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'empty');
    });

    test('ungültige Uhrzeit 25:99 wird abgelehnt statt normalisiert', () {
      final r = CalendarLogic.parseQuickInput('Arzt 25:99',
          selectedDay: selected, now: now);
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'time_out_of_range');
    });

    test('Stunde > 23 im Uhr-Format wird abgelehnt', () {
      final r = CalendarLogic.parseQuickInput('Termin 26 Uhr',
          selectedDay: selected, now: now);
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'time_out_of_range');
    });

    test('unplausibles Datum 31.02. wird abgelehnt', () {
      final r = CalendarLogic.parseQuickInput('Termin 31.02.',
          selectedDay: selected, now: now);
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'date_invalid');
    });

    test('Monat > 12 wird abgelehnt', () {
      final r = CalendarLogic.parseQuickInput('Termin 10.13.2025',
          selectedDay: selected, now: now);
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'date_invalid');
    });

    test('Eingabe nur mit Uhrzeit ohne Titel liefert kein Crash', () {
      final r = CalendarLogic.parseQuickInput('10:00',
          selectedDay: selected, now: now);
      // Kein Titel übrig → Parser markiert als ungültig (sauberer Fallback).
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'no_title');
    });

    test('gültiger 29.02. in Schaltjahr', () {
      final r = CalendarLogic.parseQuickInput('Termin 29.02.2028',
          selectedDay: selected, now: now);
      expect(r.isValid, isTrue);
      expect(r.dateTime, DateTime(2028, 2, 29, 10, 0));
    });

    test('ungültiger 29.02. in Nicht-Schaltjahr', () {
      final r = CalendarLogic.parseQuickInput('Termin 29.02.2027',
          selectedDay: selected, now: now);
      expect(r.isValid, isFalse);
      expect(r.errorCode, 'date_invalid');
    });
  });

  group('CalendarLogic.expandRecurrenceStarts', () {
    final base = DateTime(2026, 1, 15, 10, 0);

    test('Einmalig liefert nur den Starttermin', () {
      final r = CalendarLogic.expandRecurrenceStarts(
          start: base, recurrence: 'Einmalig');
      expect(r.length, 1);
      expect(r.first, base);
    });

    test('Täglich mit fester Anzahl', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: base,
        recurrence: 'Täglich',
        endMode: '5 Termine',
        count: 5,
      );
      expect(r.length, 5);
      expect(r[1], DateTime(2026, 1, 16, 10, 0));
      expect(r[4], DateTime(2026, 1, 19, 10, 0));
    });

    test('Wöchentlich mit fester Anzahl', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: base,
        recurrence: 'Wöchentlich',
        endMode: '3 Termine',
        count: 3,
      );
      expect(r.length, 3);
      expect(r[1], DateTime(2026, 1, 22, 10, 0));
      expect(r[2], DateTime(2026, 1, 29, 10, 0));
    });

    test('Monatlich ist kalendergenau (nicht 30-Tage)', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: DateTime(2026, 1, 15, 8, 0),
        recurrence: 'Monatlich',
        endMode: '4 Termine',
        count: 4,
      );
      expect(r[1], DateTime(2026, 2, 15, 8, 0));
      expect(r[2], DateTime(2026, 3, 15, 8, 0));
      expect(r[3], DateTime(2026, 4, 15, 8, 0));
    });

    test('Monatlich klemmt den 31. auf letzten Monatstag', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: DateTime(2026, 1, 31, 9, 0),
        recurrence: 'Monatlich',
        endMode: '3 Termine',
        count: 3,
      );
      // Februar 2026 hat 28 Tage.
      expect(r[1], DateTime(2026, 2, 28, 9, 0));
      // März hat wieder 31.
      expect(r[2], DateTime(2026, 3, 31, 9, 0));
    });

    test('Monatlich über Jahreswechsel', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: DateTime(2026, 11, 10, 7, 30),
        recurrence: 'Monatlich',
        endMode: '4 Termine',
        count: 4,
      );
      expect(r[1], DateTime(2026, 12, 10, 7, 30));
      expect(r[2], DateTime(2027, 1, 10, 7, 30));
      expect(r[3], DateTime(2027, 2, 10, 7, 30));
    });

    test('Jährlich klemmt 29.02. in Nicht-Schaltjahren', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: DateTime(2028, 2, 29, 12, 0),
        recurrence: 'Jährlich',
        endMode: '3 Termine',
        count: 3,
      );
      // 2029 ist kein Schaltjahr → 28.02.
      expect(r[1], DateTime(2029, 2, 28, 12, 0));
      // 2030 ebenfalls nicht.
      expect(r[2], DateTime(2030, 2, 28, 12, 0));
    });

    test('Enddatum begrenzt die Serie', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: base,
        recurrence: 'Wöchentlich',
        endMode: 'Datum wählen',
        endDate: DateTime(2026, 2, 1),
      );
      // 15.01, 22.01, 29.01 liegen vor dem 01.02; 05.02 nicht mehr.
      expect(r.length, 3);
      expect(r.last, DateTime(2026, 1, 29, 10, 0));
    });

    test('offenes Ende wird durch openEndedLimit begrenzt', () {
      final r = CalendarLogic.expandRecurrenceStarts(
        start: base,
        recurrence: 'Täglich',
        endMode: 'Kein Ende',
        openEndedLimit: 5,
      );
      expect(r.length, 5);
    });
  });

  group('CalendarLogic.daysInMonthGrid', () {
    test('Grid-Länge ist immer ein Vielfaches von 7', () {
      for (int month = 1; month <= 12; month++) {
        final days = CalendarLogic.daysInMonthGrid(DateTime(2026, month, 1));
        expect(days.length % 7, 0, reason: 'Monat $month nicht volle Wochen');
      }
    });

    test('erster Eintrag ist ein Montag, letzter ein Sonntag', () {
      final days = CalendarLogic.daysInMonthGrid(DateTime(2026, 3, 1));
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
    });

    test('enthält alle Tage des Monats', () {
      final days = CalendarLogic.daysInMonthGrid(DateTime(2026, 2, 1));
      final febDays =
          days.where((d) => d.month == 2 && d.year == 2026).map((d) => d.day);
      // Februar 2026: 28 Tage.
      expect(febDays.toSet().length, 28);
      expect(febDays.contains(1), isTrue);
      expect(febDays.contains(28), isTrue);
    });

    test('Schaltjahr Februar 2028 hat 29 Tage im Grid', () {
      final days = CalendarLogic.daysInMonthGrid(DateTime(2028, 2, 1));
      final febDays =
          days.where((d) => d.month == 2 && d.year == 2028).map((d) => d.day);
      expect(febDays.toSet().length, 29);
      expect(febDays.contains(29), isTrue);
    });

    test('führende Tage stammen aus dem Vormonat (Jahreswechsel)', () {
      // Januar 2026 beginnt an einem Donnerstag → Mo/Di/Mi aus Dez 2025.
      final days = CalendarLogic.daysInMonthGrid(DateTime(2026, 1, 1));
      expect(days.first.year, 2025);
      expect(days.first.month, 12);
    });

    test('nachlaufende Tage füllen die letzte Woche auf', () {
      final days = CalendarLogic.daysInMonthGrid(DateTime(2026, 1, 1));
      // Letzter Grid-Tag muss nach dem 31.01. liegen (Folgemonat).
      expect(days.last.isAfter(DateTime(2026, 1, 31)), isTrue);
    });
  });

  group('CalendarLogic.localeTag', () {
    test('mappt Kurdisch-Varianten auf verfügbare intl-Locales', () {
      expect(CalendarLogic.localeTag('ku'), 'en');
      expect(CalendarLogic.localeTag('ckb'), 'ar');
    });

    test('reicht Standard-Codes unverändert durch', () {
      expect(CalendarLogic.localeTag('de'), 'de');
      expect(CalendarLogic.localeTag('tr'), 'tr');
      expect(CalendarLogic.localeTag('ar'), 'ar');
    });
  });

  group('CalendarLogic.isSameDay', () {
    test('gleicher Tag trotz unterschiedlicher Uhrzeit', () {
      expect(
        CalendarLogic.isSameDay(
            DateTime(2026, 5, 1, 8), DateTime(2026, 5, 1, 23)),
        isTrue,
      );
    });

    test('unterschiedliche Tage', () {
      expect(
        CalendarLogic.isSameDay(DateTime(2026, 5, 1), DateTime(2026, 5, 2)),
        isFalse,
      );
    });
  });
}
