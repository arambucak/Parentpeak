import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/notification_service.dart';

void main() {
  group('NotificationService.smartReminderTimes', () {
    test('plant alle drei Erinnerungen bei einem weit entfernten Termin', () {
      final now = DateTime(2026, 11, 5, 9, 0);
      final start = DateTime(2026, 12, 1, 15, 0); // ~4 Wochen entfernt
      final r = NotificationService.smartReminderTimes(start, now: now);
      expect(r.map((e) => e.key), ['week_before', 'day_before', 'event_day']);
      expect(r[0].when, start.subtract(const Duration(days: 7)));
      expect(r[1].when, start.subtract(const Duration(days: 1)));
      expect(r[2].when, start);
    });

    test('lässt die 1-Woche-Erinnerung weg, wenn sie in der Vergangenheit läge',
        () {
      final now = DateTime(2026, 11, 5, 9, 0);
      final start = DateTime(2026, 11, 9, 15, 0); // nur 4 Tage entfernt
      final r = NotificationService.smartReminderTimes(start, now: now);
      expect(r.map((e) => e.key), ['day_before', 'event_day']);
    });

    test('nur die Termin-Erinnerung bleibt bei sehr kurzfristigem Termin', () {
      final now = DateTime(2026, 11, 5, 9, 0);
      final start = DateTime(2026, 11, 5, 18, 0); // heute Abend
      final r = NotificationService.smartReminderTimes(start, now: now);
      expect(r.map((e) => e.key), ['event_day']);
    });

    test('keine Erinnerung für einen bereits vergangenen Termin', () {
      final now = DateTime(2026, 11, 5, 20, 0);
      final start = DateTime(2026, 11, 5, 18, 0); // schon vorbei
      final r = NotificationService.smartReminderTimes(start, now: now);
      expect(r, isEmpty);
    });

    test('Grenzfall: Termin exakt jetzt wird nicht geplant', () {
      final now = DateTime(2026, 11, 5, 18, 0);
      final start = DateTime(2026, 11, 5, 18, 0);
      final r = NotificationService.smartReminderTimes(start, now: now);
      expect(r, isEmpty);
    });
  });
}
