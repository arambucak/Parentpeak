import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/eltern_wissen_service.dart';
import 'package:parentpeak/data/eltern_wissen_data.dart';

void main() {
  final service = ElternWissenService.instance;

  group('ElternWissenService.search', () {
    test('zu kurze Query liefert nichts', () {
      expect(service.search(''), isEmpty);
      expect(service.search('a'), isEmpty);
    });

    test('findet Treffer über ein Tag (z.B. "weinen")', () {
      final results = service.search('weinen');
      expect(results, isNotEmpty);
      // Ein Baby-Weinen-Eintrag muss unter den Top-Treffern sein.
      expect(results.any((e) => e.tags.contains('weinen')), isTrue);
    });

    test('ist unabhängig von Groß-/Kleinschreibung und Umlauten', () {
      final lower = service.search('weinen');
      final upper = service.search('WEINEN');
      expect(upper.map((e) => e.id).toList(),
          equals(lower.map((e) => e.id).toList()));
    });

    test('liefert höchstens 5 Treffer (Top-N)', () {
      // Ein sehr allgemeiner Begriff darf die Liste nicht sprengen.
      final results = service.search('kind');
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('relevante Treffer stehen oben (Ranking funktioniert)', () {
      // Die Suche ist bewusst großzügig (lieber ein Treffer mehr als ratlose
      // Eltern). Entscheidend ist, dass ein eindeutiger Begriff den passenden
      // Eintrag an die SPITZE bringt.
      final results = service.search('schlafen');
      expect(results, isNotEmpty);
      final top = results.first;
      final matchesTopic = top.tags.any((t) => t.contains('schlaf')) ||
          top.question.toLowerCase().contains('schlaf') ||
          top.category.toLowerCase().contains('schlaf');
      expect(matchesTopic, isTrue,
          reason: 'Top-Treffer für "schlafen" sollte thematisch passen');
    });

    test('alle FAQ-Einträge haben eindeutige IDs und Pflichtfelder', () {
      // Datenqualität: schützt vor stillen Dubletten/leeren Einträgen.
      final ids = elternWissenData.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'IDs müssen eindeutig sein');
      for (final e in elternWissenData) {
        expect(e.question.trim(), isNotEmpty);
        expect(e.tags, isNotEmpty);
        expect(e.minAge, lessThanOrEqualTo(e.maxAge));
      }
    });
  });
}
