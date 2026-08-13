import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MoodEntry {
  final DateTime date;
  final String mood;
  final String? moment;

  const MoodEntry({required this.date, required this.mood, this.moment});

  Map<String, dynamic> toJson() => {
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'mood': mood,
        if (moment != null && moment!.isNotEmpty) 'moment': moment,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> j) => MoodEntry(
        date: DateTime.parse(j['date'] as String),
        mood: j['mood'] as String,
        moment: j['moment'] as String?,
      );
}

class MoodHistoryService {
  static const _key = 'mood.history.v2';

  static Future<void> saveMood(String mood, {String? moment}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadHistory();
    final today = _dateOnly(DateTime.now());
    final filtered = entries.where((e) => !_isSameDay(e.date, today)).toList();
    final trimmed = moment?.trim();
    filtered.add(MoodEntry(
      date: today,
      mood: mood,
      moment: (trimmed?.isNotEmpty ?? false) ? trimmed : null,
    ));
    filtered.sort((a, b) => a.date.compareTo(b.date));
    final capped =
        filtered.length > 7 ? filtered.sublist(filtered.length - 7) : filtered;
    await prefs.setString(
        _key, jsonEncode(capped.map((e) => e.toJson()).toList()));
    // Legacy compat keys
    await prefs.setString('mood.today', mood);
    await prefs.setString('mood.today_date', DateTime.now().toIso8601String());
  }

  static Future<List<MoodEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
