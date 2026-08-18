/// Zentrale Monetarisierungs-Konfiguration für Parentpeak.
///
/// Alle Feature-Flags hier. Für Beta: alles `false`.
/// Nach Beta: Schalter umlegen → Monetarisierung aktiv.
class MonetizationConfig {
  MonetizationConfig._();

  // ─── Master-Schalter ──────────────────────────────────────────────────────

  /// Monetarisierung global an/aus. Wenn false → alles kostenlos, keine Ads.
  static const bool enabled = false;

  // ─── Premium ──────────────────────────────────────────────────────────────

  /// Premium-Subscription anbieten (In-App Purchase)
  static const bool premiumEnabled = false;

  /// Monatspreis (nur für Anzeige — echter Preis kommt von App Store)
  static const double premiumMonthlyPrice = 3.99;

  /// Jahrespreis
  static const double premiumYearlyPrice = 34.99;

  /// Premium Product IDs (Apple App Store / Google Play)
  static const String premiumMonthlyProductId = 'parentpeak_premium_monthly';
  static const String premiumYearlyProductId = 'parentpeak_premium_yearly';

  // ─── Werbung (Ads) ────────────────────────────────────────────────────────

  /// Native Ads zwischen Content anzeigen (für Free-Nutzer)
  static const bool adsEnabled = false;

  /// Wie viele echte Items zwischen Ads (1 Ad pro N Items)
  static const int adFrequency = 5;

  /// AdMob Unit IDs (Test-IDs für Entwicklung, echte nach Beta)
  static const String adMobNativeAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/2247696110'; // Test
  static const String adMobNativeAdUnitIdIos =
      'ca-app-pub-3940256099942544/3986624511'; // Test
  static const String adMobNativeAdUnitIdWeb = ''; // Web: Self-Service only

  // ─── Events-Limit (Free-Nutzer) ──────────────────────────────────────────

  /// Events-Limit für Free-Nutzer aktivieren
  static const bool eventsLimitEnabled = false;

  /// Maximale Event-Detailansichten pro Woche (Free)
  static const int freeEventsPerWeek = 3;

  // ─── KI-Limit (Free-Nutzer) ──────────────────────────────────────────────

  /// KI-Chat Limit für Free-Nutzer
  static const bool aiChatLimitEnabled = false;

  /// Maximale KI-Fragen pro Tag (Free)
  static const int freeAiQuestionsPerDay = 3;

  // ─── Rezept-Limit (Free-Nutzer) ──────────────────────────────────────────

  /// Rezept-Generator Limit für Free-Nutzer
  static const bool recipeLimitEnabled = false;

  /// Maximale Rezepte pro Tag (Free)
  static const int freeRecipesPerDay = 1;

  // ─── Eltern-Netzwerk Limit (Free-Nutzer) ───────────────────────────────────

  /// Eltern-Netzwerk Kontaktanfragen-Limit für Free-Nutzer
  static const bool networkLimitEnabled = false;

  /// Maximale Kontaktanfragen pro Monat (Free)
  static const int freeNetworkContactsPerMonth = 3;

  // ─── Familien-Geld Limit (Free-Nutzer) ────────────────────────────────────

  /// Familien-Geld persönlicher Check nur für Premium
  static const bool financeCheckPremiumOnly = false;

  // ─── Anbieter-Paket ──────────────────────────────────────────────────────

  /// Anbieter-Paket (9,99€/Monat für Power-Poster)
  static const bool providerPackageEnabled = false;

  /// Kostenlose Events pro Monat für Anbieter
  static const int freeProviderEventsPerMonth = 3;

  /// Anbieter-Paket Monatspreis
  static const double providerMonthlyPrice = 6.99;

  static const String providerPackageProductId = 'parentpeak_provider_monthly';

  // ─── Self-Service Ads Portal ─────────────────────────────────────────────

  /// Self-Service Ads (Anbieter buchen selbst)
  static const bool selfServiceAdsEnabled = false;

  /// Minimum Budget pro Tag in EUR
  static const double selfServiceMinDailyBudget = 1.0;

  // ─── Hilfs-Methoden ──────────────────────────────────────────────────────

  /// Prüft ob irgendein Limit aktiv ist (für UI-Hinweise)
  static bool get hasAnyLimits =>
      enabled &&
      (eventsLimitEnabled || aiChatLimitEnabled || recipeLimitEnabled);

  /// Prüft ob Werbung angezeigt werden soll
  static bool get shouldShowAds => enabled && adsEnabled;

  /// Prüft ob Premium-Upgrade angeboten werden soll
  static bool get shouldOfferPremium => enabled && premiumEnabled;
}
