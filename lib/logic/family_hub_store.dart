import 'dart:async';
import 'dart:convert';

import 'package:parentpeak/logic/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyHubAccountChanged implements Exception {
  const FamilyHubAccountChanged();

  @override
  String toString() => 'The family hub account changed during this operation.';
}

/// One local envelope makes account data and legacy ownership a single write.
/// This is account isolation, not encryption.
class FamilyHubStore {
  FamilyHubStore({
    String? Function()? userIdProvider,
    Future<bool> Function(String key, String value)? persist,
  })
      : _userIdProvider = userIdProvider ??
            (() => AuthService.instance.currentUser?.uid),
        _persist = persist;

  static final instance = FamilyHubStore();
  static const storageKey = 'familyhub.accounts.v1';
  static const dossierKey = 'kinddossier.data';
  static const activeKey = 'shopping.active';
  static const doneKey = 'shopping.done';
  static const frequentKey = 'shopping.frequent';
  static const todoKey = 'zentrale.todos';
  static const allergyKey = 'familyküche.allergies';
  static const legacyKeys = [
    dossierKey, activeKey, doneKey, frequentKey, todoKey, allergyKey,
  ];
  static Future<void> _writes = Future<void>.value();

  final String? Function() _userIdProvider;
  final Future<bool> Function(String key, String value)? _persist;
  String? get userId => _userIdProvider();
  String get scope => userId == null
      ? 'guest'
      : 'account.${Uri.encodeComponent(userId!)}';

  void requireScope(String expected) {
    if (scope != expected) throw const FamilyHubAccountChanged();
  }

  Map<String, dynamic> _decode(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null) return {'accounts': <String, dynamic>{}};
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> || root['accounts'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid family hub storage envelope');
    }
    return root;
  }

  Map<String, dynamic> _account(Map<String, dynamic> root, String expected) {
    final accounts = root['accounts'] as Map<String, dynamic>;
    final account = accounts[expected];
    if (account == null) return {};
    if (account is! Map<String, dynamic> ||
        account['owner'] != expected ||
        account['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid family hub account owner');
    }
    return Map<String, dynamic>.from(account['data']);
  }

  Future<Map<String, dynamic>> read({required String expectedScope}) async {
    requireScope(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    return _account(_decode(prefs), expectedScope);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    // Keep the queue usable after a failure; the caller still receives it.
    _writes = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return result;
  }

  Future<void> _commit(SharedPreferences prefs, Map<String, dynamic> root,
      String expected) async {
    requireScope(expected);
    final encoded = jsonEncode(root);
    final persist = _persist;
    final written = persist == null
        ? await prefs.setString(storageKey, encoded)
        : await persist(storageKey, encoded);
    if (!written) {
      // SharedPreferences updates its cache before the platform acknowledges.
      await prefs.reload();
      throw StateError('Could not persist family hub account data');
    }
    requireScope(expected);
  }

  Future<void> write(Map<String, dynamic> changes,
      {required String expectedScope}) {
    final snapshot = jsonDecode(jsonEncode(changes)) as Map<String, dynamic>;
    return _serialize(() async {
      requireScope(expectedScope);
      final prefs = await SharedPreferences.getInstance();
      requireScope(expectedScope);
      final root = _decode(prefs);
      final data = _account(root, expectedScope)..addAll(snapshot);
      (root['accounts'] as Map<String, dynamic>)[expectedScope] = {
        'owner': expectedScope,
        'data': data,
      };
      await _commit(prefs, root, expectedScope);
    });
  }

  Future<bool> hasUnassignedLegacy() async {
    final expected = scope;
    final prefs = await SharedPreferences.getInstance();
    requireScope(expected);
    final root = _decode(prefs);
    if (root['legacyOwner'] != null) return false;
    return legacyKeys.any(prefs.containsKey);
  }

  /// Requires an explicit caller confirmation. The original keys are retained
  /// as a backup but cannot be imported by another account after this commit.
  Future<void> claimLegacy({
    required String expectedScope,
    required Map<String, dynamic> Function(Map<String, dynamic>) normalize,
  }) {
    return _serialize(() async {
      requireScope(expectedScope);
      if (userId == null) throw StateError('Sign in to claim legacy family data');
      final prefs = await SharedPreferences.getInstance();
      requireScope(expectedScope);
      final root = _decode(prefs);
      final claimed = root['legacyOwner'];
      if (claimed == expectedScope) return;
      if (claimed != null) throw StateError('Legacy family data already assigned');
      final legacy = <String, dynamic>{};
      for (final key in legacyKeys) {
        if (!prefs.containsKey(key)) continue;
        legacy[key] = key == frequentKey || key == allergyKey
            ? prefs.getStringList(key)
            : jsonDecode(prefs.getString(key)!);
      }
      final normalized = normalize(legacy);
      final data = _account(root, expectedScope);
      final shoppingIds = <Object>{
        for (final key in [activeKey, doneKey])
          for (final item in (data[key] as List? ?? []))
            (item as Map)['id'],
      };
      for (final entry in normalized.entries) {
        final existing = data[entry.key] as List? ?? [];
        final incoming = entry.value as List;
        if (entry.key == frequentKey || entry.key == allergyKey) {
          data[entry.key] = {...existing, ...incoming}.toList();
          continue;
        }
        final ids = entry.key == activeKey || entry.key == doneKey
            ? shoppingIds
            : existing.map((item) => (item as Map)['id']).toSet();
        final merged = [...existing];
        for (var i = 0; i < incoming.length; i++) {
          final item = Map<String, dynamic>.from(incoming[i] as Map);
          final original = item['id'];
          if (ids.contains(original)) {
            var suffix = i;
            do {
              item['id'] = 'legacy_${entry.key}_${suffix++}_$original';
            } while (ids.contains(item['id']));
          }
          ids.add(item['id']);
          merged.add(item);
        }
        data[entry.key] = merged;
      }
      (root['accounts'] as Map<String, dynamic>)[expectedScope] = {
        'owner': expectedScope,
        'data': data,
      };
      root['legacyOwner'] = expectedScope;
      await _commit(prefs, root, expectedScope);
    });
  }
}
