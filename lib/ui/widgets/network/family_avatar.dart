import 'package:flutter/material.dart';

/// Größenstufen für [FamilyAvatar].
///
/// S für dichte Listen/Zeilen, M für Karten, L für den Profilkopf und den
/// Match-Bildschirm.
enum FamilyAvatarSize { s, m, l }

/// Avatar einer Familie im Eltern-Netzwerk / in der Familien-Community.
///
/// Zeigt bewusst **keine Fotos** (Produktentscheidung: nur Initialen oder
/// Illustration, keine Eltern- oder Kinderfotos). Dargestellt wird die
/// Initiale des Familiennamens auf einer stabil aus dem Namen abgeleiteten
/// Farbe. Die Farbpalette wird aus dem [ColorScheme] des aktiven Themes
/// gebildet, damit hell/dunkel und Theme-Wechsel automatisch passen – anders
/// als beim älteren `UserAvatar`, der sechs feste Literal-Farben nutzt.
///
/// Trägt ein Semantik-Label, damit Screenreader die Familie ansagen können.
class FamilyAvatar extends StatelessWidget {
  const FamilyAvatar({
    super.key,
    required this.name,
    this.size = FamilyAvatarSize.m,
    this.semanticLabel,
  });

  /// Anzeigename der Familie (z. B. „Familie Aylin"). Erstes Zeichen wird als
  /// Initiale gezeigt.
  final String name;

  /// Größenstufe. Siehe [FamilyAvatarSize].
  final FamilyAvatarSize size;

  /// Optionales Semantik-Label. Fällt auf den [name] zurück.
  final String? semanticLabel;

  double get _radius {
    switch (size) {
      case FamilyAvatarSize.s:
        return 18;
      case FamilyAvatarSize.m:
        return 24;
      case FamilyAvatarSize.l:
        return 36;
    }
  }

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  /// Stabil aus dem Namen abgeleitete Hintergrundfarbe aus dem Theme-
  /// [ColorScheme]. Gleiche Familie → gleiche Farbe, in hell und dunkel.
  Color _background(ColorScheme scheme) {
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    if (name.isEmpty) return palette.first;
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _background(scheme);
    // Lesbarer Vordergrund passend zur jeweiligen Container-/Akzentfarbe.
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : scheme.onSurface;
    return Semantics(
      label: semanticLabel ?? name,
      image: true,
      child: ExcludeSemantics(
        child: CircleAvatar(
          radius: _radius,
          backgroundColor: background,
          child: Text(
            _initial,
            style: TextStyle(
              color: foreground,
              fontSize: _radius * 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
