import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/fallback_recipes.dart';
import 'package:parentpeak/logic/allergen_guard.dart';

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

void main() {
  const languages = ['de', 'en', 'tr', 'ku'];

  group('FallbackRecipes.forLanguage', () {
    test('liefert für jede Hauptsprache dieselbe Anzahl Rezepte', () {
      final counts =
          languages.map((l) => FallbackRecipes.forLanguage(l).length).toSet();
      // Alle Sprachen müssen gleich viele Rezepte haben (parallele Pflege).
      expect(counts.length, 1,
          reason: 'Sprachen haben unterschiedlich viele Rezepte');
      expect(FallbackRecipes.forLanguage('de').length, 10);
    });

    test('unbekannte Sprache fällt inklusiv auf Englisch zurück', () {
      final en = FallbackRecipes.forLanguage('en');
      final other = FallbackRecipes.forLanguage('es');
      expect(other.length, en.length);
      expect(other.first.title, en.first.title);
    });

    test('keine leeren Titel, Zutaten oder Schritte in irgendeiner Sprache',
        () {
      for (final lang in languages) {
        for (final r in FallbackRecipes.forLanguage(lang)) {
          expect(r.title.trim(), isNotEmpty, reason: '$lang: leerer Titel');
          expect(r.ingredients, isNotEmpty, reason: '$lang: keine Zutaten');
          expect(r.steps, isNotEmpty, reason: '$lang: keine Schritte');
          expect(r.tip.trim(), isNotEmpty, reason: '$lang: kein Tipp');
        }
      }
    });

    test(
        'strukturelle Sicherheits-Felder sind über alle Sprachen positionsgleich identisch',
        () {
      // Allergen-Sicherheit muss sprachunabhängig gelten: allergensFree,
      // minChildAge und die Zutaten-Allergene müssen pro Index in jeder
      // Sprache übereinstimmen, sonst wäre ein Rezept in einer Sprache sicher
      // und in einer anderen nicht.
      final de = FallbackRecipes.forLanguage('de');
      for (final lang in languages.where((l) => l != 'de')) {
        final other = FallbackRecipes.forLanguage(lang);
        for (var i = 0; i < de.length; i++) {
          expect(other[i].allergensFree.toSet(), de[i].allergensFree.toSet(),
              reason: '$lang[$i] allergensFree weicht ab');
          expect(other[i].minChildAge, de[i].minChildAge,
              reason: '$lang[$i] minChildAge weicht ab');
        }
      }
    });

    test(
        'ein Rezept, das in DE ein Allergen enthält, enthält es auch in den anderen Sprachen',
        () {
      // Prüft, dass die (übersetzten) Zutaten in jeder Sprache dieselben
      // Allergene auslösen — Grundlage dafür, dass AllergenGuard verlässlich
      // filtert, egal in welcher Sprache das Fallback kommt.
      const checkAllergens = {'laktose', 'milch', 'gluten', 'ei', 'fisch'};
      final de = FallbackRecipes.forLanguage('de');
      final mismatches = <String>[];
      for (final lang in languages.where((l) => l != 'de')) {
        final other = FallbackRecipes.forLanguage(lang);
        for (var i = 0; i < de.length; i++) {
          final deViol = AllergenGuard.violatedAllergens(
            ingredients: de[i].ingredients,
            allergens: checkAllergens,
          );
          final otherViol = AllergenGuard.violatedAllergens(
            ingredients: other[i].ingredients,
            allergens: checkAllergens,
          );
          if (!_setEquals(otherViol, deViol)) {
            mismatches.add(
                '$lang[$i] "${other[i].title}": DE=$deViol vs $lang=$otherViol');
          }
        }
      }
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });
  });
}
