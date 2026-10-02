import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/event_date_selection.dart';
import 'package:parentpeak/logic/event_flyer_scanner_service.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12);
  EventDateSelection selection() => EventDateSelection(
      date: DateTime(2026, 10, 3), time: const TimeOfDayLite(12, 0));

  test('unknown scan date cannot publish the default tomorrow', () {
    final value = selection();
    value.applyScan(
        const ScannedEventDraft(title: 'Theater', time: TimeOfDayLite(10, 0)),
        now);
    expect(value.hasConcreteDate, isFalse);
    expect(value.canSubmit(now), isFalse);
    value.selectTime(const TimeOfDayLite(10, 0));
    expect(value.canSubmit(now), isFalse);
    value.selectDate(DateTime(2026, 10, 5));
    expect(value.canSubmit(now), isTrue);
    expect(value.localDateTime, DateTime(2026, 10, 5, 10));
    expect(value.localDateTime.isUtc, isFalse);
  });

  test('every scan invalidates confirmation but preserves manual choices', () {
    final value = selection();
    value.selectDate(DateTime(2026, 10, 8));
    value.selectTime(const TimeOfDayLite(9, 30));
    value.applyScan(
        ScannedEventDraft(
            date: DateTime(2027, 1, 14), time: const TimeOfDayLite(10, 0)),
        now);
    expect(value.hasConcreteDate, isTrue);
    expect(value.localDateTime, DateTime(2026, 10, 8, 9, 30));
    expect(value.canSubmit(now), isFalse);
    value.selectDate(value.date);
    expect(value.canSubmit(now), isFalse);
    value.selectTime(value.time);
    expect(value.canSubmit(now), isTrue);
    value.applyScan(const ScannedEventDraft(title: 'Re-scan'), now);
    expect(value.canSubmit(now), isFalse);
    expect(value.localDateTime, DateTime(2026, 10, 8, 9, 30));
  });

  test('scanned concrete date and time still require both confirmations', () {
    final value = selection();
    value.applyScan(
        ScannedEventDraft(
            date: DateTime(2026, 10, 7), time: const TimeOfDayLite(10, 0)),
        now);
    expect(value.canSubmit(now), isFalse);
    value.selectDate(value.date);
    expect(value.canSubmit(now), isFalse);
    value.selectTime(value.time);
    expect(value.canSubmit(now), isTrue);
  });

  test('old or distant scan dates are clamped only for the picker', () {
    final value = selection();
    value.applyScan(ScannedEventDraft(date: DateTime(2020, 1, 1)), now);
    expect(value.hasConcreteDate, isFalse);
    expect(value.pickerInitialDate(now), DateTime(2026, 10, 2));
    value.selectDate(DateTime(2026, 10, 2));
    value.selectTime(const TimeOfDayLite(10, 0));
    expect(value.canSubmit(now), isFalse);
    value.applyScan(ScannedEventDraft(date: DateTime(2030, 1, 1)), now);
    expect(value.pickerInitialDate(now), DateTime(2026, 10, 2));
    final distant = selection();
    distant.applyScan(ScannedEventDraft(date: DateTime(2030, 1, 1)), now);
    expect(distant.pickerInitialDate(now), DateTime(2027, 10, 2));
    expect(distant.date, DateTime(2030, 1, 1));
  });
}
