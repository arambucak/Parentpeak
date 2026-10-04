import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/crisis_support.dart';

void main() {
  group('CrisisSupport.isAcuteCrisis — mehrsprachig', () {
    test('erkennt Deutsch', () {
      expect(CrisisSupport.isAcuteCrisis('Ich will nicht mehr leben.'), isTrue);
      expect(
          CrisisSupport.isAcuteCrisis('Ich könnte meinem Kind etwas antun'),
          isTrue);
    });
    test('erkennt Englisch', () {
      expect(CrisisSupport.isAcuteCrisis('I want to kill myself'), isTrue);
      expect(CrisisSupport.isAcuteCrisis('I might harm my child'), isTrue);
    });
    test('erkennt Türkisch', () {
      expect(CrisisSupport.isAcuteCrisis('intihar etmek istiyorum'), isTrue);
      expect(CrisisSupport.isAcuteCrisis('çocuğuma zarar vermek'), isTrue);
    });
    test('erkennt Kurdisch', () {
      expect(CrisisSupport.isAcuteCrisis('ez dixwazim bimirim'), isTrue);
    });
    test('ignoriert harmlose Nachrichten', () {
      expect(CrisisSupport.isAcuteCrisis('Mein Kind schläft schlecht.'),
          isFalse);
      expect(CrisisSupport.isAcuteCrisis('How do I set a bedtime routine?'),
          isFalse);
    });
  });

  group('CrisisSupport.isEmotionalOverload', () {
    test('erkennt Überlastung ohne akute Gefahr (DE/EN/TR)', () {
      expect(CrisisSupport.isEmotionalOverload('Ich kann nicht mehr'), isTrue);
      expect(CrisisSupport.isEmotionalOverload('I am overwhelmed'), isTrue);
      expect(CrisisSupport.isEmotionalOverload('artık yapamıyorum'), isTrue);
    });
    test('ist nicht dasselbe wie akute Krise', () {
      expect(CrisisSupport.isAcuteCrisis('Ich kann nicht mehr'), isFalse);
    });
  });

  group('CrisisSupport.emergencyLine — länderabhängig', () {
    test('DE', () {
      final line = CrisisSupport.emergencyLine('DE');
      expect(line, contains('112'));
      expect(line, contains('Telefonseelsorge'));
    });
    test('GB', () {
      final line = CrisisSupport.emergencyLine('GB');
      expect(line, contains('999'));
      expect(line, contains('Samaritans'));
    });
    test('TR', () {
      final line = CrisisSupport.emergencyLine('TR');
      expect(line, contains('112'));
      expect(line, contains('183'));
    });
    test('AT und CH haben eigene Nummern', () {
      expect(CrisisSupport.emergencyLine('AT'), contains('142'));
      expect(CrisisSupport.emergencyLine('CH'), contains('143'));
    });
    test('unbekanntes/leeres Land fällt auf EU-112 zurück', () {
      expect(CrisisSupport.emergencyLine(null), contains('112'));
      expect(CrisisSupport.emergencyLine('XX'), contains('112'));
    });
  });

  group('CrisisSupport.crisisResponse — lokalisiert', () {
    test('DE enthält länderrichtige Nummern', () {
      final r =
          CrisisSupport.crisisResponse(languageCode: 'de', countryCode: 'DE');
      expect(r, contains('112'));
      expect(r.toLowerCase(), contains('menschliche hilfe'));
    });
    test('nicht abgedeckte Sprache fällt auf Englisch zurück', () {
      final r =
          CrisisSupport.crisisResponse(languageCode: 'fr', countryCode: 'GB');
      expect(r.toLowerCase(), contains('human help'));
      expect(r, contains('999'));
    });
    test('Sprache und Land sind unabhängig kombinierbar', () {
      // Türkische Sprache, aber Nutzer lebt in Deutschland.
      final r =
          CrisisSupport.crisisResponse(languageCode: 'tr', countryCode: 'DE');
      expect(r, contains('112'));
      expect(r, contains('Telefonseelsorge'));
    });
  });
}
