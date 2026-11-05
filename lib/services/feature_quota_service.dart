import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/profile_account_store.dart';

enum QuotaFeature { chat, recipes, events, contacts, finance }

class FeatureQuotaException implements Exception {
  const FeatureQuotaException(this.feature, this.code);
  final QuotaFeature feature;
  final String code;

  static FeatureQuotaException? fromBackend(BackendApiException error) {
    if (!['feature_limit_reached', 'feature_premium_required']
        .contains(error.serverCode)) {
      return null;
    }
    final feature = error.path.contains('recipe')
        ? QuotaFeature.recipes
        : error.path.contains('finance')
            ? QuotaFeature.finance
            : error.path.contains('friend') || error.path.contains('matching')
                ? QuotaFeature.contacts
                : QuotaFeature.chat;
    return FeatureQuotaException(feature, error.serverCode!);
  }
}

class FeatureQuotaStatus {
  FeatureQuotaStatus.fromJson(Map<String, dynamic> json)
      : enabled = json['enabled'] as bool,
        premium = switch (json['tier']) {
          'premium' => true,
          'free' => false,
          _ => throw const FormatException('Invalid entitlement tier'),
        },
        serverTime = DateTime.parse(json['serverTime'] as String).toUtc(),
        items = Map<String, dynamic>.from(json['items'] as Map);
  final bool enabled;
  final bool premium;
  final DateTime serverTime;
  final Map<String, dynamic> items;

  int? remaining(QuotaFeature feature) {
    if (!enabled || premium) return null;
    final item = items[feature.name];
    if (item is! Map ||
        item['remaining'] is! int ||
        (item['remaining'] as int) < 0) {
      throw const FormatException('Invalid quota remaining');
    }
    return item['remaining'] as int;
  }
}

class FeatureQuotaService {
  FeatureQuotaService(
      {BackendApiClient? apiClient, ProfileAccountStore? accounts})
      : _apiClient = apiClient,
        _accounts = accounts ?? ProfileAccountStore.instance;
  static final instance = FeatureQuotaService();
  @visibleForTesting
  static BackendApiClient? Function() apiClientFactory =
      BackendServiceFactory.createVerifiedApiClient;
  final BackendApiClient? _apiClient;
  final ProfileAccountStore _accounts;

  BackendApiClient _client(ProfileAccountTicket ticket) {
    _accounts.require(ticket);
    final client = _apiClient ?? apiClientFactory();
    if (client == null) throw StateError('Feature access API unavailable');
    return client.withRequestGuard(() => _accounts.require(ticket));
  }

  Future<T> _request<T>(
      QuotaFeature feature, Future<T> Function() operation) async {
    try {
      return await operation();
    } on BackendApiException catch (error) {
      final quota = FeatureQuotaException.fromBackend(error);
      if (quota != null) throw FeatureQuotaException(feature, quota.code);
      debugPrint('Feature access failed: ${error.statusCode}');
      rethrow;
    }
  }

  Future<FeatureQuotaStatus> status() => _status(_accounts.ticket);

  Future<FeatureQuotaStatus> _status(ProfileAccountTicket ticket) async {
    final data = await _client(ticket).getJson('/usage/me');
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid feature access status');
    }
    return FeatureQuotaStatus.fromJson(data);
  }

  Future<void> check(QuotaFeature feature) async {
    final current = await status();
    if (!current.enabled || current.premium) return;
    if (feature == QuotaFeature.finance) {
      throw const FeatureQuotaException(
          QuotaFeature.finance, 'feature_premium_required');
    }
    if (current.remaining(feature) == 0) {
      throw FeatureQuotaException(feature, 'feature_limit_reached');
    }
  }

  Future<void> viewEvent(String key) async {
    final ticket = _accounts.ticket;
    if (!(await _status(ticket)).enabled) return;
    await _request(
        QuotaFeature.events,
        () => _client(ticket).postJson(
              '/usage/events/view',
              {'eventKey': key},
            ));
  }

  Future<void> financeAccess() async {
    final ticket = _accounts.ticket;
    if (!(await _status(ticket)).enabled) return;
    await _request(QuotaFeature.finance,
        () => _client(ticket).getJson('/usage/finance/access'));
  }

  Future<String?> reserveRecipe() async {
    final ticket = _accounts.ticket;
    if (!(await _status(ticket)).enabled) return null;
    return _request(QuotaFeature.recipes, () async {
      final data = await _client(ticket).postJson('/usage/recipes/reserve', {});
      if (data['receipt'] is! String) {
        throw const FormatException('Invalid recipe reservation');
      }
      return data['receipt'] as String;
    });
  }

  Future<Map<String, dynamic>?> todayRecipe() async {
    final ticket = _accounts.ticket;
    final current = await _status(ticket);
    if (!current.enabled || current.premium) return null;
    final data = await _client(ticket).getJson('/usage/recipes/today');
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid daily recipe response');
    }
    final item = data['item'];
    if (item == null) return null;
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Invalid daily recipe');
    }
    return item;
  }

  Future<void> saveRecipe(String? receipt, Map<String, dynamic> recipe) async {
    if (receipt == null) return;
    final ticket = _accounts.ticket;
    await _request(
        QuotaFeature.recipes,
        () => _client(ticket).putJson(
              '/usage/recipes/$receipt/result',
              {'item': recipe},
            ));
  }
}
