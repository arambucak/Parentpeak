import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/l10n/localization_extension.dart';

/// 5 Quick-Action Buttons für den Home-Screen.
/// Immer sichtbar, immer erreichbar — die wichtigsten Funktionen.
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onCalendar;
  final VoidCallback onEvents;
  final VoidCallback onImpulse;
  final VoidCallback onNetzwerk;
  final int? calendarBadge; // Anzahl Termine heute

  const QuickActionsRow({
    super.key,
    required this.onChat,
    required this.onCalendar,
    required this.onEvents,
    required this.onImpulse,
    required this.onNetzwerk,
    this.calendarBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionItem(
          icon: Icons.tips_and_updates_rounded,
          label: context.tr('home_quick_ai_chat'),
          color: const Color(0xFF0284C7),
          onTap: onChat,
        ),
        _QuickActionItem(
          icon: Icons.calendar_month_rounded,
          label: context.tr('home_quick_calendar'),
          color: const Color(0xFF2563EB),
          onTap: onCalendar,
          badge: calendarBadge,
        ),
        _QuickActionItem(
          icon: Icons.celebration_rounded,
          label: context.tr('home_quick_events'),
          color: const Color(0xFF8B5CF6),
          onTap: onEvents,
        ),
        _QuickActionItem(
          icon: Icons.auto_awesome_mosaic_rounded,
          label: context.tr('home_quick_impulses'),
          color: const Color(0xFF0EA5A4),
          onTap: onImpulse,
        ),
        _QuickActionItem(
          icon: Icons.people_rounded,
          label: context.tr('home_quick_network'),
          color: const Color(0xFFF97316),
          onTap: onNetzwerk,
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text(
                  '$badge',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                )),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
