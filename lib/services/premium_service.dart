import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/monetization_config.dart';

/// Subscription-Tier des Nutzers.
enum PremiumTier {
  free,
  premium,
  provider, // Anbieter-Paket (Theater, Vereine, Familienzentren)
}

/// Zentrale Premium-Verwaltung.
///
/// Prüft ob der Nutzer Premium hat, speichert den Status lokal,
/// und steuert alle Gates (Events-Limit, Ads, KI-Limit).
///
/// In der Beta: Jeder ist "premium" (alle Limits deaktiviert).
/// Nach Beta: In-App Purchase Validierung hier anbinden.
class PremiumService {
  static final PremiumService instance = PremiumService._();
  PremiumService._();

  static const String _tierKey = 'premium.tier';
  static const String _expiresKey = 'premium.expires_at';
  static const String _promoCodeKey = 'premium.promo_code';

  PremiumTier _tier = PremiumTier.free;
  DateTime? _expiresAt;
  String? _activePromoCode;

  /// Aktueller Subscription-Tier
  PremiumTier get tier => _tier;

  /// Ist der Nutzer Premium (oder hat aktives Anbieter-Paket)?
  bool get isPremium {
    // Beta: Monetarisierung deaktiviert → alle sind "premium"
    if (!MonetizationConfig.enabled) return true;

    if (_tier == PremiumTier.free) return false;

    // Prüfe ob Abo abgelaufen ist
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) {
      _tier = PremiumTier.free;
      _expiresAt = null;
      _persist();
      return false;
    }

    return true;
  }

  /// Ist der Nutzer ein zahlender Anbieter?
  bool get isProvider => isPremium && _tier == PremiumTier.provider;

  /// Hat der Nutzer einen aktiven Promo-Code?
  bool get hasPromoCode => _activePromoCode != null;

  /// Sollen Ads angezeigt werden? (Nur für Free-Nutzer wenn Ads aktiv)
  bool get shouldShowAds =>
      MonetizationConfig.shouldShowAds && !isPremium;

  /// Soll das Events-Limit greifen?
  bool get shouldLimitEvents =>
      MonetizationConfig.enabled &&
      MonetizationConfig.eventsLimitEnabled &&
      !isPremium;

  /// Soll das KI-Chat-Limit greifen?
  bool get shouldLimitAiChat =>
      MonetizationConfig.enabled &&
      MonetizationConfig.aiChatLimitEnabled &&
      !isPremium;

  /// Soll das Rezept-Limit greifen?
  bool get shouldLimitRecipes =>
      MonetizationConfig.enabled &&
      MonetizationConfig.recipeLimitEnabled &&
      !isPremium;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Initialisiere aus SharedPreferences (bei App-Start aufrufen)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final tierStr = prefs.getString(_tierKey);
    _tier = _parseTier(tierStr);

    final expiresMillis = prefs.getInt(_expiresKey);
    if (expiresMillis != null) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresMillis);
    }

    _activePromoCode = prefs.getString(_promoCodeKey);

    debugPrint('PremiumService: tier=$_tier, expires=$_expiresAt, '
        'isPremium=$isPremium');
  }

  // ─── Subscription Management ─────────────────────────────────────────────

  /// Aktiviere Premium (nach In-App Purchase Validierung)
  Future<void> activatePremium({
    required Duration duration,
    PremiumTier tier = PremiumTier.premium,
  }) async {
    _tier = tier;
    _expiresAt = DateTime.now().add(duration);
    await _persist();
    debugPrint('PremiumService: Premium aktiviert bis $_expiresAt');
  }

  /// Aktiviere mit Promo-Code (z.B. für Beta-Tester, Freunde)
  Future<bool> redeemPromoCode(String code) async {
    final validCodes = _getValidPromoCodes();
    if (!validCodes.containsKey(code.trim().toUpperCase())) {
      return false;
    }

    final days = validCodes[code.trim().toUpperCase()]!;
    _activePromoCode = code.trim().toUpperCase();
    await activatePremium(duration: Duration(days: days));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promoCodeKey, _activePromoCode!);

    debugPrint('PremiumService: Promo-Code "$code" eingelöst ($days Tage)');
    return true;
  }

  /// Premium deaktivieren (z.B. wenn Abo gekündigt wird)
  Future<void> deactivate() async {
    _tier = PremiumTier.free;
    _expiresAt = null;
    _activePromoCode = null;
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_promoCodeKey);
  }

  /// Verbleibende Premium-Tage (für Anzeige)
  int get remainingDays {
    if (_expiresAt == null) return 0;
    final diff = _expiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  // ─── Promo-Codes ─────────────────────────────────────────────────────────

  /// Gültige Promo-Codes → Tage Premium
  /// Später: aus Backend laden statt hardcoded
  Map<String, int> _getValidPromoCodes() {
    return {
      'BETAFAMILY': 90, // 3 Monate für Beta-Tester
      'PARENTPEAK2026': 30, // 1 Monat Launch-Promo
      'FRIENDS50': 60, // 2 Monate für Freunde
      'EARLYBIRD': 365, // 1 Jahr für Early Adopters
    };
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, _tier.name);
    if (_expiresAt != null) {
      await prefs.setInt(_expiresKey, _expiresAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_expiresKey);
    }
  }

  PremiumTier _parseTier(String? str) {
    switch (str) {
      case 'premium':
        return PremiumTier.premium;
      case 'provider':
        return PremiumTier.provider;
      default:
        return PremiumTier.free;
    }
  }
}
