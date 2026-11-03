import 'package:flutter/material.dart';

/// Kleiner, ruhiger Hinweis-Chip für Attribute einer Familie: Sprache, Wert,
/// Zeitfenster oder Kinderalter.
///
/// Das Projekt-Theme definiert kein `chipTheme`, daher setzt diese Komponente
/// Form (Radius 12) und Farben selbst – jedoch ausschließlich aus dem
/// [ColorScheme], nie als Literal. Ersetzt die früheren Lila-Tint-Container
/// (`0xFF8B5CF6`) der Match-Karte.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
