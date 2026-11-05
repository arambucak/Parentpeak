import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/ui/widgets/home/accent_surface.dart';

/// Stellt sicher, dass die farbigen Home-Flächen (Kontext-Card, Teaser)
/// im Dunkel-Modus NICHT die hellen Pastelltöne/dunklen Texte des
/// Light-Modes behalten — das war der gemeldete Bug.
void main() {
  // Hilfs-Widget, das uns einen BuildContext mit gewünschter Brightness gibt.
  Future<BuildContext> contextWith(
      WidgetTester tester, Brightness brightness) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    );
    return ctx;
  }

  const lightStart = Color(0xFFF5F3FF);
  const lightEnd = Color(0xFFEDE9FE);
  const accent = Color(0xFF8B5CF6);
  const lightText = Color(0xFF6B21A8);

  group('AccentSurface', () {
    testWidgets('Light-Modus behält die Original-Pastellfarben', (t) async {
      final ctx = await contextWith(t, Brightness.light);

      final gradient = AccentSurface.cardGradient(ctx,
          lightStart: lightStart, lightEnd: lightEnd, accent: accent);
      expect(gradient, [lightStart, lightEnd]);

      final text =
          AccentSurface.onSurface(ctx, lightText: lightText, accent: accent);
      expect(text, lightText);
    });

    testWidgets('Dark-Modus liefert dunkle Flächen statt heller Pastelltöne',
        (t) async {
      final ctx = await contextWith(t, Brightness.dark);

      final gradient = AccentSurface.cardGradient(ctx,
          lightStart: lightStart, lightEnd: lightEnd, accent: accent);

      // Die Gradient-Farben dürfen NICHT die hellen Light-Werte sein.
      expect(gradient, isNot([lightStart, lightEnd]));
      // Und sie müssen dunkel sein (niedrige Luminanz).
      for (final c in gradient) {
        expect(c.computeLuminance(), lessThan(0.15),
            reason: 'Dark-Mode-Fläche soll dunkel sein, war $c');
      }
    });

    testWidgets('Dark-Modus liefert hellen, lesbaren Text', (t) async {
      final ctx = await contextWith(t, Brightness.dark);

      final text =
          AccentSurface.onSurface(ctx, lightText: lightText, accent: accent);

      // Nicht mehr der dunkle Light-Mode-Text.
      expect(text, isNot(lightText));
      // Heller als der dunkle Original-Text → besserer Kontrast auf dunkel.
      expect(
          text.computeLuminance(), greaterThan(lightText.computeLuminance()));
    });

    testWidgets('chipSurface übernimmt im Light-Modus die lightAlpha',
        (t) async {
      final lightCtx = await contextWith(t, Brightness.light);
      final lightChip = AccentSurface.chipSurface(lightCtx, lightAlpha: 0.6);
      expect(lightChip.a, closeTo(0.6, 0.01));
    });

    testWidgets('chipSurface ist im Dark-Modus nicht blendend', (t) async {
      final darkCtx = await contextWith(t, Brightness.dark);
      final darkChip = AccentSurface.chipSurface(darkCtx, lightAlpha: 0.6);
      // Im Dark-Mode darf die weiße Chip-Fläche nicht blendend sein.
      expect(darkChip.a, lessThan(0.2));
    });
  });
}
