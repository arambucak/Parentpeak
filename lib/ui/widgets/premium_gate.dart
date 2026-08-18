import 'package:flutter/material.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/services/premium_service.dart';
import 'package:parentpeak/services/events_limit_service.dart';

/// Premium-Gate Widget — zeigt Upgrade-Prompt wenn Limit erreicht.
///
/// Verwendung: Vor Event-Detail, KI-Chat, Rezept-Generator.
/// Zeigt nichts wenn Nutzer Premium hat oder Limits deaktiviert sind.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.child,
    this.featureLabel = 'dieses Feature',
    this.gateType = PremiumGateType.events,
  });

  /// Das Widget das angezeigt wird wenn KEIN Gate greift
  final Widget child;

  /// Label für das Feature (z.B. "Events", "KI-Beratung")
  final String featureLabel;

  /// Welches Limit wird geprüft?
  final PremiumGateType gateType;

  @override
  Widget build(BuildContext context) {
    // Kein Gate wenn Monetarisierung deaktiviert oder Nutzer Premium
    if (!MonetizationConfig.enabled || PremiumService.instance.isPremium) {
      return child;
    }

    final shouldBlock = _shouldBlock();
    if (!shouldBlock) return child;

    return _PremiumUpgradeOverlay(
      featureLabel: featureLabel,
      gateType: gateType,
    );
  }

  bool _shouldBlock() {
    switch (gateType) {
      case PremiumGateType.events:
        return EventsLimitService.instance.isLimitReached;
      case PremiumGateType.aiChat:
        // TODO: Implement AiChatLimitService
        return false;
      case PremiumGateType.recipes:
        // TODO: Implement RecipeLimitService
        return false;
    }
  }
}

enum PremiumGateType { events, aiChat, recipes }

/// Upgrade-Overlay das anstelle des geblockten Contents erscheint.
class _PremiumUpgradeOverlay extends StatelessWidget {
  const _PremiumUpgradeOverlay({
    required this.featureLabel,
    required this.gateType,
  });

  final String featureLabel;
  final PremiumGateType gateType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = EventsLimitService.instance.remaining;
    final limit = EventsLimitService.instance.weeklyLimit;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    const Color(0xFFEC4899).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 40,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 24),

            // Headline
            Text(
              'Du hast diese Woche $limit Events entdeckt!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Subtext
            Text(
              'Es gibt noch mehr tolle Angebote in deiner Nähe. '
              'Mit Premium siehst du alle — ohne Limit.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Premium-Button
            FilledButton.icon(
              onPressed: () => _showPremiumSheet(context),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Parentpeak Premium — 30 Tage kostenlos'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),

            // Promo-Code Link
            TextButton(
              onPressed: () => _showPromoCodeDialog(context),
              child: Text(
                'Promo-Code eingeben',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Counter
            if (remaining == 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nächste Woche: $limit neue Events kostenlos',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPremiumSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Parentpeak Premium',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alles was Eltern brauchen. Ohne Limits.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 28),
            _PremiumFeatureRow(
              icon: Icons.event_available_rounded,
              label: 'Unbegrenzte Events & Aktivitäten',
            ),
            _PremiumFeatureRow(
              icon: Icons.notifications_active_rounded,
              label: 'Push-Alert bei neuen Events in der Nähe',
            ),
            _PremiumFeatureRow(
              icon: Icons.auto_awesome_rounded,
              label: 'KI-Beratung ohne Limit',
            ),
            _PremiumFeatureRow(
              icon: Icons.restaurant_rounded,
              label: 'Unbegrenzte Rezepte + Wochen-Mealplan',
            ),
            _PremiumFeatureRow(
              icon: Icons.calendar_month_rounded,
              label: 'Events → Apple/Google Kalender Sync',
            ),
            _PremiumFeatureRow(
              icon: Icons.block_rounded,
              label: 'Komplett werbefrei',
            ),
            const SizedBox(height: 32),
            // Preis-Optionen
            _PricingOption(
              label: 'Monatlich',
              price: '${MonetizationConfig.premiumMonthlyPrice.toStringAsFixed(2).replaceAll('.', ',')} €',
              period: '/ Monat',
              highlighted: false,
              onTap: () {
                // TODO: In-App Purchase trigger
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 10),
            _PricingOption(
              label: 'Jährlich',
              price: '${MonetizationConfig.premiumYearlyPrice.toStringAsFixed(2).replaceAll('.', ',')} €',
              period: '/ Jahr (spare 33%)',
              highlighted: true,
              onTap: () {
                // TODO: In-App Purchase trigger
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '30 Tage kostenlos testen. Jederzeit kündbar.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromoCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Promo-Code einlösen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'z.B. BETAFAMILY',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              final success =
                  await PremiumService.instance.redeemPromoCode(code);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? '🎉 Premium aktiviert!'
                      : 'Ungültiger Code. Bitte prüfe die Eingabe.'),
                  backgroundColor: success ? const Color(0xFF16A34A) : null,
                ),
              );
            },
            child: const Text('Einlösen'),
          ),
        ],
      ),
    );
    // Dispose controller when dialog is gone
  }
}

class _PremiumFeatureRow extends StatelessWidget {
  const _PremiumFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _PricingOption extends StatelessWidget {
  const _PricingOption({
    required this.label,
    required this.price,
    required this.period,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final String price;
  final String period;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF8B5CF6)
                : theme.colorScheme.outlineVariant,
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: highlighted
                              ? const Color(0xFF8B5CF6)
                              : null,
                        )),
                    if (highlighted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('BELIEBT',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(period,
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline)),
              ],
            ),
            const Spacer(),
            Text(price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: highlighted ? const Color(0xFF8B5CF6) : null,
                )),
          ],
        ),
      ),
    );
  }
}
