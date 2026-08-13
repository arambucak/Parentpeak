import 'package:parentpeak/config/api_config.dart';

import 'backend_contract_utils.dart';

class CalendarContract {
  static String get eventsPath => APIConfig.getBackendCalendarEventsPath();

  static List<Map<String, dynamic>> parseList(dynamic payload) {
    final raw = extractListFromPayload(
        payload, const ['events', 'items', 'data', 'results']);
    return raw.map(normalize).toList();
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final now = DateTime.now();
    final start =
        _pickDate(raw, const ['start', 'startAt', 'start_time']) ?? now;
    final end = _pickDate(raw, const ['end', 'endAt', 'end_time']) ??
        now.add(const Duration(hours: 1));

    return {
      'id': pickString(raw, const ['id', '_id', 'uuid'],
          now.microsecondsSinceEpoch.toString()),
      'title': pickString(raw, const ['title', 'name', 'subject'], ''),
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'person': pickString(
          raw, const ['person', 'personName', 'owner', 'assignee'], 'Eltern'),
      'location': pickString(raw, const ['location', 'place', 'address'], ''),
      'allDay': pickBool(raw, const ['allDay', 'all_day'], false),
      'recurrence': pickString(raw, const ['recurrence', 'repeat'], 'Einmalig'),
      'reminderMinutes':
          _pickInt(raw, const ['reminderMinutes', 'reminder_minutes'], 0),
      'recurrenceEndMode': pickString(
          raw, const ['recurrenceEndMode', 'repeat_end_mode'], 'Kein Ende'),
      'recurrenceEndDate':
          _pickDate(raw, const ['recurrenceEndDate', 'repeat_end_date'])
              ?.toIso8601String(),
      'recurrenceCount':
          _pickNullableInt(raw, const ['recurrenceCount', 'repeat_count']),
    };
  }

  static Map<String, dynamic>? parseSingleItem(dynamic payload) {
    final item = extractItemFromPayload(
        payload, const ['item', 'event', 'data', 'result']);
    if (item == null) return null;
    return normalize(item);
  }

  static Map<String, dynamic> buildCreatePayload(Map<String, dynamic> event, {String? userId}) {
    return {
      'userId': userId ?? '',
      'familyId': APIConfig.getBackendFamilyId(),
      'title': event['title'] ?? '',
      'description': '',
      'personName': event['person'] ?? 'Eltern',
      'location': event['location'] ?? '',
      'startAt': event['start'],
      'endAt': event['end'],
      'allDay': event['allDay'] ?? false,
      'recurrence': event['recurrence'] ?? 'Einmalig',
      'recurrenceEndMode': event['recurrenceEndMode'] ?? 'Kein Ende',
      'recurrenceEndDate': event['recurrenceEndDate'],
      'recurrenceCount': event['recurrenceCount'],
      'reminderMinutes': event['reminderMinutes'] ?? 0,
      'schemaVersion': APIConfig.getBackendApiVersion(),
    };
  }

  static DateTime? _pickDate(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int _pickInt(
      Map<String, dynamic> source, List<String> keys, int fallback) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static int? _pickNullableInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
