import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/logic/allergen_guard.dart';
import 'package:parentpeak/logic/fallback_recipes.dart';

/// KI-Rezept-Service — generiert kinderfreundliche Rezepte via Gemini.
///
/// Funktionsweise:
///   - Lädt Kind-Alter + Allergien aus dem Profil
///   - Berücksichtigt aktuelle Saison
///   - Generiert 1 Rezept pro Aufruf (schnell, fokussiert)
///   - Cached letzte 10 Rezepte lokal
class FamilyRecipeService {
  static final FamilyRecipeService instance = FamilyRecipeService._();
  FamilyRecipeService._();

  static const _savedKey = 'familyküche.saved';

  List<FamilyRecipe> _savedRecipes = [];
  int _childAge = 3;
  List<String> _allergies = [];
  // Kanonische Allergen-Keys (aus Kind-Dossier) für die clientseitige
  // Sicherheitsprüfung generierter/Fallback-Rezepte.
  Set<String> _allergenKeys = {};

  List<FamilyRecipe> get savedRecipes => List.unmodifiable(_savedRecipes);

  /// Initialisiert den Service (lädt Profil-Daten + Cache).
  Future<void> initialize() async {
    final profile = await FamilyMatchProfile.load();
    if (profile != null && profile.children.isNotEmpty) {
      _childAge = (profile.children.first.ageMonths / 12).round().clamp(0, 16);
    }

    // SICHERHEIT: Allergien aus dem Kind-Dossier (die echte, gepflegte Quelle)
    // laden. Der alte Key 'familyküche.allergies' wird zusätzlich gelesen,
    // falls dort je etwas gesetzt wurde — beides zusammengeführt.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList('familyküche.allergies') ?? [];
    final dossierAllergies = await _loadDossierAllergies();
    _allergies = {...dossierAllergies, ...legacy}.toList();
    // Kanonische Allergen-Keys für die clientseitige Rezept-Prüfung.
    _allergenKeys = AllergenGuard.allergensFromDossiers([
      // Legacy-Begriffe ebenfalls kanonisieren.
      ...legacy.map((a) => KindDossier(childName: '', allergies: [a])),
    ])
      ..addAll(dossierAllergies.map(AllergenGuard.canonicalAllergen));

    // Gespeicherte Rezepte laden
    final savedRaw = prefs.getString(_savedKey);
    if (savedRaw != null) {
      try {
        _savedRecipes = (jsonDecode(savedRaw) as List)
            .map((e) => FamilyRecipe.fromJson(e))
            .toList();
      } catch (_) {}
    }
  }

  /// Sammelt die (rohen) Allergie-Begriffe aus allen Kind-Dossiers.
  Future<List<String>> _loadDossierAllergies() async {
    try {
      await KindDossierService.instance.load();
      final all = <String>{};
      for (final d in KindDossierService.instance.dossiers) {
        for (final a in d.allergies) {
          final clean = a.trim();
          if (clean.isNotEmpty) all.add(clean);
        }
      }
      return all.toList();
    } catch (_) {
      return const [];
    }
  }

  /// Generiert ein neues Rezept via Gemini.
  Future<FamilyRecipe?> generateRecipe({String languageCode = 'de'}) async {
    // Rate limit check
    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('FamilyRecipeService: Rate limit reached');
      return _fallbackRecipe(languageCode: languageCode);
    }

    final season = _currentSeason();
    final allergyText = _allergies.isEmpty
        ? 'Keine bekannten Allergien'
        : 'WICHTIG - Frei von: ${_allergies.join(", ")}';
    final ageText = _childAge < 1
        ? 'Baby (6-12 Monate, Brei/Fingerfood)'
        : _childAge < 3
            ? 'Kleinkind ($_childAge Jahre, weich, kleine Stücke)'
            : _childAge < 6
                ? 'Kita-Kind ($_childAge Jahre, normal)'
                : 'Schulkind ($_childAge Jahre, alles)';
    final outputLanguage = _outputLanguage(languageCode);

    final prompt = '''
Generiere EIN kinderfreundliches Familien-Rezept auf $outputLanguage.

Kontext:
- Jüngstes Kind: $ageText
- Saison: $season (nutze saisonale Zutaten)
- $allergyText
- Budget: günstig (unter 4 EUR pro Portion)
- Zeit: maximal 35 Minuten
- Portionen: 4

Regeln:
- VIELFALT: Wechsle zwischen Fleisch (Hähnchen, Hackfleisch, Schnitzel), Fisch (Lachs, Fischstäbchen), und vegetarisch. NICHT immer das gleiche.
- Das Rezept MUSS für das angegebene Kindesalter sicher und geeignet sein
- Einfache Zutaten die man im Supermarkt bekommt
- Kinder müssen es MÖGEN (nicht zu scharf, nicht zu bitter)
- Beliebt bei Kindern: Nudeln, Reis, Kartoffeln, Chicken Nuggets, Pizza, Pfannkuchen, Fischstäbchen, Bolognese, Schnitzel, Mac&Cheese
- Gib einen konkreten Eltern-Tipp (picky eater trick, gemeinsam kochen, etc.)
- allergensFree: nur auflisten wenn das Rezept tatsächlich FREI von Allergenen ist. Wenn Milch drin ist, NICHT "laktose" listen.
- Alle nutzersichtbaren JSON-Werte müssen auf $outputLanguage sein. Die JSON-Schlüssel bleiben exakt wie vorgegeben.

Antworte NUR mit einem gültigen JSON-Objekt (kein Markdown, kein Text davor/danach):
{
  "title": "Name des Gerichts",
  "description": "1 Satz warum Kinder das lieben",
  "prepMinutes": 25,
  "costPerPortion": 1.80,
  "portions": 4,
  "minChildAge": 2,
  "ingredients": ["500g Nudeln", "300g Hackfleisch", "1 Dose Tomaten"],
  "steps": ["Hack anbraten.", "Tomaten dazu.", "Mit Nudeln servieren."],
  "allergensFree": [],
  "season": "$season",
  "tip": "Lass dein Kind das Hack krümeln - wer mithilft isst lieber."
}
''';

    try {
      final modelName = APIConfig.getGeminiModelName();
      debugPrint(
          'FamilyRecipeService: Verwende Backend-KI mit Modell=$modelName');

      final raw = await GeminiAIService(modelName: modelName).generateText(
        prompt,
        systemInstruction:
            'Du bist ein mehrsprachiger Familien-Koch-Assistent. Antworte IMMER NUR mit gültigem JSON. '
            'Kein Markdown, kein Text davor oder danach. Nur ein JSON-Objekt.',
      );
      await AIRateLimiter.recordRequest();
      debugPrint('FamilyRecipeService: Gemini Antwort (${raw.length} Zeichen)');

      if (raw.isEmpty) {
        debugPrint('FamilyRecipeService: Leere Antwort von Gemini!');
        return _fallbackRecipe(languageCode: languageCode);
      }

      final recipe = _parseRecipe(raw, languageCode: languageCode);
      if (recipe != null) {
        // SICHERHEIT: KI-Antwort gegen die Allergene UND das Kindesalter
        // gegenprüfen. Enthält das Rezept trotz Prompt-Anweisung ein Allergen
        // oder ist es nicht altersgerecht (minChildAge > Kindalter), NICHT
        // ausliefern, sondern auf ein garantiert sicheres Fallback ausweichen.
        if (AllergenGuard.isRecipeSafe(recipe, _allergenKeys) &&
            _isAgeAppropriate(recipe)) {
          return recipe;
        }
        debugPrint(
            'FamilyRecipeService: KI-Rezept unsicher (Allergen/Alter) → sicheres Fallback');
        return _fallbackRecipe(languageCode: languageCode);
      }
      debugPrint(
          'FamilyRecipeService: Parsing fehlgeschlagen, Antwort: ${raw.substring(0, raw.length.clamp(0, 200))}');
      return _fallbackRecipe(languageCode: languageCode);
    } catch (e, stack) {
      debugPrint('FamilyRecipeService: KI-Fehler: $e');
      debugPrint(
          'FamilyRecipeService: Stack: ${stack.toString().split('\n').take(3).join('\n')}');
      return _fallbackRecipe(languageCode: languageCode);
    }
  }

  /// Generiert ein kinderfreundliches Rezept zu einem GESUCHTEN Gericht
  /// (z. B. "Kartoffelsalat"). Wird als KI-Fallback genutzt, wenn die Community
  /// kein passendes Rezept hat.
  Future<FamilyRecipe?> generateRecipeFor(String dish,
      {String languageCode = 'de'}) async {
    final wanted = dish.trim();
    if (wanted.isEmpty) return generateRecipe(languageCode: languageCode);
    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('FamilyRecipeService: Rate limit reached (generateFor)');
      throw AiRateLimitException(AIRateLimiter.limitReachedMessage);
    }
    final season = _currentSeason();
    final allergyText = _allergies.isEmpty
        ? 'Keine bekannten Allergien'
        : 'WICHTIG - Frei von: ${_allergies.join(", ")}';
    final ageText = _childAge < 1
        ? 'Baby (6-12 Monate, Brei/Fingerfood)'
        : _childAge < 3
            ? 'Kleinkind ($_childAge Jahre, weich, kleine Stücke)'
            : _childAge < 6
                ? 'Kita-Kind ($_childAge Jahre, normal)'
                : 'Schulkind ($_childAge Jahre, alles)';
    final outputLanguage = _outputLanguage(languageCode);

    final prompt = '''
Erstelle EIN kinderfreundliches Familien-Rezept auf $outputLanguage für: "$wanted".

Kontext:
- Jüngstes Kind: $ageText
- Saison: $season
- $allergyText
- Zeit: möglichst unter 35 Minuten
- Portionen: 4

Regeln:
- Halte dich an das gewünschte Gericht "$wanted" (kindgerechte Variante, falls nötig milder/weicher).
- Das Rezept MUSS für das angegebene Kindesalter sicher und geeignet sein.
- Einfache Zutaten aus dem Supermarkt. Kein zu scharfer/bitterer Geschmack.
- Gib einen konkreten, warmen Eltern-Tipp.
- allergensFree: nur auflisten, wenn das Rezept tatsächlich frei davon ist.
- Alle nutzersichtbaren JSON-Werte müssen auf $outputLanguage sein. Die JSON-Schlüssel bleiben exakt wie vorgegeben.

Antworte NUR mit einem gültigen JSON-Objekt (kein Markdown, kein Text davor/danach):
{
  "title": "Name des Gerichts",
  "description": "1 Satz warum Kinder das mögen",
  "prepMinutes": 25,
  "costPerPortion": 1.80,
  "portions": 4,
  "minChildAge": 2,
  "ingredients": ["Zutat 1", "Zutat 2"],
  "steps": ["Schritt 1.", "Schritt 2."],
  "allergensFree": [],
  "season": "$season",
  "tip": "Ein kurzer Eltern-Tipp."
}
''';

    try {
      final modelName = APIConfig.getGeminiModelName();
      final raw = await GeminiAIService(modelName: modelName).generateText(
        prompt,
        systemInstruction:
            'Du bist ein Familien-Koch-Assistent. Antworte IMMER NUR mit gültigem '
            'JSON. Kein Markdown, kein Text davor oder danach. Nur ein JSON-Objekt.',
      );
      await AIRateLimiter.recordRequest();
      if (raw.isEmpty) return null;
      return _parseRecipeStrict(raw);
    } catch (e) {
      debugPrint('FamilyRecipeService.generateRecipeFor: $e');
      return null;
    }
  }

  /// Wie _parseRecipe, aber OHNE Zufalls-Fallback: gibt null zurück, wenn die
  /// Antwort kein gültiges JSON ist. So bekommt der Nutzer bei einer Gericht-
  /// Suche nie ein unpassendes Zufallsrezept untergeschoben.
  FamilyRecipe? _parseRecipeStrict(String raw) {
    try {
      var text = raw.trim();
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      final map =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      map['id'] = 'recipe_${DateTime.now().millisecondsSinceEpoch}';
      final recipe = FamilyRecipe.fromJson(map);
      return recipe.title.trim().isEmpty ? null : recipe;
    } catch (e) {
      debugPrint('FamilyRecipeService._parseRecipeStrict: $e');
      return null;
    }
  }

  /// Speichert ein Rezept als Favorit.
  Future<void> saveRecipe(FamilyRecipe recipe) async {
    _savedRecipes.insert(0, recipe);
    if (_savedRecipes.length > 30) {
      _savedRecipes = _savedRecipes.take(30).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _savedKey, jsonEncode(_savedRecipes.map((r) => r.toJson()).toList()));
  }

  /// Entfernt ein gespeichertes Rezept.
  Future<void> removeRecipe(String id) async {
    _savedRecipes.removeWhere((r) => r.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _savedKey, jsonEncode(_savedRecipes.map((r) => r.toJson()).toList()));
  }

  /// Bewertet ein Rezept: Hat es den Kindern geschmeckt?
  Future<void> rateRecipe(String title, bool liked) async {
    final prefs = await SharedPreferences.getInstance();
    final rawHits = prefs.getString('familyküche.hits') ?? '[]';
    final rawFlops = prefs.getString('familyküche.flops') ?? '[]';
    List<String> hits = List<String>.from(jsonDecode(rawHits));
    List<String> flops = List<String>.from(jsonDecode(rawFlops));
    if (liked) {
      if (!hits.contains(title)) hits.insert(0, title);
      flops.remove(title);
    } else {
      if (!flops.contains(title)) flops.insert(0, title);
      hits.remove(title);
    }
    if (hits.length > 50) hits = hits.take(50).toList();
    if (flops.length > 30) flops = flops.take(30).toList();
    await prefs.setString('familyküche.hits', jsonEncode(hits));
    await prefs.setString('familyküche.flops', jsonEncode(flops));
  }

  /// Gibt die "Kinder-Hits" Liste.
  Future<List<String>> getKinderHits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('familyküche.hits') ?? '[]';
    return List<String>.from(jsonDecode(raw));
  }

  /// Setzt Allergien (einmal im Profil).
  Future<void> setAllergies(List<String> allergies) async {
    _allergies = allergies;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('familyküche.allergies', allergies);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Mappt einen Sprachcode auf die (deutsche) Bezeichnung für den KI-Prompt,
  /// damit Gemini in der aktiven App-Sprache antwortet.
  static String _outputLanguage(String languageCode) => switch (languageCode) {
        'de' => 'Deutsch',
        'tr' => 'Türkisch',
        'ku' => 'Kurmandschi (lateinische Schrift)',
        _ => 'Englisch',
      };

  String _currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'Frühling';
    if (month >= 6 && month <= 8) return 'Sommer';
    if (month >= 9 && month <= 11) return 'Herbst';
    return 'Winter';
  }

  FamilyRecipe? _parseRecipe(String raw, {String languageCode = 'de'}) {
    try {
      var text = raw.trim();
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');

      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return _fallbackRecipe(languageCode: languageCode);
      }

      final jsonStr = text.substring(start, end + 1);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      map['id'] = 'recipe_${DateTime.now().millisecondsSinceEpoch}';
      return FamilyRecipe.fromJson(map);
    } catch (e) {
      debugPrint('FamilyRecipeService._parseRecipe: $e');
      return _fallbackRecipe(languageCode: languageCode);
    }
  }

  int _fallbackIndex = 0;

  /// Liefert ein Fallback-Rezept, das für die gesetzten Allergene SICHER ist.
  /// Rotiert dafür durch die Liste und überspringt unsichere Rezepte. Gibt
  /// null zurück, wenn KEIN Fallback sicher ist — dann zeigt die UI eine klare
  /// Allergen-Warnung statt eines (gefährlichen) Rezepts.
  ///
  /// Die Fallback-Rezepte werden in der aktiven App-Sprache ausgegeben
  /// (DE/EN/TR/KU, sonst EN als inklusiver Rückfall).
  /// Ein Rezept ist für das jüngste Kind geeignet, wenn sein Mindestalter das
  /// Kindalter nicht überschreitet. So bekommt z. B. ein Baby kein Rezept
  /// „ab 3 Jahren" mit verschluckbaren Stücken untergeschoben.
  bool _isAgeAppropriate(FamilyRecipe recipe) =>
      recipe.minChildAge <= _childAge;

  FamilyRecipe? _fallbackRecipe({String languageCode = 'de'}) {
    final recipes = FallbackRecipes.forLanguage(languageCode);
    final count = recipes.length;
    for (var i = 0; i < count; i++) {
      final recipe = recipes[(_fallbackIndex + i) % count];
      if (AllergenGuard.isRecipeSafe(recipe, _allergenKeys) &&
          _isAgeAppropriate(recipe)) {
        _fallbackIndex = (_fallbackIndex + i + 1) % count;
        return FamilyRecipe(
          id: 'fallback_${DateTime.now().millisecondsSinceEpoch}_$_fallbackIndex',
          title: recipe.title,
          description: recipe.description,
          prepMinutes: recipe.prepMinutes,
          costPerPortion: recipe.costPerPortion,
          minChildAge: recipe.minChildAge,
          ingredients: recipe.ingredients,
          steps: recipe.steps,
          allergensFree: recipe.allergensFree,
          season: _currentSeason(),
          tip: recipe.tip,
        );
      }
    }
    // Kein einziges Fallback-Rezept ist für diese Allergene sicher.
    return null;
  }
}
