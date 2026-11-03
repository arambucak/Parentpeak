import 'package:flutter/material.dart';

/// Primäre Aktion im Eltern-Netzwerk (z. B. „Interessiert").
///
/// Nutzt die Theme-Primärfarbe statt des früheren harten Lila. Mindesthöhe
/// 48 für gut erreichbare Tippziele (Barrierefreiheit), Radius 16 passend zum
/// `elevatedButtonTheme` des Projekts.
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: style,
      );
    }
    return FilledButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

/// Sekundäre Aktion im Eltern-Netzwerk (z. B. „Nicht jetzt").
///
/// Gleiche Höhe und Form wie [PrimaryAction], damit ein Button-Paar optisch
/// gleichwertig wirkt (bewusste Produktentscheidung: keine Abwertung von
/// „Nicht jetzt"). Umrandet, Theme-Farben.
class SecondaryAction extends StatelessWidget {
  const SecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: style,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
