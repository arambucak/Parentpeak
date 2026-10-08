import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileAccountChanged implements Exception {
  const ProfileAccountChanged();
  @override
  String toString() => 'The profile session changed during this operation.';
}

class ProfileAccountTicket {
  const ProfileAccountTicket(this.scope, this.generation);
  final String scope;
  final int generation;
}

enum ProfileLegacyDomain { children, onboarding, location }

class ProfileAccountStore extends ChangeNotifier {
  ProfileAccountStore({
    String? Function()? userIdProvider,
    Future<bool> Function(String, String)? persist,
  }) : _userIdProvider =
           userIdProvider ?? (() => AuthService.instance.currentUser?.uid),
       _persist = persist,
       _checkFirebase = userIdProvider == null {
    _lastScope = scope;
    AuthService.instance.addListener(synchronize);
  }

  static final instance = ProfileAccountStore();
  static const storageKey = 'profile.accounts.v1';
  static const childrenKey = 'profile.children';
  static const completedKey = 'onboarding.completed';
  static const familyNameKey = 'onboarding.family_name';
  static const roleKey = 'onboarding.parent_role';
  static const rolesKey = 'onboarding.parent_roles';
  static const agesKey = 'onboarding.child_ages';
  static const prioritiesKey = 'onboarding.priorities';
  static const countryKey = 'holiday.country';
  static const regionKey = 'holiday.region';
  static const tileOrderKey = 'home.tile_order.v1';
  static const latitudeKey = 'location.latitude';
  static const longitudeKey = 'location.longitude';
  static const cityKey = 'location.city';
  static const methodKey = 'location.method';
  static const eventCityKey = 'events.saved_city';
  static const stringKeys = [
    familyNameKey, roleKey, countryKey, regionKey, cityKey, methodKey, eventCityKey,
  ];
  static const listKeys = [
    childrenKey, rolesKey, agesKey, prioritiesKey, tileOrderKey,
  ];
  static const domains = {
    ProfileLegacyDomain.children: [childrenKey],
    ProfileLegacyDomain.onboarding: [
      completedKey, familyNameKey, roleKey, rolesKey, agesKey, prioritiesKey,
      countryKey, regionKey, tileOrderKey,
    ],
    ProfileLegacyDomain.location: [
      latitudeKey, longitudeKey, cityKey, methodKey, eventCityKey,
    ],
  };
  static Future<void>? _writes;
  final String? Function() _userIdProvider;
  final Future<bool> Function(String, String)? _persist;
  final bool _checkFirebase;
  late String _lastScope;
  int _generation = 0;

  String? get userId => _userIdProvider();
  String get scope {
    final uid = userId;
    return uid == null || uid.trim().isEmpty
        ? 'guest'
        : 'account.${Uri.encodeComponent(uid)}';
  }

  void synchronize() {
    if (_lastScope == scope) return;
    _lastScope = scope;
    _generation++;
    notifyListeners();
  }

  ProfileAccountTicket get ticket {
    synchronize();
    return ProfileAccountTicket(scope, _generation);
  }

  void require(ProfileAccountTicket expected) {
    synchronize();
    if (expected.scope != scope || expected.generation != _generation ||
        (_checkFirebase && Firebase.apps.isNotEmpty &&
            FirebaseAuth.instance.currentUser?.uid != userId)) {
      throw const ProfileAccountChanged();
    }
  }

  bool isCurrent(ProfileAccountTicket expected) {
    try {
      require(expected);
      return true;
    } on ProfileAccountChanged {
      return false;
    }
  }

  void _validate(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final key = entry.key, value = entry.value;
      final valid = key == completedKey
          ? value is bool
          : stringKeys.contains(key)
              ? value is String
              : listKeys.contains(key)
                  ? value is List && value.every((item) => item is String)
                  : key == latitudeKey || key == longitudeKey
                      ? value is num && value.isFinite &&
                          value.abs() <= (key == latitudeKey ? 90 : 180)
                      : false;
      if (!valid) throw FormatException('Invalid profile field: $key');
    }
  }

  Map<String, dynamic> _root(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      return {'version': 1, 'accounts': <String, dynamic>{},
        'legacyOwners': <String, dynamic>{}};
    }
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> || root['version'] != 1 ||
        root['accounts'] is! Map<String, dynamic> ||
        root['legacyOwners'] is! Map<String, dynamic> ||
        !(root['legacyOwners'] as Map).entries.every((entry) =>
            ProfileLegacyDomain.values.any((d) => d.name == entry.key) &&
            entry.value is String)) {
      throw const FormatException('Invalid profile account envelope');
    }
    return root;
  }

  Map<String, dynamic> _account(Map<String, dynamic> root, String owner) {
    final account = (root['accounts'] as Map<String, dynamic>)[owner];
    if (account == null) return {};
    if (account is! Map<String, dynamic> || account['owner'] != owner ||
        account['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile account owner');
    }
    final data = Map<String, dynamic>.from(account['data']);
    _validate(data);
    return data;
  }

  Future<Map<String, dynamic>> read(ProfileAccountTicket expected) async {
    require(expected);
    final prefs = await SharedPreferences.getInstance();
    require(expected);
    return _account(_root(prefs), expected.scope);
  }

  Future<bool> hasLegacy(
    ProfileAccountTicket expected, ProfileLegacyDomain domain,
  ) async {
    require(expected);
    final prefs = await SharedPreferences.getInstance();
    require(expected);
    return (_root(prefs)['legacyOwners'] as Map)[domain.name] == null &&
        domains[domain]!.any(prefs.containsKey);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = (_writes ?? Future<void>.value()).then((_) => operation());
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }
    tail = result.then<void>(
      (_) => release(),
      onError: (Object error, StackTrace stack) => release(),
    );
    _writes = tail;
    return result;
  }

  Future<void> _commit(SharedPreferences prefs, Map<String, dynamic> root,
      ProfileAccountTicket expected) async {
    require(expected);
    bool written;
    try {
      final raw = jsonEncode(root);
      final persist = _persist;
      written = await (persist == null
          ? prefs.setString(storageKey, raw) : persist(storageKey, raw));
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    if (!written) {
      await prefs.reload();
      throw StateError('Could not persist account profile');
    }
    require(expected);
    notifyListeners();
  }

  Future<void> update(ProfileAccountTicket expected,
      void Function(Map<String, dynamic>) change) => _serialize(() async {
    require(expected);
    final prefs = await SharedPreferences.getInstance();
    require(expected);
    final root = _root(prefs);
    final data = _account(root, expected.scope);
    change(data);
    _validate(data);
    (root['accounts'] as Map<String, dynamic>)[expected.scope] = {
      'owner': expected.scope, 'data': data,
    };
    await _commit(prefs, root, expected);
  });

  Future<void> write(ProfileAccountTicket expected, Map<String, dynamic> values) {
    final snapshot = jsonDecode(jsonEncode(values)) as Map<String, dynamic>;
    _validate(snapshot);
    return update(expected, (data) => data.addAll(snapshot));
  }

  Future<void> claim(ProfileAccountTicket expected,
      ProfileLegacyDomain domain, {
      required Future<bool> Function() confirmOwnership,
  }) async {
    require(expected);
    if (expected.scope == 'guest') throw StateError('Sign in to claim local data');
    if (!await confirmOwnership()) return;
    require(expected);
    await _serialize(() async {
      require(expected);
      final prefs = await SharedPreferences.getInstance();
      require(expected);
      final root = _root(prefs);
      final owners = root['legacyOwners'] as Map<String, dynamic>;
      if (owners[domain.name] != null) {
        throw StateError('Legacy data already assigned');
      }
      final data = _account(root, expected.scope);
      final keys = domains[domain]!;
      if (keys.any(data.containsKey)) {
        throw StateError('Account data already exists; claim would overwrite it');
      }
      final legacy = <String, dynamic>{
        for (final key in keys)
          if (prefs.containsKey(key)) key: prefs.get(key),
      };
      if (legacy.isEmpty) throw StateError('No unassigned local data');
      _validate(legacy);
      data.addAll(legacy);
      owners[domain.name] = expected.scope;
      (root['accounts'] as Map<String, dynamic>)[expected.scope] = {
        'owner': expected.scope, 'data': data,
      };
      await _commit(prefs, root, expected);
    });
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(synchronize);
    super.dispose();
  }
}
