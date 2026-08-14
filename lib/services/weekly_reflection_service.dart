import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single weekly reflection entry with 5 guided questions
class WeeklyReflection {
  final String weekId; // e.g. "2026-W33"
  final DateTime createdAt;
  final String
      overallMood; // Emoji key: Super, Gut, Gemischt, Anstrengend, Dankbar
  final String whatWentWell;
  final String whatWasChallenging;
  final String whatILearned;
  final String lookingForwardTo;
  final String? aiFeedback;

  const WeeklyReflection({
    required this.weekId,
    required this.createdAt,
    required this.overallMood,
    required this.whatWentWell,
    required this.whatWasChallenging,
    required this.whatILearned,
    required this.lookingForwardTo,
    this.aiFeedback,
  });

  Map<String, dynamic> toJson() => {
        'weekId': weekId,
        'createdAt': createdAt.toIso8601String(),
        'overallMood': overallMood,
        'whatWentWell': whatWentWell,
        'whatWasChallenging': whatWasChallenging,
        'whatILearned': whatILearned,
        'lookingForwardTo': lookingForwardTo,
        if (aiFeedback != null) 'aiFeedback': aiFeedback,
      };

  factory WeeklyReflection.fromJson(Map<String, dynamic> j) => WeeklyReflection(
        weekId: j['weekId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        overallMood: j['overallMood'] as String,
        whatWentWell: j['whatWentWell'] as String? ?? '',
        whatWasChallenging: j['whatWasChallenging'] as String? ?? '',
        whatILearned: j['whatILearned'] as String? ?? '',
        lookingForwardTo: j['lookingForwardTo'] as String? ?? '',
        aiFeedback: j['aiFeedback'] as String?,
      );

  WeeklyReflection copyWith({String? aiFeedback}) => WeeklyReflection(
        weekId: weekId,
        createdAt: createdAt,
        overallMood: overallMood,
        whatWentWell: whatWentWell,
        whatWasChallenging: whatWasChallenging,
        whatILearned: whatILearned,
        lookingForwardTo: lookingForwardTo,
        aiFeedback: aiFeedback ?? this.aiFeedback,
      );
}

class WeeklyReflectionService {
  static const _key = 'weekly_reflections.v1';

  /// Get current ISO week ID (e.g. "2026-W33")
  static String currentWeekId() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekNumber = _isoWeekNumber(monday);
    return '${monday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  static int _isoWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    return woy;
  }

  /// Save a reflection
  static Future<void> save(WeeklyReflection reflection) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    // Replace existing for same week or add new
    final idx = all.indexWhere((r) => r.weekId == reflection.weekId);
    if (idx >= 0) {
      all[idx] = reflection;
    } else {
      all.add(reflection);
    }
    // Keep max 52 weeks
    if (all.length > 52) all.removeRange(0, all.length - 52);
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await prefs.setString(
        _key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// Load all reflections
  static Future<List<WeeklyReflection>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => WeeklyReflection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a reflection by weekId
  static Future<void> delete(String weekId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.removeWhere((r) => r.weekId == weekId);
    await prefs.setString(
        _key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// Get reflection for current week (if exists)
  static Future<WeeklyReflection?> currentWeek() async {
    final all = await loadAll();
    final id = currentWeekId();
    try {
      return all.firstWhere((r) => r.weekId == id);
    } catch (_) {
      return null;
    }
  }

  /// Check if this week's reflection is already done
  static Future<bool> isCurrentWeekDone() async {
    return (await currentWeek()) != null;
  }
}
