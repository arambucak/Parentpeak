import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/ui/ritual_ruhe_screen.dart';

void main() {
  group('extractRitualJsonObject', () {
    test('entfernt ```json Codefences und parst sauber', () {
      const raw = '```json\n{"name":"Abend","steps":[]}\n```';
      final out = extractRitualJsonObject(raw);
      expect(out, isNotNull);
      final decoded = jsonDecode(out!) as Map<String, dynamic>;
      expect(decoded['name'], 'Abend');
    });

    test('entfernt generische ``` Fences ohne Sprach-Tag', () {
      const raw = '```\n{"a":1}\n```';
      expect(jsonDecode(extractRitualJsonObject(raw)!)['a'], 1);
    });

    test('schneidet umgebenden Fließtext weg', () {
      const raw = 'Hier ist dein Ritual: {"name":"Morgen"} — viel Freude!';
      expect(jsonDecode(extractRitualJsonObject(raw)!)['name'], 'Morgen');
    });

    test('reines JSON bleibt unverändert parsebar', () {
      const raw = '{"name":"X","steps":[{"title":"A"}]}';
      final decoded = jsonDecode(extractRitualJsonObject(raw)!);
      expect(decoded['steps'], hasLength(1));
    });

    test('gibt null zurück wenn kein Objekt enthalten ist', () {
      expect(extractRitualJsonObject('nur text'), isNull);
      expect(extractRitualJsonObject(''), isNull);
      expect(extractRitualJsonObject('[1,2,3]'), isNull);
    });
  });
}
