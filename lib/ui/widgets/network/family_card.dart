import 'package:flutter/material.dart';

/// Karten-Container für das Eltern-Netzwerk (Entdecken-Karte, Match-Kachel,
/// Anfrage-Zeile).
///
/// Nutzt das `cardTheme` des Projekts (Radius 24, Elevation 0) statt des
/// früheren handgebauten Containers mit Radius 18 und eigenem Schlagschatten.
/// So sind alle Karten im Netzwerk einheitlich und folgen dem Theme.
class FamilyCard extends StatelessWidget {
  const FamilyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
