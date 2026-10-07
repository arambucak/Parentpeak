import 'dart:convert';

import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/treasure_draft_images.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TreasureAccountChanged implements Exception {
  const TreasureAccountChanged();
  @override
  String toString() => 'The treasure account changed during this operation.';
}

/// Account isolation, not encryption. Legacy ownership is independent of other tiles.
class TreasureAccountStore {
  TreasureAccountStore({
    String? Function()? userIdProvider,
    Future<bool> Function(String key, String value)? persist,
  }) : _userIdProvider = userIdProvider ?? (() => AuthService.instance.currentUser?.uid),
       _persist = persist;

  static final instance = TreasureAccountStore();
  static const storageKey = 'treasure.accounts.v1';
  static const draftKey = 'treasure_upload_draft.v1';
  static const reservedKey = 'treasure_reserved_ids.v1';
  static const blockedKey = 'treasure_blocked_listing_ids.v1';
  static const reportedKey = 'treasure_reported_listing_ids.v1';
  static const feedKey = 'treasure_listings.v1';
  static const legacyKeys = [draftKey, reservedKey, blockedKey, reportedKey];
  static Future<void>? _writes;
  final String? Function() _userIdProvider;
  final Future<bool> Function(String key, String value)? _persist;

  String? get userId => _userIdProvider();
  String get scope {
    final uid = userId;
    return uid == null ? 'guest' : 'account.${Uri.encodeComponent(uid)}';
  }

  void requireScope(String expected) {
    if (scope != expected) throw const TreasureAccountChanged();
  }

  Map<String, dynamic> _decode(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null) return {'accounts': <String, dynamic>{}};
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> ||
        root['accounts'] is! Map<String, dynamic> ||
        (root['legacyOwner'] != null && root['legacyOwner'] is! String)) {
      throw const FormatException('Invalid treasure account envelope');
    }
    return root;
  }

  Map<String, dynamic> _validate(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final valid = switch (entry.key) {
        draftKey => entry.value == null || entry.value is Map<String, dynamic>,
        reservedKey || blockedKey || reportedKey =>
          entry.value is List && (entry.value as List).every((id) => id is String && id.isNotEmpty),
        feedKey => entry.value is List && (entry.value as List).every((item) => item is Map<String, dynamic>),
        _ => false,
      };
      if (!valid) throw FormatException('Invalid treasure data: ${entry.key}');
      if (entry.key == draftKey && entry.value != null) {
        final draft = entry.value as Map<String, dynamic>;
        final condition = draft['conditionIndex'];
        final distance = draft['distanceMeters'];
        if ((condition != null && (condition is! int || condition < 0 || condition > 2)) ||
            (distance != null && (distance is! num || !distance.isFinite || distance < 50 || distance > 800))) {
          throw const FormatException('Invalid treasure draft range');
        }
        for (final key in ['title', 'colorLabel', 'note', 'sizeAge', 'categoryKey', 'imagePath']) {
          if (draft[key] != null && draft[key] is! String) {
            throw FormatException('Invalid treasure draft field: $key');
          }
        }
        final paths = draft['imagePaths'];
        if (paths != null && (paths is! List || paths.any((path) => path is! String))) {
          throw const FormatException('Invalid treasure draft images');
        }
        if (draft['images'] != null) TreasureDraftImages.validate(draft['images']);
      }
    }
    return data;
  }

  Map<String, dynamic> _account(Map<String, dynamic> root, String scope) {
    final account = (root['accounts'] as Map<String, dynamic>)[scope];
    if (account == null) return {};
    if (account is! Map<String, dynamic> ||
        account['owner'] != scope ||
        account['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid treasure account owner');
    }
    return _validate(Map<String, dynamic>.from(account['data']));
  }

  Future<Map<String, dynamic>> read({required String expectedScope}) async {
    requireScope(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    return _account(_decode(prefs), expectedScope);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = (_writes ?? Future<void>.value()).then((_) => operation());
    // Preserve the queue after failure; the caller still receives the error.
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }
    tail = result.then<void>((_) => release(),
      onError: (Object error, StackTrace stack) => release());
    _writes = tail;
    return result;
  }

  Future<void> _commit(SharedPreferences prefs, Map<String, dynamic> root, String scope) async {
    requireScope(scope);
    bool written;
    final persist = _persist;
    try {
      written = await (persist == null
          ? prefs.setString(storageKey, jsonEncode(root))
          : persist(storageKey, jsonEncode(root)));
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    if (!written) {
      await prefs.reload();
      throw StateError('Could not persist treasure account data');
    }
    requireScope(scope);
  }

  Future<void> update(
    void Function(Map<String, dynamic>) mutation, {
    required String expectedScope,
  }) => _serialize(() async {
    requireScope(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    final root = _decode(prefs);
    final data = _account(root, expectedScope);
    mutation(data);
    (root['accounts'] as Map<String, dynamic>)[expectedScope] = {
      'owner': expectedScope, 'data': _validate(data),
    };
    await _commit(prefs, root, expectedScope);
  });

  Future<bool> hasUnassignedLegacy({required String expectedScope}) async {
    requireScope(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    return _decode(prefs)['legacyOwner'] == null && legacyKeys.any(prefs.containsKey);
  }

  Future<void> claimLegacy({required String expectedScope}) => _serialize(() async {
    requireScope(expectedScope);
    if (userId == null) throw StateError('Sign in to claim treasure data');
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    final root = _decode(prefs);
    final owner = root['legacyOwner'];
    if (owner == expectedScope) return;
    if (owner != null) throw StateError('Legacy treasure data already assigned');
    final legacy = <String, dynamic>{};
    for (final key in legacyKeys) {
      if (!prefs.containsKey(key)) continue;
      legacy[key] = key == draftKey
          ? jsonDecode(prefs.getString(key)!)
          : prefs.getStringList(key);
    }
    _validate(legacy);
    final data = _account(root, expectedScope);
    for (final entry in legacy.entries) {
      if (entry.key == draftKey) {
        if (!data.containsKey(draftKey)) data[draftKey] = entry.value;
      } else {
        data[entry.key] = {
          ...?data[entry.key] as List?,
          ...entry.value as List,
        }.toList();
      }
    }
    (root['accounts'] as Map<String, dynamic>)[expectedScope] = {
      'owner': expectedScope, 'data': data,
    };
    root['legacyOwner'] = expectedScope;
    await _commit(prefs, root, expectedScope);
  });
}
