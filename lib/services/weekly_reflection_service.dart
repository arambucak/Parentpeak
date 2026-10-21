import 'dart:convert';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
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
  WeeklyReflectionService({
    String Function()? scopeProvider,
    Future<bool> Function(String key, String value)? persist,
  })  : _scopeProvider = scopeProvider ?? _currentScope,
        _persist = persist;

  static final instance = WeeklyReflectionService();
  static const storagePrefix = 'weekly_reflections.v2';
  final String Function() _scopeProvider;
  final Future<bool> Function(String key, String value)? _persist;
  static Future<void>? _writes;
  static const legacyOwnerKey = 'weekly_reflections.legacy_owner.v1';
  static const legacyImportedKey = 'weekly_reflections.legacy_imported.v1';
  String get scope => _scopeProvider();

  static String _currentScope() {
    final uid = AuthService.instance.currentUser?.uid;
    return uid == null ? 'guest' : 'account.${Uri.encodeComponent(uid)}';
  }

  void requireScope(String expected) {
    if (scope != expected) throw const AccountAiConsentRequiredException();
  }

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
  Future<void> save(
    WeeklyReflection reflection, {
    String? expectedScope,
    void Function()? requestGuard,
  }) =>
      _change(expectedScope ?? scope, (all) {
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
      }, requestGuard: requestGuard);

  /// Load all reflections
  Future<List<WeeklyReflection>> loadAll({String? expectedScope}) async {
    final owner = expectedScope ?? scope;
    requireScope(owner);
    final prefs = await SharedPreferences.getInstance();
    requireScope(owner);
    final raw = prefs.getString('$storagePrefix.$owner');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => WeeklyReflection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = (_writes ?? Future<void>.value()).then((_) => operation());
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }

    tail = result.then<void>((_) => release(),
        onError: (Object error, StackTrace stack) => release());
    _writes = tail;
    return result;
  }

  Future<void> _write(SharedPreferences prefs, String key, String raw) async {
    bool written;
    final persist = _persist;
    try {
      written = await (persist == null
          ? prefs.setString(key, raw)
          : persist(key, raw));
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    if (!written) {
      await prefs.reload();
      throw StateError('Could not persist weekly reflection');
    }
  }

  Future<void> _change(
          String owner, void Function(List<WeeklyReflection>) change,
          {void Function()? requestGuard}) =>
      _serialize(() async {
        void guard() {
          requireScope(owner);
          requestGuard?.call();
        }

        guard();
        final prefs = await SharedPreferences.getInstance();
        final all = await loadAll(expectedScope: owner);
        guard();
        change(all);
        final raw = jsonEncode(all.map((e) => e.toJson()).toList());
        guard();
        await _write(prefs, '$storagePrefix.$owner', raw);
        guard();
      });

  Future<bool> hasLegacy() async {
    final owner = scope;
    final prefs = await SharedPreferences.getInstance();
    requireScope(owner);
    final assigned = prefs.getString(legacyOwnerKey);
    return prefs.containsKey('weekly_reflections.v1') &&
        (assigned == null || assigned == owner) &&
        prefs.getString(legacyImportedKey) != owner;
  }

  Future<void> claimLegacy({
    required String expectedScope,
    required void Function() requestGuard,
  }) =>
      _serialize(() async {
        void guard() {
          requireScope(expectedScope);
          requestGuard();
          if (expectedScope == 'guest') {
            throw StateError('Sign in to claim reflections');
          }
        }

        guard();
        final prefs = await SharedPreferences.getInstance();
        guard();
        final assigned = prefs.getString(legacyOwnerKey);
        if (assigned != null && assigned != expectedScope) {
          throw StateError(
              'Legacy reflections already assigned to another account');
        }
        final raw = prefs.getString('weekly_reflections.v1');
        if (raw == null) throw StateError('No legacy reflections available');
        final legacy = (jsonDecode(raw) as List)
            .map((e) => WeeklyReflection.fromJson(e as Map<String, dynamic>))
            .toList();
        final all = await loadAll(expectedScope: expectedScope);
        final currentWeeks = all.map((e) => e.weekId).toSet();
        all.addAll(legacy.where((e) => currentWeeks.add(e.weekId)));
        all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (all.length > 52) all.removeRange(0, all.length - 52);
        guard();
        // Reserve ownership first: a failed/interrupted import remains retryable
        // for this account, never claimable by the next account on the device.
        await _write(prefs, legacyOwnerKey, expectedScope);
        guard();
        await _write(prefs, '$storagePrefix.$expectedScope',
            jsonEncode(all.map((e) => e.toJson()).toList()));
        guard();
        await _write(prefs, legacyImportedKey, expectedScope);
        guard();
      });

  /// Delete a reflection by weekId
  Future<void> delete(String weekId, {String? expectedScope}) {
    return _change(expectedScope ?? scope, (all) {
      all.removeWhere((r) => r.weekId == weekId);
    });
  }

  /// Get reflection for current week (if exists)
  Future<WeeklyReflection?> currentWeek({String? expectedScope}) async {
    final all = await loadAll(expectedScope: expectedScope);
    final id = currentWeekId();
    for (final reflection in all) {
      if (reflection.weekId == id) return reflection;
    }
    return null;
  }

  /// Check if this week's reflection is already done
  Future<bool> isCurrentWeekDone() async {
    return (await currentWeek()) != null;
  }
}
