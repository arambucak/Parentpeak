import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';

class PlaymateDiscoveryEmptyState extends StatelessWidget {
  const PlaymateDiscoveryEmptyState({super.key, required this.tabs});

  final TabController tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          const Text('\u{1F331}', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            context.tr('network_copy_empty_title'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('network_copy_empty_description'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => tabs.animateTo(1),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(context.tr('network_copy_invite_playmates')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
