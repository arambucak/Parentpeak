import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/contracts/calendar_contract.dart';

/// Sichert den Backend-Roundtrip der Zusatzfelder ab: "Wer bringt/holt" und
/// der Pack-Reminder dürfen bei einem Server-Roundtrip NICHT verloren gehen
/// (früherer Bug: buildCreatePayload/normalize ließen sie aus).
void main() {
  group('CalendarContract Roundtrip der Zusatzfelder', () {
    final event = {
      'title': 'Schwimmen',
      'person': 'Mila',
      'location': 'Familienkalender',
      'start': '2026-06-01T10:00:00.000',
      'end': '2026-06-01T11:00:00.000',
      'allDay': false,
      'recurrence': 'Einmalig',
      'reminderMinutes': 0,
      'recurrenceEndMode': 'Kein Ende',
      'packReminder': 'Schwimmsachen + Handtuch',
      'bringer': 'Papa',
      'abholer': 'Oma',
    };

    test('buildCreatePayload sendet packReminder/bringer/abholer', () {
      final payload = CalendarContract.buildCreatePayload(event, userId: 'u1');
      expect(payload['packReminder'], 'Schwimmsachen + Handtuch');
      expect(payload['bringer'], 'Papa');
      expect(payload['abholer'], 'Oma');
    });

    test('owner claim is optional and never an empty UID', () {
      expect(
          CalendarContract.buildCreatePayload(event).containsKey('userId'),
          isFalse);
      expect(
          CalendarContract.buildCreatePayload(event, userId: '')
              .containsKey('userId'),
          isFalse);
      expect(
          CalendarContract.buildCreatePayload(event, userId: 'u1')['userId'],
          'u1');
    });

    test('normalize liest die Felder (camelCase) zurück', () {
      // Simuliert eine Server-Antwort, die genau den Create-Payload spiegelt.
      final payload = CalendarContract.buildCreatePayload(event, userId: 'u1');
      final normalized = CalendarContract.normalize({
        ...payload,
        'id': 'srv_1',
        'start': payload['startAt'],
        'end': payload['endAt'],
      });
      expect(normalized['packReminder'], 'Schwimmsachen + Handtuch');
      expect(normalized['bringer'], 'Papa');
      expect(normalized['abholer'], 'Oma');
    });

    test('normalize liest auch snake_case + Alias "picker"', () {
      final normalized = CalendarContract.normalize({
        'id': 'srv_2',
        'title': 'Zahnarzt',
        'startAt': '2026-06-02T09:00:00.000',
        'endAt': '2026-06-02T09:30:00.000',
        'pack_reminder': 'Versichertenkarte',
        'bringer': 'Mama',
        'picker': 'Papa',
      });
      expect(normalized['packReminder'], 'Versichertenkarte');
      expect(normalized['bringer'], 'Mama');
      expect(normalized['abholer'], 'Papa');
    });

    test('fehlende Zusatzfelder werden null (nicht Leerstring)', () {
      final normalized = CalendarContract.normalize({
        'id': 'srv_3',
        'title': 'Termin',
        'startAt': '2026-06-03T09:00:00.000',
        'endAt': '2026-06-03T10:00:00.000',
      });
      expect(normalized['packReminder'], isNull);
      expect(normalized['bringer'], isNull);
      expect(normalized['abholer'], isNull);
    });
  });
}
