import 'package:flutter/material.dart';

/// Ruhiger Leerzustand im Eltern-Netzwerk (keine Familien in der Nähe, alle
/// angesehen, kein Profil …).
///
/// Verallgemeinert den früheren `PlaymateDiscoveryEmptyState`: Titel, Text und
/// Aktion sind konfigurierbar, das harte Lila (`0xFF8B5CF6`) entfällt
/// zugunsten der Theme-Primärfarbe. Der Aktions-Button bleibt bewusst ein
/// [FilledButton], damit bestehende Widget-Tests (die auf `FilledButton`
/// prüfen und die Tab-Navigation testen) weiter gelten.
class NetworkEmptyState extends StatelessWidget {
  const NetworkEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.emoji = '\u{1F331}',
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.person_add_alt_1_rounded,
  });

  final String title;
  final String description;
  final String emoji;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
