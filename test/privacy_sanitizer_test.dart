import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/privacy_sanitizer.dart';

void main() {
  group('PrivacySanitizer.sanitizeForAi', () {
    test('schwärzt Kindnamen im strukturierten Prompt-Kontext "Kind: Name"', () {
      // Regression: Der Entwicklungs-Report baute den Prompt als
      // "Kind: Max, Alter: ..." — der Doppelpunkt ließ den Namen früher durch.
      final out = PrivacySanitizer.sanitizeForAi('Kind: Max, Alter: 3 Jahre');
      expect(out.contains('Max'), isFalse);
      expect(out.contains('[KINDNAME]'), isTrue);
    });

    test('schwärzt Kindnamen auch bei Bindestrich und ohne Trenner', () {
      expect(PrivacySanitizer.sanitizeForAi('Kind - Anna').contains('Anna'),
          isFalse);
      expect(PrivacySanitizer.sanitizeForAi('Kind Anna').contains('Anna'),
          isFalse);
    });

    test('schwärzt den klassischen "mein Kind Max"-Fall weiterhin', () {
      final out = PrivacySanitizer.sanitizeForAi('mein Kind Max spielt gern');
      expect(out.contains('Max'), isFalse);
      expect(out.contains('[KINDNAME]'), isTrue);
      // Umgebender Text bleibt erhalten.
      expect(out.contains('spielt gern'), isTrue);
    });

    test('schwärzt Sohn/Tochter mit Doppelpunkt', () {
      expect(PrivacySanitizer.sanitizeForAi('Sohn: Leon').contains('Leon'),
          isFalse);
      expect(
          PrivacySanitizer.sanitizeForAi('Tochter: Mia').contains('Mia'),
          isFalse);
    });

    test('schwärzt E-Mail, Telefon und PLZ', () {
      final out = PrivacySanitizer.sanitizeForAi(
          'Mail a@b.de Tel 030 12345678 PLZ 10115');
      expect(out.contains('a@b.de'), isFalse);
      expect(out.contains('[EMAIL]'), isTrue);
      expect(out.contains('[TELEFON]'), isTrue);
      expect(out.contains('[PLZ]'), isTrue);
    });

    test('lässt unverfänglichen Text unverändert', () {
      const input = 'Grobmotorik: läuft sicher -> Ja';
      expect(PrivacySanitizer.sanitizeForAi(input), input);
    });
  });
}
