import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// KI-Rezept-Service — generiert kinderfreundliche Rezepte via Gemini.
///
/// Funktionsweise:
///   - Laedt Kind-Alter + Allergien aus dem Profil
///   - Beruecksichtigt aktuelle Saison
///   - Generiert 1 Rezept pro Aufruf (schnell, fokussiert)
///   - Cached letzte 10 Rezepte lokal
class FamilyRecipeService {
  static final FamilyRecipeService instance = FamilyRecipeService._();
  FamilyRecipeService._();

  static const _cacheKey = 'familykueche.recipes';
  static const _savedKey = 'familykueche.saved';

  List<FamilyRecipe> _recentRecipes = [];
  List<FamilyRecipe> _savedRecipes = [];
  int _childAge = 3;
  List<String> _allergies = [];

  List<FamilyRecipe> get savedRecipes => List.unmodifiable(_savedRecipes);

  /// Initialisiert den Service (laedt Profil-Daten + Cache).
  Future<void> initialize() async {
    final profile = await FamilyMatchProfile.load();
    if (profile != null && profile.children.isNotEmpty) {
      _childAge = (profile.children.first.ageMonths / 12).round().clamp(0, 16);
    }
    // Allergien aus SharedPreferences (spaeter aus Profil erweiterbar)
    final prefs = await SharedPreferences.getInstance();
    _allergies = prefs.getStringList('familykueche.allergies') ?? [];
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

  /// Generiert ein neues Rezept via Gemini.
  Future<FamilyRecipe?> generateRecipe() async {
    final apiKey = APIConfig.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('FamilyRecipeService: Kein Gemini API-Key.');
      return _fallbackRecipe();
    }

    final season = _currentSeason();
    final allergyText = _allergies.isEmpty
        ? 'Keine bekannten Allergien'
        : 'WICHTIG - Frei von: ${_allergies.join(", ")}';
    final ageText = _childAge < 1
        ? 'Baby (6-12 Monate, Brei/Fingerfood)'
        : _childAge < 3
            ? 'Kleinkind ($_childAge Jahre, weich, kleine Stuecke)'
            : _childAge < 6
                ? 'Kita-Kind ($_childAge Jahre, normal)'
                : 'Schulkind ($_childAge Jahre, alles)';

    final prompt = '''
Generiere EIN kinderfreundliches Familien-Rezept.

Kontext:
- Juengstes Kind: $ageText
- Saison: $season (nutze saisonale Zutaten)
- $allergyText
- Budget: guenstig (unter 3 EUR pro Portion)
- Zeit: maximal 35 Minuten
- Portionen: 4

Regeln:
- Das Rezept MUSS fuer das angegebene Kindesalter sicher und geeignet sein
- Einfache Zutaten die man im Supermarkt bekommt
- Kinder muessen es MOEGEN (nicht zu scharf, nicht zu bitter)
- Gib einen konkreten Eltern-Tipp (picky eater trick, gemeinsam kochen, etc.)

Antworte NUR mit einem JSON-Objekt (kein Markdown):
{
  "title": "Name des Gerichts",
  "description": "1 Satz: Warum Kinder das moegen",
  "prepMinutes": 25,
  "costPerPortion": 1.80,
  "portions": 4,
  "minChildAge": 2,
  "ingredients": ["500g Nudeln", "200g Brokkoli", "100ml Sahne"],
  "steps": ["Nudeln kochen.", "Brokkoli daempfen.", "Alles vermischen."],
  "allergensFree": ["nuesse", "ei"],
  "season": "$season",
  "tip": "Lass dein Kind den Brokkoli in kleine Baeume brechen - dann essen sie ihn lieber."
}
''';

    try {
      final model = GenerativeModel(
        model: APIConfig.getGeminiModelName(),
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.9,
          maxOutputTokens: 1024,
        ),
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '';
      return _parseRecipe(raw);
    } catch (e) {
      debugPrint('FamilyRecipeService: KI-Fehler: $e');
      return _fallbackRecipe();
    }
  }

  /// Speichert ein Rezept als Favorit.
  Future<void> saveRecipe(FamilyRecipe recipe) async {
    _savedRecipes.insert(0, recipe);
    if (_savedRecipes.length > 30)
      _savedRecipes = _savedRecipes.take(30).toList();
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

  /// Setzt Allergien (einmal im Profil).
  Future<void> setAllergies(List<String> allergies) async {
    _allergies = allergies;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('familykueche.allergies', allergies);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'Fruehling';
    if (month >= 6 && month <= 8) return 'Sommer';
    if (month >= 9 && month <= 11) return 'Herbst';
    return 'Winter';
  }

  FamilyRecipe? _parseRecipe(String raw) {
    try {
      var text = raw.trim();
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');

      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1) return _fallbackRecipe();

      final jsonStr = text.substring(start, end + 1);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      map['id'] = 'recipe_${DateTime.now().millisecondsSinceEpoch}';
      return FamilyRecipe.fromJson(map);
    } catch (e) {
      debugPrint('FamilyRecipeService._parseRecipe: $e');
      return _fallbackRecipe();
    }
  }

  FamilyRecipe _fallbackRecipe() {
    final recipes = [
      FamilyRecipe(
        id: 'fallback_1',
        title: 'Nudeln mit versteckter Gemuese-Sauce',
        description:
            'Karotten und Zucchini verschwinden in der Tomatensauce — kein Kind merkt es.',
        prepMinutes: 25,
        costPerPortion: 1.50,
        minChildAge: 1,
        ingredients: [
          '400g Spaghetti',
          '2 Karotten',
          '1 Zucchini',
          '400ml Passata',
          '1 EL Olivenoel',
          'Salz'
        ],
        steps: [
          'Gemuese fein raspeln.',
          'In Oel anbraten bis weich.',
          'Passata dazu, 10 Min koecheln.',
          'Puerieren bis glatt.',
          'Mit Nudeln servieren.'
        ],
        allergensFree: ['nuesse', 'ei', 'laktose'],
        season: _currentSeason(),
        tip:
            'Lass dein Kind die Karotten waschen — wer mithilft, probiert eher.',
      ),
      FamilyRecipe(
        id: 'fallback_2',
        title: 'Pfannkuchen mit Apfelmus',
        description: 'Suess, schnell, beliebt bei JEDEM Kind. Geht immer.',
        prepMinutes: 15,
        costPerPortion: 0.80,
        minChildAge: 1,
        ingredients: [
          '200g Mehl',
          '2 Eier',
          '300ml Milch',
          '1 Prise Salz',
          'Butter zum Braten',
          'Apfelmus'
        ],
        steps: [
          'Mehl, Eier, Milch, Salz glatt ruehren.',
          'Pfanne erhitzen, Butter rein.',
          'Duenn ausgiessen, goldbraun wenden.',
          'Mit Apfelmus servieren.'
        ],
        allergensFree: ['nuesse'],
        season: _currentSeason(),
        tip:
            'Pfannkuchen eignen sich perfekt zum gemeinsam Wenden-Ueben ab 4 Jahren.',
      ),
      FamilyRecipe(
        id: 'fallback_3',
        title: 'Reis mit Brokkoli-Kaese-Sauce',
        description:
            'Der Kaese macht den Brokkoli unwiderstehlich — auch fuer Gemuese-Verweigerer.',
        prepMinutes: 20,
        costPerPortion: 1.20,
        minChildAge: 1,
        ingredients: [
          '250g Reis',
          '300g Brokkoli',
          '100ml Sahne',
          '80g geriebener Kaese',
          'Salz, Muskat'
        ],
        steps: [
          'Reis nach Packung kochen.',
          'Brokkoli in Roeschen 8 Min daempfen.',
          'Sahne + Kaese erhitzen bis cremig.',
          'Brokkoli unterheben.',
          'Ueber Reis geben.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: _currentSeason(),
        tip:
            'Nenne die Brokkoli-Roeschen "kleine Baeume" — Kinder essen lieber was einen lustigen Namen hat.',
      ),
    ];
    return recipes[DateTime.now().second % recipes.length];
  }
}
