import 'dart:convert';

import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/finance_number.dart';

/// Financial ownership is independent of the family hub's legacy claim.
/// The envelope provides account isolation, not encryption or synchronization.
class FamilyFinanceStore {
  FamilyFinanceStore({
    String? Function()? userIdProvider,
    Future<bool> Function(String key, String value)? persist,
  }) : _userIdProvider = userIdProvider ??
            (() => AuthService.instance.currentUser?.uid),
       _persist = persist;

  static final instance = FamilyFinanceStore();
  static const storageKey = 'famgeld.accounts.v1';
  static const countryKey = 'famgeld.country';
  static const amountsKey = 'famgeld.amounts';
  static const eligibilityKey = 'famgeld.eligibility_done';
  static const employeeKey = 'famgeld.is_employee';
  static const singleParentKey = 'famgeld.is_single_parent';
  static const incomeKey = 'famgeld.income_level';
  static const savingsGoalKey = 'famgeld.monthly_savings_goal';
  static const savedKey = 'famgeld.total_saved';
  static const countriesKey = 'famgeld.countries.v1';
  static const countryValueKeys = [
    amountsKey, eligibilityKey, employeeKey, singleParentKey,
    incomeKey, savingsGoalKey, savedKey,
  ];
  static const valueKeys = [
    countryKey, amountsKey, eligibilityKey, employeeKey, singleParentKey,
    incomeKey, savingsGoalKey, savedKey,
  ];
  static Future<void> _writes = Future<void>.value();

  final String? Function() _userIdProvider;
  final Future<bool> Function(String key, String value)? _persist;
  String? get userId => _userIdProvider();
  String get scope {
    final uid = userId;
    return uid == null ? 'guest' : 'account.${Uri.encodeComponent(uid)}';
  }

  void requireScope(String expected) {
    if (scope != expected) throw const FamilyHubAccountChanged();
  }

  static String guideKey(String country) => 'benefitguide.checklist.$country.v1';
  static String documentsKey(String benefit) => 'antragshelfer.$benefit.docs';
  static bool _isChecklist(String key) =>
      RegExp(r'^benefitguide\.checklist\.[^.]+\.v1$').hasMatch(key) ||
      RegExp(r'^antragshelfer\.[^.]+\.docs$').hasMatch(key);
  static bool _isDataKey(String key) => valueKeys.contains(key) || _isChecklist(key);
  static bool isCountry(Object? value) => value is String &&
      CountryFinanceData.availableCountries.any((country) => country.code == value);

  Map<String, dynamic> _decode(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null) return {'accounts': <String, dynamic>{}};
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> ||
        root['accounts'] is! Map<String, dynamic> ||
        (root['legacyOwner'] != null && root['legacyOwner'] is! String)) {
      throw const FormatException('Invalid finance account envelope');
    }
    return root;
  }

  Map<String, dynamic> _validate(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      final valid = switch (key) {
        countryKey => isCountry(value),
        countriesKey => value is Map<String, dynamic> &&
            value.entries.every((entry) => isCountry(entry.key) &&
                entry.value is Map<String, dynamic> &&
                (entry.value as Map<String, dynamic>).keys.every(countryValueKeys.contains) &&
                _validCountryValues(entry.value as Map<String, dynamic>)),
        amountsKey => value is Map<String, dynamic> &&
            value.values.every(FinanceNumber.isValid),
        eligibilityKey || employeeKey || singleParentKey => value is bool,
        incomeKey => value is int && value >= 0 && value <= 2,
        savingsGoalKey || savedKey => FinanceNumber.isValid(value),
        _ => _isChecklist(key) && value is List &&
            value.every((item) => item is String),
      };
      if (!valid) throw FormatException('Invalid finance data: $key');
    }
    return data;
  }

  bool _validCountryValues(Map<String, dynamic> values) {
    _validate(values);
    return true;
  }

    Map<String, dynamic> _group(Map<String, dynamic> data) {
      final grouped = Map<String, dynamic>.from(data);
      final countries = Map<String, dynamic>.from(
        grouped[countriesKey] as Map<String, dynamic>? ?? {});
      final flat = <String, dynamic>{};
      for (final key in countryValueKeys) {
        if (grouped.containsKey(key)) flat[key] = grouped.remove(key);
      }
      if (flat.isNotEmpty) {
        // Old account values without a selection used the screen's DE default.
        final country = grouped[countryKey] as String? ?? 'de';
        grouped[countryKey] = country;
        countries[country] = {
          ...?countries[country] as Map<String, dynamic>?, ...flat,
        };
      }
      if (countries.isNotEmpty) grouped[countriesKey] = countries;
      return grouped;
    }

    Map<String, dynamic> _view(Map<String, dynamic> data) {
      final grouped = _group(data);
      final country = grouped[countryKey] as String? ?? 'de';
      return {
        ...grouped,
        ...?(grouped[countriesKey] as Map<String, dynamic>?)?[country]
            as Map<String, dynamic>?,
      };
    }

  Map<String, dynamic> _account(Map<String, dynamic> root, String expected) {
    final account = (root['accounts'] as Map<String, dynamic>)[expected];
    if (account == null) return {};
    if (account is! Map<String, dynamic> ||
        account['owner'] != expected ||
        account['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid finance account owner');
    }
    return _validate(Map<String, dynamic>.from(account['data']));
  }

  Future<Map<String, dynamic>> read({required String expectedScope}) async {
    requireScope(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    return _view(_account(_decode(prefs), expectedScope));
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    // A rejected caller must not poison subsequent transactions.
    _writes = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return result;
  }

  Future<void> _commit(SharedPreferences prefs, Map<String, dynamic> root,
      String expected) async {
    requireScope(expected);
    final persist = _persist;
    bool written;
    try {
      final encoded = jsonEncode(root);
      written = persist == null
          ? await prefs.setString(storageKey, encoded)
          : await persist(storageKey, encoded);
    } catch (error) {
      await prefs.reload();
      rethrow;
    }
    if (!written) {
      await prefs.reload();
      throw StateError('Could not persist financial account data');
    }
    requireScope(expected);
  }

  Future<void> write(Map<String, dynamic> changes, {
    required String expectedScope, bool mergeAmounts = false,
  }) {
    requireScope(expectedScope);
    _validate(changes);
    final snapshot = _validate(
      jsonDecode(jsonEncode(changes)) as Map<String, dynamic>,
    );
    return _serialize(() async {
      requireScope(expectedScope);
      final prefs = await SharedPreferences.getInstance();
      requireScope(expectedScope);
      final root = _decode(prefs);
      final data = _group(_account(root, expectedScope));
      final country = snapshot[countryKey] as String? ??
          data[countryKey] as String? ?? 'de';
      final countryChanges = <String, dynamic>{
        for (final key in countryValueKeys)
          if (snapshot.containsKey(key)) key: snapshot[key],
      };
      if (countryChanges.isNotEmpty) {
        final countries = Map<String, dynamic>.from(
          data[countriesKey] as Map<String, dynamic>? ?? {});
        final values = <String, dynamic>{
          ...?countries[country] as Map<String, dynamic>?,
        };
        if (mergeAmounts && countryChanges.containsKey(amountsKey)) {
          countryChanges[amountsKey] = <String, dynamic>{
            ...?values[amountsKey] as Map<String, dynamic>?,
            ...countryChanges[amountsKey] as Map<String, dynamic>,
          };
        }
        countries[country] = values..addAll(countryChanges);
        data[countriesKey] = countries;
      }
      data.addAll({
        for (final entry in snapshot.entries)
          if (!countryValueKeys.contains(entry.key)) entry.key: entry.value,
      });
      (root['accounts'] as Map<String, dynamic>)[expectedScope] = {
        'owner': expectedScope, 'data': data,
      };
      await _commit(prefs, root, expectedScope);
    });
  }

  Future<bool> hasUnassignedLegacy({required String expectedScope}) async {
    requireScope(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    return _decode(prefs)['legacyOwner'] == null &&
        prefs.getKeys().any(_isDataKey);
  }

  Future<void> claimLegacy({required String expectedScope}) => _serialize(() async {
    requireScope(expectedScope);
    if (userId == null) throw StateError('Sign in to claim financial legacy data');
    final prefs = await SharedPreferences.getInstance();
    requireScope(expectedScope);
    final root = _decode(prefs);
    final owner = root['legacyOwner'];
    if (owner == expectedScope) return;
    if (owner != null) throw StateError('Financial legacy data already assigned');
    final legacy = <String, dynamic>{};
    for (final key in prefs.getKeys().where(_isDataKey)) {
      final value = prefs.get(key);
      legacy[key] = key == amountsKey && value is String ? jsonDecode(value) : value;
    }
    _validate(legacy);
    final data = _view(_account(root, expectedScope));
    final differentCountry = data.containsKey(countryKey) &&
        legacy.containsKey(countryKey) && data[countryKey] != legacy[countryKey];
    for (final entry in legacy.entries) {
      if (differentCountry &&
          [amountsKey, incomeKey, savingsGoalKey, savedKey].contains(entry.key)) {
        continue;
      }
      if (_isChecklist(entry.key)) {
        data[entry.key] = {
          ...?data[entry.key] as List?, ...entry.value as List,
        }.toList();
      } else if (entry.key == amountsKey && data.containsKey(amountsKey)) {
        data[amountsKey] = {
          ...entry.value as Map<String, dynamic>,
          ...data[amountsKey] as Map<String, dynamic>,
        };
      } else {
        // Existing account values win; the original legacy keys remain a backup.
        data.putIfAbsent(entry.key, () => entry.value);
      }
    }
    (root['accounts'] as Map<String, dynamic>)[expectedScope] = {
      'owner': expectedScope, 'data': _group(data),
    };
    root['legacyOwner'] = expectedScope;
    await _commit(prefs, root, expectedScope);
  });

  Future<Set<String>> loadChecklist(String key, {required String expectedScope}) async {
    if (!_isChecklist(key)) throw ArgumentError.value(key, 'key');
    final data = await read(expectedScope: expectedScope);
    return (data[key] as List? ?? const []).cast<String>().toSet();
  }

  Future<void> saveChecklist(String key, Set<String> items,
      {required String expectedScope}) {
    if (!_isChecklist(key)) throw ArgumentError.value(key, 'key');
    return write({key: items.toList()}, expectedScope: expectedScope);
  }
}
