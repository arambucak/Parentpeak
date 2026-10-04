import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';

void main() {
  group('PedagogicalChatBackend safety routing', () {
    test('treats ordinary exhaustion as supportive, not crisis', () async {
      final backend = PedagogicalChatBackend();

      final chunks = await backend.streamReply(
        history: const [],
        userMessage: 'Ich kann nicht mehr und bin so erschöpft.',
      ).toList();

      final response = chunks.join();

      // Sanfte Unterstützung, KEINE Notruf-Eskalation.
      expect(response.toLowerCase(), contains('nicht allein'));
      expect(response, isNot(contains('112')));
    });

    test('keeps acute danger on the crisis path (DE)', () async {
      final backend = PedagogicalChatBackend();

      final chunks = await backend.streamReply(
        history: const [],
        userMessage: 'Ich will meinem Kind etwas antun.',
        languageCode: 'de',
        countryCode: 'DE',
      ).toList();

      final response = chunks.join();

      expect(response, contains('112'));
      expect(response, contains('Telefonseelsorge'));
    });

    test('detects an English crisis message and answers in English', () async {
      final backend = PedagogicalChatBackend();

      final chunks = await backend.streamReply(
        history: const [],
        userMessage: 'I want to kill myself, I see no way out.',
        languageCode: 'en',
        countryCode: 'GB',
      ).toList();

      final response = chunks.join();

      // Englische Antwort + britische Notfallnummern.
      expect(response.toLowerCase(), contains('human help'));
      expect(response, contains('999'));
      expect(response, contains('Samaritans'));
      // Keine deutschen Nummern für GB.
      expect(response, isNot(contains('Telefonseelsorge')));
    });

    test('detects a Turkish crisis message with Turkish helplines', () async {
      final backend = PedagogicalChatBackend();

      final chunks = await backend.streamReply(
        history: const [],
        userMessage: 'çocuğuma zarar vermek istiyorum',
        languageCode: 'tr',
        countryCode: 'TR',
      ).toList();

      final response = chunks.join();

      expect(response, contains('112'));
      expect(response, contains('183'));
    });

    test('English overload is supportive, not a crisis', () async {
      final backend = PedagogicalChatBackend();

      final chunks = await backend.streamReply(
        history: const [],
        userMessage: "I can't anymore, I am completely overwhelmed.",
        languageCode: 'en',
      ).toList();

      final response = chunks.join();

      expect(response.toLowerCase(), contains("you're not alone"));
      expect(response, isNot(contains('999')));
      expect(response, isNot(contains('112')));
    });
  });
}
