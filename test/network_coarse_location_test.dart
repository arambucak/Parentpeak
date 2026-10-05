import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart'
    show coarseCoordinate;

/// Datenschutz: Das Spielfreunde-Profil darf die exakte Position einer Familie
/// nie ans Backend senden. coarseCoordinate rundet auf ~1 km Raster.
void main() {
  group('coarseCoordinate (Standort-Datenschutz)', () {
    test('rundet auf 2 Dezimalstellen (~1 km Raster)', () {
      expect(coarseCoordinate(52.520008), 52.52);
      expect(coarseCoordinate(13.404954), 13.40);
      expect(coarseCoordinate(48.137154), 48.14);
    });

    test('entfernt metergenaue Präzision', () {
      // 6 Nachkommastellen (~0,1 m) -> 2 Nachkommastellen (~1 km).
      final coarse = coarseCoordinate(52.521987)!;
      expect(coarse, 52.52);
      // Rundungsraster: Ergebnis ist ein Vielfaches von 0.01.
      expect((coarse * 100).roundToDouble() / 100, coarse);
    });

    test('negative Koordinaten (Süd/West) korrekt', () {
      expect(coarseCoordinate(-23.5505), -23.55);
      expect(coarseCoordinate(-46.6333), -46.63);
    });

    test('null / ungültige Werte geben null', () {
      expect(coarseCoordinate(null), isNull);
      expect(coarseCoordinate(double.nan), isNull);
      expect(coarseCoordinate(double.infinity), isNull);
    });
  });
}
