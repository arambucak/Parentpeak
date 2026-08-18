import 'package:flutter/material.dart';
import 'package:parentpeak/services/premium_service.dart';
import 'package:parentpeak/config/monetization_config.dart';

/// Native Ad Slot — wird zwischen Content-Items angezeigt.
///
/// Zeigt Werbung NUR wenn:
/// - MonetizationConfig.adsEnabled == true
/// - Nutzer KEIN Premium hat
///
/// Aktuell: Platzhalter-Widget (nach Beta: AdMob SDK einbinden).
/// Design: Sieht aus wie ein Content-Item, aber mit "Anzeige"-Label.
class NativeAdSlot extends StatelessWidget {
  const NativeAdSlot({super.key, this.context_hint});

  /// Kontext-Hinweis für Targeting (z.B. "events", "recipes", "market")
  final String? context_hint;

  @override
  Widget build(BuildContext context) {
    // Nicht anzeigen wenn Monetarisierung aus oder Nutzer Premium
    if (!PremiumService.instance.shouldShowAds) {
      return const SizedBox.shrink();
    }

    // Platzhalter — nach Beta durch echte AdMob Native Ad ersetzen
    return _PlaceholderAd(contextHint: context_hint);
  }

  /// Helper: Soll an dieser Position im Feed eine Ad erscheinen?
  /// Aufruf: `if (NativeAdSlot.shouldInsertAt(index)) ...`
  static bool shouldInsertAt(int index) {
    if (!MonetizationConfig.shouldShowAds) return false;
    if (PremiumService.instance.isPremium) return false;
    // Erste Ad nach 3 Items, danach alle N Items
    if (index < 3) return false;
    return (index - 3) % MonetizationConfig.adFrequency == 0;
  }
}

/// Platzhalter-Widget das wie eine Native Ad aussieht.
/// Wird nach Beta durch echte AdMob-Integration ersetzt.
class _PlaceholderAd extends StatelessWidget {
  const _PlaceholderAd({this.contextHint});

  final String? contextHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Anzeige"-Label
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Anzeige',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSecondaryContainer,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.more_horiz_rounded,
                  size: 16, color: theme.colorScheme.outline),
            ],
          ),
          const SizedBox(height: 10),
          // Platzhalter-Content
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 140,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
