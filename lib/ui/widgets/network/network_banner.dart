import 'package:flutter/material.dart';

/// Tonalität eines [NetworkBanner].
enum NetworkBannerTone { info, warning }

/// Handlungsrelevanter Hinweis im Eltern-Netzwerk – mit Icon und Kartenstil.
///
/// Ersetzt das frühere reine Text-Statuspanel, das auch ohne Handlungsbedarf
/// Platz belegte („Profil vom Server als aktiv bestätigt."). Ein Banner wird
/// nur gezeigt, wenn der Nutzer wirklich etwas tun kann (Profil anlegen,
/// Profil fortsetzen, Fehler beheben). Farben kommen aus dem Theme.
class NetworkBanner extends StatelessWidget {
  const NetworkBanner({
    super.key,
    required this.message,
    this.icon,
    this.tone = NetworkBannerTone.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final NetworkBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool warning = tone == NetworkBannerTone.warning;
    final Color accent = warning ? scheme.tertiary : scheme.primary;
    final Color background =
        warning ? scheme.tertiaryContainer : scheme.primaryContainer;
    final Color onBackground =
        warning ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: onBackground,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
