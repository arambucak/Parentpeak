import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/app_localizations.dart';

class TreasureHandoverCard extends StatelessWidget {
  const TreasureHandoverCard({
    super.key,
    required this.monthlyFamiliesHelped,
    required this.nextHandoverSummary,
    required this.onTap,
  });

  final int monthlyFamiliesHelped;
  final String nextHandoverSummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF8FF), Color(0xFFF8F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE9FF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5CD7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('treasureTileTitle', fallback: 'Verschenkmarkt'),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF122033),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.t('treasureTileSubtitle', fallback: 'Verschenken, austauschen, Eltern verbinden'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4A5E75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF1E5CD7),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.tFormat(
                  'treasureMonthlyFamiliesHelped',
                  {'count': '$monthlyFamiliesHelped'},
                  fallback:
                      'Du hast diesen Monat schon $monthlyFamiliesHelped Familien in deiner Nachbarschaft glücklich gemacht.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF26384B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF3FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Color(0xFF1E5CD7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextHandoverSummary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1B2D47),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ModePill(
                  icon: Icons.coffee_rounded,
                  label: l10n.t('treasureHandoverCoffeeMode', fallback: 'Kaffee- & Quatsch-Modus'),
                  color: const Color(0xFFFFEEE0),
                  iconColor: const Color(0xFFD96C2F),
                ),
                _ModePill(
                  icon: Icons.swap_horiz_rounded,
                  label: l10n.t('treasureHandoverFlyingSwap', fallback: 'Fliegender Wechsel'),
                  color: const Color(0xFFE8F7EE),
                  iconColor: const Color(0xFF1E9C5C),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
