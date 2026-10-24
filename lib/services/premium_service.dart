import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/logic/entitlement_service.dart';

enum PremiumTier { free, premium }

/// Compatibility facade for existing feature gates.
///
/// The entitlement snapshot is fetched and owned by [EntitlementService];
/// local preferences and promo codes are never a source of premium access.
class PremiumService {
  static final PremiumService instance = PremiumService._();
  PremiumService._();

  EntitlementService get _entitlements => EntitlementService.instance;

  PremiumTier? get tier {
    if (_entitlements.state != EntitlementState.verified) return null;
    return _entitlements.isPremium ? PremiumTier.premium : PremiumTier.free;
  }

  bool get isPremium => _entitlements.isPremium;

  bool get isProvider => false;

  bool get hasPromoCode => false;

  bool get shouldShowAds =>
      MonetizationConfig.shouldShowAds &&
      _entitlements.adsEligibleByEntitlement;

  bool get shouldLimitEvents =>
      MonetizationConfig.enabled &&
      MonetizationConfig.eventsLimitEnabled &&
      !isPremium;

  bool get shouldLimitAiChat =>
      MonetizationConfig.enabled &&
      MonetizationConfig.aiChatLimitEnabled &&
      !isPremium;

  bool get shouldLimitRecipes =>
      MonetizationConfig.enabled &&
      MonetizationConfig.recipeLimitEnabled &&
      !isPremium;

  Future<void> initialize() => _entitlements.initialize();

  @Deprecated('Premium can only be activated by future server verification.')
  Future<void> activatePremium({
    required Duration duration,
    PremiumTier tier = PremiumTier.premium,
  }) async {
    await _entitlements.refreshEntitlements();
  }

  @Deprecated('Local promo codes are no longer an entitlement source.')
  Future<bool> redeemPromoCode(String code) async => false;

  Future<void> deactivate() => _entitlements.refreshEntitlements();

  int get remainingDays {
    final validUntil = _entitlements.snapshot.validUntil;
    if (!_entitlements.isPremium || validUntil == null) return 0;
    final days = validUntil.difference(DateTime.now().toUtc()).inDays;
    return days > 0 ? days : 0;
  }
}
