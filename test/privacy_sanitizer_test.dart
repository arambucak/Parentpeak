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
      expect(
        PrivacySanitizer.sanitizeForAi('Kind - Anna').contains('Anna'),
        isFalse,
      );
      expect(
        PrivacySanitizer.sanitizeForAi('Kind Anna').contains('Anna'),
        isFalse,
      );
    });

    test('schwärzt den klassischen "mein Kind Max"-Fall weiterhin', () {
      final out = PrivacySanitizer.sanitizeForAi('mein Kind Max spielt gern');
      expect(out.contains('Max'), isFalse);
      expect(out.contains('[KINDNAME]'), isTrue);
      // Umgebender Text bleibt erhalten.
      expect(out.contains('spielt gern'), isTrue);
    });

    test('schwärzt Sohn/Tochter mit Doppelpunkt', () {
      expect(
        PrivacySanitizer.sanitizeForAi('Sohn: Leon').contains('Leon'),
        isFalse,
      );
      expect(
        PrivacySanitizer.sanitizeForAi('Tochter: Mia').contains('Mia'),
        isFalse,
      );
    });

    test('schwärzt E-Mail, Telefon und PLZ', () {
      final out = PrivacySanitizer.sanitizeForAi(
        'Mail a@b.de Tel 030 12345678 PLZ 10115',
      );
      expect(out.contains('a@b.de'), isFalse);
      expect(out.contains('[EMAIL]'), isTrue);
      expect(out.contains('[TELEFON]'), isTrue);
      expect(out.contains('[PLZ]'), isTrue);
    });

    test('lässt unverfänglichen Text unverändert', () {
      const input = 'Grobmotorik: läuft sicher -> Ja';
      expect(PrivacySanitizer.sanitizeForAi(input), input);
    });

    test(
      'recognized de/en/tr/ku relations preserve advice but redact Unicode names',
      () {
        for (final sample in <String, String>{
          'MEIN SOHN Max schläft. max braucht Nähe.': 'Max',
          'My daughter Ada has eczema. Ada needs care.': 'Ada',
          'Our son Ben needs a calm routine.': 'Ben',
          'Child:Élodie likes playing.': 'Élodie',
          'My child Anne-Marie needs support.': 'Anne-Marie',
          'Kızım İpek uyumuyor. İpek için ne yapabilirim?': 'İpek',
          'Oğlum Çağrı oyun istiyor.': 'Çağrı',
          'Zarokê min Aram şevê naxewê. Aram alîkarî dixwaze.': 'Aram',
          'Keça min Rojîn alîkarî dixwaze.': 'Rojîn',
          'My daughter O’Neil likes playing.': 'O’Neil',
        }.entries) {
          final output = PrivacySanitizer.sanitizeForAi(sample.key);
          expect(
            output.toLowerCase(),
            isNot(contains(sample.value.toLowerCase())),
            reason: sample.key,
          );
          expect(output, contains('[KINDNAME]'));
          expect(PrivacySanitizer.sanitizeForAi(output), output);
        }
      },
    );

    test(
      'conversation-wide names cover bare user and assistant references without mutating input',
      () {
        final history = [
          {'role': 'user', 'content': 'My daughter Ada has eczema.'},
          {'role': 'assistant', 'content': 'Ada may need gentle care.'},
          {'role': 'user', 'content': 'How can Ada sleep better?'},
        ];
        final output = PrivacySanitizer.sanitizeHistoryForAi(history);
        expect(
          output.every((item) => !item['content']!.contains('Ada')),
          isTrue,
        );
        expect(output.first['content'], contains('eczema'));
        expect(history.first['content'], contains('Ada'));
        expect(output.map((item) => item['role']), [
          'user',
          'assistant',
          'user',
        ]);
      },
    );

    test(
      'ordinary relation sentences and neutral Memory placeholders remain unchanged',
      () {
        for (final input in [
          'Mein Kind ist müde. Mein Sohn schläft schlecht.',
          'My daughter has eczema. Our child needs support.',
          'My child is three years old.',
          'Kızım uyumuyor. Oğlum oyun istiyor.',
          'Zarokê min şevê naxewê.',
          'Kind: [KINDNAME], Alter: 3 Jahre',
          'Child: [CHILD_1], confirmed age: 3',
          'Memory: [THIS_CHILD] needs support with [OTHER_CHILD].',
          'Unser Kind Morgen früh begleiten.',
        ]) {
          expect(PrivacySanitizer.sanitizeForAi(input), input);
        }
      },
    );
  });
}
