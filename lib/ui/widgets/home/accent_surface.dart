import 'package:flutter/material.dart';

/// Hilfsfunktionen für farbige Akzent-Karten (Kontext-Card, Teaser etc.),
/// die im Hell- UND Dunkel-Modus gut aussehen sollen.
///
/// Hintergrund: Die Home-Kacheln nutzen warme Pastell-Gradienten mit dunklen
/// Textfarben. Das funktioniert nur im Light-Mode. Im Dark-Mode werden die
/// hellen Flächen blendend und der dunkle Text unlesbar.
///
/// Statt überall Hex-Werte doppelt zu pflegen, leiten diese Funktionen aus
/// EINER Akzentfarbe (z.B. Amber, Grün, Violett) die jeweils passende Flächen-
/// und Textfarbe für die aktuelle Helligkeit ab.
class AccentSurface {
  const AccentSurface._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Gradient-Farben für den Karten-Hintergrund.
  /// Light: die mitgegebenen hellen Pastelltöne.
  /// Dark: sehr dunkle, leicht eingefärbte Flächen auf Basis von [accent].
  static List<Color> cardGradient(
    BuildContext context, {
    required Color lightStart,
    required Color lightEnd,
    required Color accent,
  }) {
    if (!_isDark(context)) return [lightStart, lightEnd];
    // Dunkle Karte mit dezentem Akzent-Schimmer.
    return [
      Color.alphaBlend(accent.withValues(alpha: 0.10), const Color(0xFF1C1C1E)),
      Color.alphaBlend(accent.withValues(alpha: 0.16), const Color(0xFF232326)),
    ];
  }

  /// Rahmenfarbe der Karte.
  static Color cardBorder(BuildContext context, Color accent,
      {double lightAlpha = 0.2}) {
    return accent.withValues(alpha: _isDark(context) ? 0.35 : lightAlpha);
  }

  /// Fläche für kleine „Chips" (Dauer/Material, nächster Termin etc.).
  /// Light: halbtransparentes Weiß über der Pastellfläche.
  /// Dark: halbtransparentes Weiß über dunklem Grund (leichtes Aufhellen).
  static Color chipSurface(BuildContext context, {double lightAlpha = 0.6}) {
    return _isDark(context)
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: lightAlpha);
  }

  /// Haupt-Textfarbe auf der Akzentfläche.
  /// Light: die mitgegebene dunkle Variante (z.B. 0xFF92400E).
  /// Dark: eine helle, gut lesbare Variante der Akzentfarbe.
  static Color onSurface(
    BuildContext context, {
    required Color lightText,
    required Color accent,
  }) {
    if (!_isDark(context)) return lightText;
    return _lighten(accent, 0.45);
  }

  /// Sekundäre/gedämpfte Textfarbe (Labels) auf der Akzentfläche.
  static Color onSurfaceMuted(
    BuildContext context, {
    required Color lightText,
    required Color accent,
  }) {
    if (!_isDark(context)) return lightText;
    return _lighten(accent, 0.55);
  }

  /// Akzentfarbe für Icons/Buttons – im Dark-Mode leicht aufgehellt für
  /// besseren Kontrast auf dunklem Grund.
  static Color accentColor(BuildContext context, Color accent) {
    return _isDark(context) ? _lighten(accent, 0.3) : accent;
  }

  /// Hellt eine Farbe Richtung Weiß auf ([amount] 0..1).
  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
