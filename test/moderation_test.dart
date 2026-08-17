import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';

/// Comprehensive tests for chat moderation — family-safe community.
void main() {
  final svc = ChatModerationService.instance;

  group('ChatModerationService - Safe Messages', () {
    test('normal greetings pass', () {
      expect(svc.isSafe('Hallo! Wie geht es euch?'), isTrue);
      expect(svc.isSafe('Guten Morgen zusammen!'), isTrue);
      expect(svc.isSafe('Hi, wir sind neu hier'), isTrue);
    });

    test('parenting questions pass', () {
      expect(svc.isSafe('Kennt jemand einen guten Kinderarzt in Berlin?'), isTrue);
      expect(svc.isSafe('Mein Kind schläft schlecht, habt ihr Tipps?'), isTrue);
      expect(svc.isSafe('Suche Spielfreunde für 3-Jährige'), isTrue);
    });

    test('meetup coordination passes', () {
      expect(svc.isSafe('Treffen wir uns am Spielplatz um 15 Uhr?'), isTrue);
      expect(svc.isSafe('Ich bringe Snacks mit!'), isTrue);
      expect(svc.isSafe('Wer hat Lust auf einen Ausflug in den Zoo?'), isTrue);
    });

    test('emotional support passes', () {
      expect(svc.isSafe('Du machst das toll!'), isTrue);
      expect(svc.isSafe('Das klingt wirklich anstrengend. Ich fühle mit dir.'), isTrue);
      expect(svc.isSafe('Es ist okay mal einen schlechten Tag zu haben.'), isTrue);
    });
  });

  group('ChatModerationService - Blocked Messages', () {
    test('German profanity blocked', () {
      expect(svc.isSafe('Du bist so eine scheiße'), isFalse);
      expect(svc.isSafe('fick dich'), isFalse);
      expect(svc.checkMessage('fick dich'), contains('respektvollen'));
    });

    test('English profanity blocked', () {
      expect(svc.isSafe('fuck you'), isFalse);
      expect(svc.isSafe('what the shit'), isFalse);
    });

    test('Turkish profanity blocked', () {
      expect(svc.isSafe('siktir git'), isFalse);
    });

    test('Harassment blocked', () {
      expect(svc.isSafe('du bist eine schlechte mutter'), isFalse);
      expect(svc.isSafe('halt die fresse'), isFalse);
      expect(svc.checkMessage('halt die fresse'), contains('verletzend'));
    });

    test('Self-harm references blocked', () {
      expect(svc.isSafe('bring dich um'), isFalse);
      expect(svc.isSafe('kys'), isFalse);
    });

    test('Spam - repeated chars blocked', () {
      expect(svc.isSafe('aaaaaaaaaaaaaaa'), isFalse);
      expect(svc.isSafe('xxxxxxxxxxxxxxxxxx'), isFalse);
    });

    test('Spam - too many caps blocked', () {
      expect(svc.isSafe('KAUFT JETZT MEIN SUPER TOLLES PRODUKT HIER'), isFalse);
    });

    test('Spam - too many links blocked', () {
      expect(svc.isSafe('Check https://a.com und https://b.com und https://c.com'), isFalse);
    });

    test('Commercial content blocked', () {
      expect(svc.isSafe('Kaufe jetzt mein Produkt'), isFalse);
      expect(svc.isSafe('Verdiene geld von zuhause'), isFalse);
      expect(svc.isSafe('network marketing chance'), isFalse);
      expect(svc.isSafe('crypto invest opportunity'), isFalse);
      expect(svc.checkMessage('Kaufe jetzt mein Produkt'), contains('Werbung'));
    });

    test('Personal data warning', () {
      expect(svc.isSafe('Ruf mich an: +49 171 1234567'), isFalse);
      expect(svc.isSafe('Meine Nummer ist 0171 1234567'), isFalse);
      expect(svc.isSafe('Ich wohne in der Musterstraße 12'), isFalse);
      expect(svc.checkMessage('+49 171 1234567'), contains('persönlichen Daten'));
    });
  });

  group('ChatModerationService - Edge Cases', () {
    test('empty string is safe', () {
      expect(svc.checkMessage(''), isNull);
      expect(svc.checkMessage('   '), isNull);
    });

    test('single character is safe', () {
      expect(svc.isSafe('!'), isTrue);
      expect(svc.isSafe('?'), isTrue);
    });

    test('emoji-only messages are safe', () {
      expect(svc.isSafe('😊'), isTrue);
      expect(svc.isSafe('👍🏻'), isTrue);
      expect(svc.isSafe('❤️❤️❤️'), isTrue);
    });

    test('URLs (1-2) are allowed', () {
      expect(svc.isSafe('Schaut mal: https://example.com'), isTrue);
      expect(svc.isSafe('https://a.com und https://b.com'), isTrue);
    });
  });
}
