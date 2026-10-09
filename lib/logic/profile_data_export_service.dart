import 'dart:convert';

import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileExportSignInRequired implements Exception {
  const ProfileExportSignInRequired();

  @override
  String toString() => 'Sign in to export account data.';
}

class ProfileDataExportService {
  ProfileDataExportService({
    ProfileAccountStore? accounts,
    Future<SharedPreferences> Function()? preferences,
  }) : _accounts = accounts ?? ProfileAccountStore.instance,
       _preferences = preferences ?? SharedPreferences.getInstance;

  final ProfileAccountStore _accounts;
  final Future<SharedPreferences> Function() _preferences;

  static const _accountDataEnvelopes = {
    'chat.accounts.v1': 'topics',
    'familyhub.accounts.v1': 'data',
    'famgeld.accounts.v1': 'data',
    'treasure.accounts.v1': 'data',
  };

  static const _scopedPreferencePrefixes = [
    'chat.ai_consent.v1',
    'chat.memory_consent.v1',
    'dev.ai_report_consent.v1',
    'dev.ai_report.v4',
    'dev.report_history.v2',
    'famgeld.ai_guide_consent.v1',
    'familykueche.ai_recipe_consent.v1',
    'fridge.ai_photo_consent.v1',
    'treasure.ai_photo_consent.v1',
  ];

  Future<Map<String, dynamic>> collectLocalData(
    ProfileAccountTicket ticket,
  ) async {
    _accounts.require(ticket);
    if (ticket.scope == 'guest' ||
        _accounts.userId?.trim().isNotEmpty != true) {
      throw const ProfileExportSignInRequired();
    }
    final prefs = await _preferences();
    _accounts.require(ticket);

    final envelopes = <String, dynamic>{
      'profile': await _accounts.read(ticket),
    };
    for (final entry in _accountDataEnvelopes.entries) {
      final ownerData = _readEnvelope(
        prefs.getString(entry.key),
        entry.key,
        ticket.scope,
        entry.value,
      );
      if (ownerData.isNotEmpty) envelopes[entry.key] = ownerData;
    }

    final scoped = <String, dynamic>{};
    final accountSuffix = '.${ticket.scope}';
    final scoredHistoryPrefix = 'dev.score_history.v2.${ticket.scope}.';
    final exactKeys = {
      for (final prefix in _scopedPreferencePrefixes) '$prefix$accountSuffix',
    };
    for (final key in prefs.getKeys()) {
      if (exactKeys.contains(key) || key.startsWith(scoredHistoryPrefix)) {
        final value = prefs.get(key);
        if (value is String) {
          try {
            scoped[key] = jsonDecode(value);
          } on FormatException {
            scoped[key] = value;
          }
        } else {
          scoped[key] = value;
        }
      }
    }

    final matchingKey = 'spielfreunde.profile$accountSuffix';
    final matchingRaw = prefs.getString(matchingKey);
    if (matchingRaw != null) {
      final matching = jsonDecode(matchingRaw);
      if (matching is! Map<String, dynamic> ||
          matching['ownerUserId'] != _accounts.userId ||
          matching['profile'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid account matching profile');
      }
      envelopes['parentMatchingProfile'] = matching['profile'];
    }

    _accounts.require(ticket);
    return {
      'owner': ticket.scope,
      'accountData': envelopes,
      'accountPreferences': scoped,
    };
  }

  Map<String, dynamic> _readEnvelope(
    String? raw,
    String key,
    String owner,
    String dataField,
  ) {
    if (raw == null) return {};
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> ||
        root['accounts'] is! Map<String, dynamic>) {
      throw FormatException('Invalid local account envelope: $key');
    }
    final account = (root['accounts'] as Map<String, dynamic>)[owner];
    if (account == null) return {};
    if (account is! Map<String, dynamic> ||
        account['owner'] != owner ||
        account[dataField] is! Map<String, dynamic>) {
      throw FormatException('Invalid local account owner: $key');
    }
    return Map<String, dynamic>.from(account[dataField] as Map);
  }
}
