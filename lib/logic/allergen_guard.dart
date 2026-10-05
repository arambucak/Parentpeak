import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/kind_dossier.dart';

/// Allergen-Sicherheit für die Familien-Küche.
///
/// SICHERHEITSKRITISCH (Kinder-App): Allergien, die Eltern im Kind-Dossier
/// pflegen, müssen in der Rezept-Generierung zuverlässig ankommen UND jedes
/// vorgeschlagene Rezept muss gegen diese Allergene geprüft werden — sowohl
/// KI-Rezepte als auch die statischen Fallback-Rezepte.
///
/// Die Erkennung ist bewusst konservativ: Im Zweifel gilt ein Rezept als
/// "enthält Allergen" (lieber ein sicheres Rezept verwerfen als ein
/// gefährliches durchlassen).
class AllergenGuard {
  const AllergenGuard._();

  /// Bekannte Allergen-Gruppen → Signalwörter (DE/EN/TR, lowercase, ohne
  /// Umlaute nach [_normalize]). Der Schlüssel ist der kanonische Allergen-Key,
  /// wie ihn das Kind-Dossier/die UI verwenden könnte.
  static const Map<String, List<String>> allergenKeywords = {
    'laktose': [
      'milch',
      'milk',
      'sut',
      'sir', // ku: şîr (Milch)
      'kase',
      'kaese',
      'cheese',
      'peynir',
      'penir', // ku: penîr (Käse)
      'sahne',
      'cream',
      'krema',
      'qeymax', // ku: Sahne/Rahm
      'butter',
      'tereyag',
      'joghurt',
      'yoghurt',
      'yogurt',
      'quark',
      'frischkase',
      'parmesan',
      'mozzarella',
      'schlagsahne',
      'creme fraiche',
      'milchpulver',
      'laktose',
      'lactose',
    ],
    'milch': [
      'milch',
      'milk',
      'sut',
      'sir', // ku: şîr (Milch)
      'kase',
      'kaese',
      'cheese',
      'peynir',
      'penir', // ku: penîr (Käse)
      'sahne',
      'cream',
      'krema',
      'qeymax', // ku: Sahne/Rahm
      'butter',
      'tereyag',
      'joghurt',
      'yogurt',
      'quark',
      'parmesan',
      'mozzarella',
      'milchpulver',
    ],
    'gluten': [
      'mehl',
      'flour',
      'un',
      'arvan', // ku: Mehl
      'weizen',
      'wheat',
      'bugday',
      'nudeln',
      'pasta',
      'makkaroni',
      'makaroni', // tr/ku: makarna/makaronî
      'makarna', // tr: Nudeln
      'spaghetti',
      'spagetti', // tr: Schreibweise ohne h
      'spagetî', // ku
      'brot',
      'bread',
      'ekmek',
      'semmelbrosel',
      'galeta', // tr: galeta unu (Paniermehl)
      'paniermehl',
      'couscous',
      'bulgur',
      'grie',
      'gries',
      'griess',
      'pizzateig',
      'teig',
      'dough',
      'hamur', // tr: Teig
      'hevir', // ku: hevîr (Teig)
      'nani', // ku: nanî (Brot/Panade)
      'cracker',
      'keks',
      'zwieback',
      'gerste',
      'roggen',
      'dinkel',
      'gluten',
    ],
    'ei': [
      'ei',
      'eier',
      'egg',
      'eggs',
      'yumurta',
      'hek', // ku: hêk (Ei)
      'eiklar',
      'eigelb',
      'mayonnaise',
      'mayo',
    ],
    'nuesse': [
      'nuss',
      'nusse',
      'nuesse',
      'nut',
      'nuts',
      'findik',
      'ceviz',
      'mandel',
      'almond',
      'badem',
      'haselnuss',
      'hazelnut',
      'walnuss',
      'walnut',
      'cashew',
      'pistazie',
      'pistachio',
      'erdnuss',
      'peanut',
      'yer fistigi',
      'nutella',
      'marzipan',
      'nussmus',
      'erdnussbutter',
      'peanut butter',
    ],
    'erdnuss': [
      'erdnuss',
      'peanut',
      'yer fistigi',
      'erdnussbutter',
      'peanut butter',
    ],
    'soja': [
      'soja',
      'soy',
      'soya',
      'sojasauce',
      'soy sauce',
      'tofu',
      'edamame'
    ],
    'fisch': [
      'fisch',
      'fish',
      'balik',
      'masi', // ku: masî (Fisch)
      'lachs',
      'salmon',
      'somon', // tr/ku: Lachs
      'kabeljau',
      'cod',
      'seelachs',
      'thunfisch',
      'tuna',
      'fischstabchen',
      'fischfilet',
      'fischfile',
      'forelle',
    ],
    'meeresfruechte': [
      'garnele',
      'shrimp',
      'krabbe',
      'crab',
      'muschel',
      'mussel',
      'tintenfisch',
      'calamari',
      'hummer',
      'lobster',
      'meeresfruchte',
      'meeresfruechte',
      'seafood',
    ],
    'sellerie': ['sellerie', 'celery', 'kereviz'],
    'senf': ['senf', 'mustard', 'hardal'],
    'sesam': ['sesam', 'sesame', 'susam', 'tahin', 'tahini'],
  };

  /// Normalisiert Text: lowercase + Umlaute/diakritische Zeichen vereinheitlichen.
  static String _normalize(String input) {
    var text = input.toLowerCase();
    const replacements = {
      'ä': 'a',
      'ö': 'o',
      'ü': 'u',
      'ß': 'ss',
      'â': 'a',
      'î': 'i',
      'û': 'u',
      'ê': 'e',
      'ô': 'o',
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ş': 's',
      'é': 'e',
      'è': 'e',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }

  /// Fasst einen vom Nutzer eingetragenen Allergie-Begriff auf einen
  /// kanonischen Allergen-Key zusammen (z.B. "Milchallergie" → 'milch').
  /// Unbekannte Begriffe werden als eigener Key (normalisiert) zurückgegeben,
  /// damit auch freie Eingaben als Signalwort gegen die Zutaten geprüft werden.
  static String canonicalAllergen(String rawAllergy) {
    final n = _normalize(rawAllergy).trim();
    // Erst gegen den Key selbst (z.B. "gluten"), dann gegen die Signalwörter
    // der Gruppe matchen (z.B. "nusse" → Gruppe 'nuesse'). Signalwörter werden
    // normalisiert verglichen, damit Umlaute (ü→u) sauber greifen.
    for (final key in allergenKeywords.keys) {
      if (n.contains(_normalize(key))) return key;
    }
    for (final entry in allergenKeywords.entries) {
      for (final signal in entry.value) {
        final s = _normalize(signal);
        if (s.isNotEmpty && n.contains(s)) return entry.key;
      }
    }
    // Freitext: das Signalwort selbst nutzen (z.B. "koriander").
    return n;
  }

  /// Sammelt alle (kanonischen) Allergene aus einer Liste von Kind-Dossiers.
  static Set<String> allergensFromDossiers(List<KindDossier> dossiers) {
    final result = <String>{};
    for (final d in dossiers) {
      for (final a in d.allergies) {
        final clean = a.trim();
        if (clean.isNotEmpty) result.add(canonicalAllergen(clean));
      }
    }
    return result;
  }

  /// Prüft, ob [ingredients] eines der [allergens] enthält.
  /// Gibt die konkret gefundenen (kanonischen) Allergene zurück — leer = sicher.
  static Set<String> violatedAllergens({
    required List<String> ingredients,
    required Set<String> allergens,
  }) {
    if (allergens.isEmpty) return const {};
    final text = ingredients.map(_normalize).join(' | ');
    final hits = <String>{};
    for (final allergen in allergens) {
      final signals = allergenKeywords[allergen] ?? [allergen];
      for (final signal in signals) {
        final s = _normalize(signal);
        if (s.isNotEmpty && _containsSignal(text, s)) {
          hits.add(allergen);
          break;
        }
      }
    }
    return hits;
  }

  /// Prüft, ob [text] das (normalisierte) Signalwort [signal] enthält.
  ///
  /// Kurze Signalwörter (≤ 3 Zeichen wie "ei", "un", "nut", "egg", "soy")
  /// werden NUR an Wortgrenzen gematcht — sonst würde "ei" fälschlich in
  /// "Fleisch" oder "un" in "Thunfisch" anschlagen und jedes Rezept als unsicher
  /// markieren. Längere Signalwörter werden als Teilstring erkannt, damit
  /// Komposita wie "Milchpulver" oder "Fischstäbchen" sicher greifen.
  static bool _containsSignal(String text, String signal) {
    if (signal.length <= 3) {
      // Wortgrenzen-Match: Signalwort als eigenständiges Wort.
      final pattern =
          RegExp('(^|[^a-z0-9])${RegExp.escape(signal)}([^a-z0-9]|\$)');
      return pattern.hasMatch(text);
    }
    return text.contains(signal);
  }

  /// true, wenn das Rezept für die gegebenen Allergene SICHER ist.
  static bool isRecipeSafe(FamilyRecipe recipe, Set<String> allergens) {
    return violatedAllergens(
      ingredients: recipe.ingredients,
      allergens: allergens,
    ).isEmpty;
  }

  /// Wählt aus [candidates] das erste Rezept, das für [allergens] sicher ist.
  /// Gibt null zurück, wenn keines sicher ist (dann sollte der Aufrufer eine
  /// klare Warnung statt eines Rezepts zeigen).
  static FamilyRecipe? firstSafe(
    List<FamilyRecipe> candidates,
    Set<String> allergens,
  ) {
    for (final recipe in candidates) {
      if (isRecipeSafe(recipe, allergens)) return recipe;
    }
    return null;
  }
}
