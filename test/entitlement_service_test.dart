import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/entitlement_service.dart';
import 'package:parentpeak/services/events_limit_service.dart';
import 'package:parentpeak/services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> entitlementResponse({
  required String tier,
  required String access,
  DateTime? validFrom,
  DateTime? validUntil,
  DateTime? verifiedAt,
  bool adsEligible = false,
}) =>
    {
      'item': {
        'state': 'verified',
        'tier': tier,
        'access': access,
        'validFrom': validFrom?.toUtc().toIso8601String(),
        'validUntil': validUntil?.toUtc().toIso8601String(),
        'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
        'adsEligibleByEntitlement': adsEligible,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EntitlementService.instance;
  late BackendApiClient? Function() originalApiClientFactory;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalApiClientFactory = EntitlementService.apiClientFactory;
    service.resetForLogout();
  });

  tearDown(() {
    EntitlementService.apiClientFactory = originalApiClientFactory;
    service.resetForLogout();
  });

  BackendApiClient apiClient(http.Response response) => BackendApiClient(
        baseUrl: 'https://backend.example.test',
        authToken: 'test-token',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/entitlements/me');
          return response;
        }),
      );

  test('verified server snapshot can grant premium only with a valid period',
      () async {
    final now = DateTime.now().toUtc();
    EntitlementService.apiClientFactory = () => apiClient(http.Response(
          jsonEncode(entitlementResponse(
            tier: 'premium',
            access: 'active',
            validFrom: now.subtract(const Duration(days: 1)),
            validUntil: now.add(const Duration(days: 30)),
            verifiedAt: now,
          )),
          200,
        ));

    await service.refreshEntitlements();

    expect(service.state, EntitlementState.verified);
    expect(service.currentTier, SubscriptionTier.premium);
    expect(service.isPremium, isTrue);
    expect(service.isFree, isFalse);
    expect(service.adsEligibleByEntitlement, isFalse);
  });

  test('offline/server failure stays unavailable, never free or ad eligible',
      () async {
    EntitlementService.apiClientFactory =
        () => apiClient(http.Response('{}', 503));

    await service.refreshEntitlements();

    expect(service.state, EntitlementState.unavailable);
    expect(service.currentTier, isNull);
    expect(service.isPremium, isFalse);
    expect(service.isFree, isFalse);
    expect(service.adsEligibleByEntitlement, isFalse);
    expect(PremiumService.instance.shouldShowAds, isFalse);
  });

  test('legacy local premium and promo preferences cannot override server Free',
      () async {
    SharedPreferences.setMockInitialValues({
      'premium.tier': 'premium',
      'premium.expires_at':
          DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
      'premium.promo_code': 'BETAFAMILY',
    });
    EntitlementService.apiClientFactory = () => apiClient(http.Response(
          jsonEncode(entitlementResponse(tier: 'free', access: 'none')),
          200,
        ));

    await PremiumService.instance.initialize();

    expect(service.state, EntitlementState.verified);
    expect(service.isFree, isTrue);
    expect(PremiumService.instance.isPremium, isFalse);
    expect(PremiumService.instance.hasPromoCode, isFalse);
    expect(
      ParentUser.fromJson({
        'uid': 'a',
        'email': 'a@example.test',
        'displayName': 'A',
        'registeredAt': DateTime(2026).toIso8601String(),
        'isPremium': true,
      }).isPremium,
      isFalse,
    );
  });

  test('local activation and promo-code entry cannot grant premium', () async {
    EntitlementService.apiClientFactory = () => apiClient(http.Response(
          jsonEncode(entitlementResponse(tier: 'free', access: 'none')),
          200,
        ));

    await PremiumService.instance.activatePremium(
      duration: const Duration(days: 365),
    );
    final promoAccepted =
        await PremiumService.instance.redeemPromoCode('BETAFAMILY');

    expect(promoAccepted, isFalse);
    expect(service.isFree, isTrue);
    expect(PremiumService.instance.isPremium, isFalse);
  });

  test('malformed and expired premium responses fail closed', () {
    final now = DateTime.now().toUtc();
    for (final response in [
      {
        'state': 'verified',
        'tier': 'premium',
        'access': 'active',
        'validFrom': now.subtract(const Duration(days: 2)).toIso8601String(),
        'validUntil':
            now.subtract(const Duration(seconds: 1)).toIso8601String(),
        'verifiedAt': now.toIso8601String(),
        'adsEligibleByEntitlement': false,
      },
      {
        'state': 'verified',
        'tier': 'premium',
        'access': 'active',
        'validFrom': null,
        'validUntil': null,
        'verifiedAt': now.toIso8601String(),
        'adsEligibleByEntitlement': false,
      },
    ]) {
      expect(
        () => EntitlementSnapshot.fromJson(response),
        throwsFormatException,
      );
    }
  });

  test(
      'weekly event limit remains three, Monday reset and disabled flags unchanged',
      () async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    SharedPreferences.setMockInitialValues({
      'events_limit.view_count': 2,
      'events_limit.week_start':
          monday.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
    });
    final limit = EventsLimitService.instance;

    expect(MonetizationConfig.freeEventsPerWeek, 3);
    expect(MonetizationConfig.eventsLimitEnabled, isFalse);
    expect(limit.weeklyLimit, 3);
    await limit.initialize();
    expect(limit.viewCount, 0);
    expect(limit.isLimitActive, isFalse);
    expect(await limit.recordEventView(), isTrue);
    expect(limit.viewCount, 0);
    final source =
        File('lib/services/events_limit_service.dart').readAsStringSync();
    expect(
        source,
        contains(
            'if (_weekStart == null || currentWeekStart.isAfter(_weekStart!))'));
    expect(source, contains('final daysToSubtract = date.weekday - 1;'));
    expect(source, contains('if (_viewCount >= weeklyLimit)'));
    expect(source, contains('return false; // Limit erreicht'));
    expect(source, contains('_viewCount++;'));
  });
}
