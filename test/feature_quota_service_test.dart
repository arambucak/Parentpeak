import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/services/feature_quota_service.dart';
import 'package:parentpeak/ui/widgets/feature_quota_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> status(
        {bool enabled = true,
        bool premium = false,
        int recipes = 1,
        int chat = 3}) =>
    {
      'enabled': enabled,
      'tier': premium ? 'premium' : 'free',
      'serverTime': '2026-11-05T23:59:59Z',
      'items': {
        'chat': {'remaining': chat},
        'recipes': {'remaining': recipes},
        'events': {'remaining': 3},
        'contacts': {'remaining': 3},
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('server status, not device preferences, controls access and resets',
      () async {
    SharedPreferences.setMockInitialValues({
      'ai_rate.date': '2099-01-01',
      'ai_rate.daily_count': 0,
      'events_limit.view_count': 0,
    });
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    final service = FeatureQuotaService(
        accounts: accounts,
        apiClient: BackendApiClient(
            baseUrl: 'https://quota.example.test',
            httpClient: MockClient(
                (_) async => http.Response(jsonEncode(status(chat: 0)), 200))));
    await expectLater(service.check(QuotaFeature.chat),
        throwsA(isA<FeatureQuotaException>()));
    expect((await service.status()).serverTime,
        DateTime.utc(2026, 11, 5, 23, 59, 59));
    SharedPreferences.setMockInitialValues({});
    await expectLater(service.check(QuotaFeature.chat),
        throwsA(isA<FeatureQuotaException>()));
  });

  test(
      'account switch between status and reservation cannot charge the new UID',
      () async {
    var uid = 'a';
    var reservations = 0;
    final accounts = ProfileAccountStore(userIdProvider: () => uid);
    addTearDown(accounts.dispose);
    final reply = Completer<http.Response>();
    final service = FeatureQuotaService(
        accounts: accounts,
        apiClient: BackendApiClient(
            baseUrl: 'https://quota.example.test',
            httpClient: MockClient((request) {
              if (request.url.path == '/usage/me') return reply.future;
              reservations++;
              return Future.value(
                  http.Response('{"receipt":"unexpected"}', 200));
            })));
    final pending = service.reserveRecipe();
    final assertion =
        expectLater(pending, throwsA(isA<ProfileAccountChanged>()));
    uid = 'b';
    accounts.synchronize();
    reply.complete(http.Response(jsonEncode(status()), 200));
    await assertion;
    expect(reservations, 0);
  });

  test('backend failure does not turn into unlimited or a local fallback grant',
      () async {
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    final service = FeatureQuotaService(
        accounts: accounts,
        apiClient: BackendApiClient(
            baseUrl: 'https://quota.example.test',
            httpClient: MockClient((_) async =>
                http.Response('{"code":"feature_access_unavailable"}', 503))));
    await expectLater(
        service.reserveRecipe(), throwsA(isA<BackendApiException>()));
  });

  test('Premium and disabled rollout do not enforce Free client allowances',
      () async {
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    for (final data in [
      status(premium: true, chat: 0),
      status(enabled: false, chat: 0)
    ]) {
      final service = FeatureQuotaService(
          accounts: accounts,
          apiClient: BackendApiClient(
              baseUrl: 'https://quota.example.test',
              httpClient: MockClient(
                  (_) async => http.Response(jsonEncode(data), 200))));
      await service.check(QuotaFeature.chat);
    }
  });

  test(
      'local fallback reserves one recipe, shared across devices; reopening is free',
      () async {
    var reserved = 0;
    Map<String, dynamic>? saved;
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    final api = BackendApiClient(
        baseUrl: 'https://quota.example.test',
        httpClient: MockClient((request) async {
          switch (request.url.path) {
            case '/usage/me':
              return http.Response(
                  jsonEncode(status(recipes: reserved == 0 ? 1 : 0)), 200);
            case '/usage/recipes/reserve':
              if (reserved > 0) {
                return http.Response('{"code":"feature_limit_reached"}', 429);
              }
              reserved++;
              return http.Response('{"receipt":"server-receipt"}', 200);
            case '/usage/recipes/server-receipt/result':
              saved = (jsonDecode(request.body) as Map<String, dynamic>)['item']
                  as Map<String, dynamic>;
              return http.Response('{"ok":true}', 200);
            case '/usage/recipes/today':
              return http.Response(jsonEncode({'item': saved}), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            default:
              throw StateError('Unexpected request: ${request.url.path}');
          }
        }));
    final consent = FamilyRecipeConsent(scopeProvider: () => 'account.a');
    final firstDevice = FamilyRecipeService(
        consent: consent,
        quotas: FeatureQuotaService(apiClient: api, accounts: accounts));
    final secondDevice = FamilyRecipeService(
        consent: consent,
        quotas: FeatureQuotaService(apiClient: api, accounts: accounts));
    await firstDevice.initialize();
    await secondDevice.initialize();
    final firstRecipe = await firstDevice.localRecipe();
    expect(firstRecipe, isNotNull);
    expect(reserved, 1);
    final reopened = await secondDevice.loadTodayRecipe();
    expect(reopened?.title, firstRecipe!.title);
    expect(reserved, 1);
    await expectLater(
        secondDevice.localRecipe(), throwsA(isA<FeatureQuotaException>()));
    expect(reserved, 1);
  });

  testWidgets(
      'quota gate hides protected content and offers warm Premium notice',
      (tester) async {
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    final service = FeatureQuotaService(
        accounts: accounts,
        apiClient: BackendApiClient(
            baseUrl: 'https://quota.example.test',
            httpClient: MockClient((request) async =>
                request.url.path == '/usage/me'
                    ? http.Response(jsonEncode(status()), 200)
                    : http.Response('{"code":"feature_limit_reached"}', 429))));
    await tester.pumpWidget(MaterialApp(
        home: FeatureQuotaGate(
      feature: QuotaFeature.events,
      eventKey: 'community:e4',
      service: service,
      child: const Scaffold(body: Text('Protected details')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Protected details'), findsNothing);
    expect(find.text(AppStringsManager.getString('en', 'quota_free_stays')),
        findsOneWidget);
    expect(find.text(AppStringsManager.getString('en', 'quota_premium')),
        findsOneWidget);
  });

  test('Free app entry is not blocked after a trial expires', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('if (!user.hasFullAccess)')));
    expect(source, isNot(contains('return PaywallScreen(')));
  });

  test('all eight launch languages contain warm notices for every feature', () {
    for (final language in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
      for (final feature in QuotaFeature.values) {
        final key = 'quota_${feature.name}';
        expect(AppStringsManager.allStrings[language]![key], isNotNull,
            reason: '$language/$key');
      }
    }
  });
}
