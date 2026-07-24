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

  int _fallbackIndex = 0;

  FamilyRecipe _fallbackRecipe() {
    final recipe =
        _allFallbackRecipes[_fallbackIndex % _allFallbackRecipes.length];
    _fallbackIndex++;
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

  static const _allFallbackRecipes = [
    FamilyRecipe(
        id: '',
        title: 'Nudeln mit versteckter Gemuese-Sauce',
        description: 'Karotten und Zucchini verschwinden in der Tomatensauce.',
        prepMinutes: 25,
        costPerPortion: 1.50,
        minChildAge: 1,
        ingredients: [
          '400g Spaghetti',
          '2 Karotten',
          '1 Zucchini',
          '400ml Passata',
          '1 EL Olivenoel'
        ],
        steps: [
          'Gemuese fein raspeln.',
          'In Oel anbraten bis weich.',
          'Passata dazu, 10 Min koecheln.',
          'Puerieren bis glatt.',
          'Mit Nudeln servieren.'
        ],
        allergensFree: ['nuesse', 'ei', 'laktose'],
        season: '',
        tip:
            'Lass dein Kind die Karotten waschen — wer mithilft, probiert eher.'),
    FamilyRecipe(
        id: '',
        title: 'Pfannkuchen mit Apfelmus',
        description: 'Suess, schnell, beliebt bei JEDEM Kind.',
        prepMinutes: 15,
        costPerPortion: 0.80,
        minChildAge: 1,
        ingredients: [
          '200g Mehl',
          '2 Eier',
          '300ml Milch',
          '1 Prise Salz',
          'Butter',
          'Apfelmus'
        ],
        steps: [
          'Teig glatt ruehren.',
          'Pfanne erhitzen, Butter rein.',
          'Duenn ausgiessen, goldbraun wenden.',
          'Mit Apfelmus servieren.'
        ],
        allergensFree: ['nuesse'],
        season: '',
        tip:
            'Pfannkuchen eignen sich perfekt zum gemeinsam Wenden-Ueben ab 4 Jahren.'),
    FamilyRecipe(
        id: '',
        title: 'Reis mit Brokkoli-Kaese-Sauce',
        description: 'Kaese macht Brokkoli unwiderstehlich.',
        prepMinutes: 20,
        costPerPortion: 1.20,
        minChildAge: 1,
        ingredients: ['250g Reis', '300g Brokkoli', '100ml Sahne', '80g Kaese'],
        steps: [
          'Reis kochen.',
          'Brokkoli daempfen.',
          'Sahne + Kaese erhitzen.',
          'Alles vermischen.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip:
            'Nenne Brokkoli "kleine Baeume" — Kinder essen lieber was lustig klingt.'),
    FamilyRecipe(
        id: '',
        title: 'Kartoffel-Wedges mit Quark-Dip',
        description: 'Knusprig wie Pommes, aber aus dem Ofen.',
        prepMinutes: 30,
        costPerPortion: 1.00,
        minChildAge: 1,
        ingredients: [
          '800g Kartoffeln',
          '2 EL Olivenoel',
          'Paprikapulver',
          '200g Quark',
          '1 Gurke'
        ],
        steps: [
          'Kartoffeln in Spalten schneiden.',
          'Mit Oel + Paprika mischen.',
          '25 Min bei 200 Grad backen.',
          'Gurke in Quark raspeln.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip:
            'Kinder duerfen die Kartoffeln mit Haenden einoelen — matschen erlaubt!'),
    FamilyRecipe(
        id: '',
        title: 'Milchreis mit Zimt und Beeren',
        description: 'Cremig, suess, troestend. Perfekt am Abend.',
        prepMinutes: 25,
        costPerPortion: 0.90,
        minChildAge: 1,
        ingredients: [
          '200g Milchreis',
          '800ml Milch',
          '2 EL Zucker',
          'Zimt',
          '150g Beeren'
        ],
        steps: [
          'Milch aufkochen.',
          'Reis einruehren, 25 Min koecheln.',
          'Zucker rein.',
          'Mit Zimt + Beeren servieren.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip:
            'Gemeinsam ruehren: Ab 3 Jahren mit langem Loeffel helfen lassen.'),
    FamilyRecipe(
        id: '',
        title: 'Gemuesesticks mit Hummus',
        description: 'Kein Kochen noetig! Bunt, gesund, fingerfood.',
        prepMinutes: 10,
        costPerPortion: 1.30,
        minChildAge: 1,
        ingredients: ['2 Karotten', '1 Gurke', '1 Paprika', '200g Hummus'],
        steps: [
          'Gemuese in Sticks schneiden.',
          'Hummus in Schale.',
          'Bunt anrichten.',
          'Zusammen dippen!'
        ],
        allergensFree: ['nuesse', 'ei', 'laktose'],
        season: '',
        tip: 'Kinder essen mehr Gemuese wenn sie es selbst dippen duerfen.'),
    FamilyRecipe(
        id: '',
        title: 'Wraps mit Frischkaese',
        description: 'Rollen, fuellen, reinbeissen. Kinder bauen selbst.',
        prepMinutes: 10,
        costPerPortion: 1.40,
        minChildAge: 2,
        ingredients: [
          '4 Wraps',
          '200g Frischkaese',
          '1 Karotte',
          '1/2 Gurke',
          'Salat'
        ],
        steps: [
          'Wraps mit Frischkaese bestreichen.',
          'Gemuese drauf verteilen.',
          'Einrollen.',
          'Halbieren.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip:
            'Jedes Kind fuellt seinen Wrap selbst — das macht eigenstaendig + stolz.'),
    FamilyRecipe(
        id: '',
        title: 'Bananen-Hafer-Kekse (ohne Zucker)',
        description: '3 Zutaten, 15 Min, gesund und suess.',
        prepMinutes: 15,
        costPerPortion: 0.50,
        minChildAge: 1,
        ingredients: [
          '2 reife Bananen',
          '150g Haferflocken',
          'Optional: Kakao oder Rosinen'
        ],
        steps: [
          'Bananen zerquetschen.',
          'Haferflocken untermischen.',
          'Kleine Haufen aufs Blech.',
          '12 Min bei 180 Grad backen.'
        ],
        allergensFree: ['nuesse', 'ei', 'laktose'],
        season: '',
        tip:
            'Kinder ab 2 koennen Bananen matschen — perfekt zum gemeinsam Backen.'),
  ];
}
