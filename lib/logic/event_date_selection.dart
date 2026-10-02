import 'package:parentpeak/logic/event_flyer_scanner_service.dart';

class EventDateSelection {
  EventDateSelection({required this.date, required this.time});

  DateTime date;
  TimeOfDayLite time;
  bool hasScan = false;
  bool hasConcreteDate = false;
  bool hasConcreteTime = false;
  bool dateConfirmed = false;
  bool timeConfirmed = false;
  bool _manualDate = false;
  bool _manualTime = false;

  void applyScan(ScannedEventDraft draft, DateTime now) {
    hasScan = true;
    dateConfirmed = false;
    timeConfirmed = false;
    if (!_manualDate && draft.date != null) date = draft.date!;
    hasConcreteDate =
        (_manualDate || draft.date != null) &&
        !date.isBefore(DateTime(now.year, now.month, now.day));
    if (!_manualTime && draft.time != null) time = draft.time!;
    hasConcreteTime = _manualTime || draft.time != null;
  }

  void selectDate(DateTime value) {
    date = value;
    _manualDate = true;
    hasConcreteDate = true;
    dateConfirmed = true;
  }

  void selectTime(TimeOfDayLite value) {
    time = value;
    _manualTime = true;
    hasConcreteTime = true;
    timeConfirmed = true;
  }

  bool canSubmit(DateTime now) =>
      localDateTime.isAfter(now) &&
      hasConcreteDate &&
      hasConcreteTime &&
      dateConfirmed &&
      timeConfirmed;

  DateTime get localDateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  DateTime pickerInitialDate(DateTime now) {
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 1, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected.isBefore(first)) return first;
    if (selected.isAfter(last)) return last;
    return selected;
  }
}
