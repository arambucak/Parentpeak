import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/config/access_config.dart';

class PaywallScreen extends StatelessWidget {
  final VoidCallback? onSubscribed;

  /// Optionaler Kontext warum der User auf die Paywall kam.
  /// z.B. 'ki_elternberatung' wenn das Chat-Limit erreicht wurde.
  final String? triggerFeatureId;

  const PaywallScreen({
    super.key,
    this.onSubscribed,
    this.triggerFeatureId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),
                  _buildHeader(theme, user),
              const SizedBox(height: 28),
              if (triggerFeatureId != null) _buildContextBanner(theme),
              if (triggerFeatureId != null) const SizedBox(height: 24),
              _buildComparisonTable(theme),
              const SizedBox(height: 28),
              _buildPricingCards(context, theme),
              const SizedBox(height: 20),
              _buildMoneyBackBadge(theme),
              const SizedBox(height: 16),
              _buildContinueFreely(context, theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
        // Zurück-Button oben links
        Positioned(
          top: 8,
          left: 4,
          child: BackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildHeader(ThemeData theme, ParentUser? user) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 42),
        ),
        const SizedBox(height: 20),
        Text(
          'Parentpeak Premium',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _getHeaderSubtitle(user),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getHeaderSubtitle(ParentUser? user) {
    if (AccessConfig.isBetaFreeAccess) {
      return 'Aktuell kostenlos in der Beta.\n'
          'Nach dem offiziellen Start: 1 Monat kostenlos testen.';
    }
    if (user == null) return 'Schalte alle Funktionen frei.';
    if (user.trialDaysRemaining > 0) {
      return 'Noch ${user.trialDaysRemaining} Tage kostenlos testen.\nDanach wähle deinen Plan.';
    }
    return 'Deine Testphase ist abgelaufen.\nBehalte vollen Zugang mit Premium.';
  }

  /// Kontextueller Banner wenn der User durch ein Limit hier gelandet ist.
  Widget _buildContextBanner(ThemeData theme) {
    final label = _getTriggerFeatureLabel();
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: theme.colorScheme.tertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Du hast das tägliche Limit für "$label" erreicht. '
              'Mit Premium gibt es keine Grenzen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getTriggerFeatureLabel() {
    if (triggerFeatureId == null) return null;
    final def = FeatureFlagService.instance.getDefinition(triggerFeatureId!);
    return def?.label;
  }

  /// Vergleichstabelle: Free vs Premium
  Widget _buildComparisonTable(ThemeData theme) {
    final features = [
      const _CompareRow(
        icon: Icons.auto_awesome_rounded,
        label: 'Wochenimpulse',
        freeValue: 'Basis',
        premiumValue: 'Voll',
      ),
      const _CompareRow(
        icon: Icons.chat_rounded,
        label: 'KI-Elternberatung',
        freeValue: '3\u00D7 / Tag',
        premiumValue: 'Unlimitiert',
      ),
      const _CompareRow(
        icon: Icons.calendar_month_rounded,
        label: 'Familienkalender',
        freeValue: 'Voll',
        premiumValue: 'Voll',
        isFreeIncluded: true,
      ),
      const _CompareRow(
        icon: Icons.fact_check_rounded,
        label: 'Organisation',
        freeValue: 'Voll',
        premiumValue: 'Voll',
        isFreeIncluded: true,
      ),
      const _CompareRow(
        icon: Icons.diversity_3_rounded,
        label: 'Eltern Match',
        freeValue: '\u2014',
        premiumValue: 'Voll',
        isPremiumOnly: true,
      ),
      const _CompareRow(
        icon: Icons.celebration_rounded,
        label: 'Events & Aktivit\u00E4ten',
        freeValue: '\u2014',
        premiumValue: 'Voll',
        isPremiumOnly: true,
      ),
      const _CompareRow(
        icon: Icons.inventory_2_rounded,
        label: 'Verschenkmarkt',
        freeValue: '\u2014',
        premiumValue: 'Voll',
        isPremiumOnly: true,
      ),
      const _CompareRow(
        icon: Icons.favorite_rounded,
        label: 'GemeinsamSatt',
        freeValue: '\u2014',
        premiumValue: 'Voll',
        isPremiumOnly: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: SizedBox.shrink(),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Free',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Premium',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...features.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;
            final isLast = idx == features.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        Icon(row.icon,
                            size: 16,
                            color: row.isPremiumOnly
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            row.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.freeValue,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: row.isPremiumOnly
                            ? theme.colorScheme.outline
                            : theme.colorScheme.onSurface,
                        fontWeight: row.isFreeIncluded
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            row.premiumValue,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPricingCards(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        _PricingCard(
          label: 'Jährlich',
          price: '29,99 \u20AC',
          subline: '2,50 \u20AC / Monat',
          badge: 'Beliebt \u00B7 37% Ersparnis',
          isPrimary: true,
          onTap: () => _activatePremium(context),
        ),
        const SizedBox(height: 12),
        _PricingCard(
          label: 'Monatlich',
          price: '3,99 \u20AC',
          subline: 'monatlich k\u00FCndbar',
          onTap: () => _activatePremium(context),
        ),
      ],
    );
  }

  Future<void> _activatePremium(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final success = await AuthService.instance.activatePremium();
    if (!success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Premium-Aktivierung fehlgeschlagen. Bitte erneut versuchen.'),
          ),
        );
      }
      return;
    }
    onSubscribed?.call();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildMoneyBackBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined,
              color: theme.colorScheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '30 Tage Geld-zur\u00FCck-Garantie \u00B7 Jederzeit k\u00FCndbar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueFreely(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            'Mit Free-Version weitermachen',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kalender, Organisation und Basis-Impulse bleiben kostenlos.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Hilfsklassen ─────────────────────────────────────────────────────────────

class _CompareRow {
  final IconData icon;
  final String label;
  final String freeValue;
  final String premiumValue;
  final bool isFreeIncluded;
  final bool isPremiumOnly;

  const _CompareRow({
    required this.icon,
    required this.label,
    required this.freeValue,
    required this.premiumValue,
    this.isFreeIncluded = false,
    this.isPremiumOnly = false,
  });
}

// ─── Pricing Card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final String label;
  final String price;
  final String subline;
  final String? badge;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PricingCard({
    required this.label,
    required this.price,
    required this.subline,
    required this.onTap,
    this.badge,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isPrimary ? 2 : 1,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isPrimary
                            ? theme.colorScheme.onPrimaryContainer
                            : null,
                      )),
                  Text(subline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isPrimary ? theme.colorScheme.primary : null,
                  ),
                ),
                Text(
                  isPrimary ? '/ Jahr' : '/ Monat',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
