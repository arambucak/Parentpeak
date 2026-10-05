import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/allergen_guard.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/kind_dossier.dart';

FamilyRecipe _recipe(String title, List<String> ingredients) => FamilyRecipe(
      id: title,
      title: title,
      description: '',
      prepMinutes: 20,
      costPerPortion: 2,
      minChildAge: 1,
      ingredients: ingredients,
      steps: const ['x'],
      season: 'alle',
    );

void main() {
  group('canonicalAllergen', () {
    test('fasst Varianten auf kanonische Keys zusammen', () {
      expect(AllergenGuard.canonicalAllergen('Milchallergie'), 'milch');
      expect(AllergenGuard.canonicalAllergen('Laktose-Intoleranz'), 'laktose');
      expect(AllergenGuard.canonicalAllergen('Nüsse'), 'nuesse');
      expect(AllergenGuard.canonicalAllergen('Erdnuss'), 'erdnuss');
      expect(AllergenGuard.canonicalAllergen('Gluten'), 'gluten');
    });
    test('unbekannter Begriff bleibt als normalisiertes Signalwort', () {
      expect(AllergenGuard.canonicalAllergen('Koriander'), 'koriander');
    });
  });

  group('allergensFromDossiers', () {
    test('sammelt und kanonisiert Allergien aus mehreren Dossiers', () {
      final dossiers = [
        KindDossier(childName: 'A', allergies: ['Milch', 'Nüsse']),
        KindDossier(childName: 'B', allergies: ['Gluten', '  ']),
      ];
      final result = AllergenGuard.allergensFromDossiers(dossiers);
      expect(result, containsAll(<String>['milch', 'nuesse', 'gluten']));
      expect(result.any((e) => e.trim().isEmpty), isFalse);
    });
  });

  group('violatedAllergens / isRecipeSafe', () {
    test('erkennt Milch in deutschen Zutaten', () {
      final r = _recipe('Mac and Cheese', ['400g Makkaroni', '150g Käse', '200ml Milch']);
      expect(AllergenGuard.isRecipeSafe(r, {'milch'}), isFalse);
      expect(AllergenGuard.violatedAllergens(
          ingredients: r.ingredients, allergens: {'milch'}), contains('milch'));
    });

    test('erkennt Nüsse (auch Marzipan/Nutella)', () {
      final r = _recipe('Dessert', ['Nutella', 'Banane']);
      expect(AllergenGuard.isRecipeSafe(r, {'nuesse'}), isFalse);
    });

    test('erkennt Gluten über Nudeln/Mehl', () {
      final r = _recipe('Pasta', ['400g Spaghetti', '1 Dose Tomaten']);
      expect(AllergenGuard.isRecipeSafe(r, {'gluten'}), isFalse);
    });

    test('erkennt englische + türkische Signalwörter', () {
      final en = _recipe('Omelette', ['2 eggs', 'butter']);
      expect(AllergenGuard.isRecipeSafe(en, {'ei'}), isFalse);
      final tr = _recipe('Balık', ['balık fileto', 'limon']);
      expect(AllergenGuard.isRecipeSafe(tr, {'fisch'}), isFalse);
    });

    test('sicheres Rezept wird als sicher erkannt', () {
      final r = _recipe('Reis-Gemüse', ['250g Reis', '1 Paprika', '1 Zucchini', 'Öl']);
      expect(AllergenGuard.isRecipeSafe(r, {'milch', 'gluten', 'nuesse'}), isTrue);
    });

    test('ohne Allergene ist alles sicher', () {
      final r = _recipe('X', ['Milch', 'Nüsse', 'Mehl']);
      expect(AllergenGuard.isRecipeSafe(r, <String>{}), isTrue);
    });
  });

  group('firstSafe', () {
    final nussig = _recipe('Nuss', ['Haselnuss', 'Mehl']);
    final milchig = _recipe('Milch', ['Käse', 'Sahne']);
    final sicher = _recipe('Reis', ['Reis', 'Karotte']);

    test('wählt das erste für die Allergene sichere Rezept', () {
      final result =
          AllergenGuard.firstSafe([nussig, milchig, sicher], {'nuesse', 'milch'});
      expect(result?.title, 'Reis');
    });

    test('gibt null zurück, wenn keines sicher ist', () {
      final result = AllergenGuard.firstSafe([nussig, milchig], {'nuesse', 'milch'});
      expect(result, isNull);
    });
  });
}
