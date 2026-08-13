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

  static const _cacheKey = 'familyküche.recipes';
  static const _savedKey = 'familyküche.saved';

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
    // Allergien aus SharedPreferences (später aus Profil erweiterbar)
    final prefs = await SharedPreferences.getInstance();
    _allergies = prefs.getStringList('familyküche.allergies') ?? [];
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
      debugPrint(
          '\u{274C} FamilyRecipeService: KEIN API-Key! .env nicht geladen?');
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
Generiere EIN kinderfreundliches Familien-Rezept auf Deutsch.

Kontext:
- Juengstes Kind: $ageText
- Saison: $season (nutze saisonale Zutaten)
- $allergyText
- Budget: guenstig (unter 4 EUR pro Portion)
- Zeit: maximal 35 Minuten
- Portionen: 4

Regeln:
- VIELFALT: Wechsle zwischen Fleisch (Haehnchen, Hackfleisch, Schnitzel), Fisch (Lachs, Fischstaebchen), und vegetarisch. NICHT immer das gleiche.
- Das Rezept MUSS für das angegebene Kindesalter sicher und geeignet sein
- Einfache Zutaten die man im Supermarkt bekommt
- Kinder müssen es MOEGEN (nicht zu scharf, nicht zu bitter)
- Beliebt bei Kindern: Nudeln, Reis, Kartoffeln, Chicken Nuggets, Pizza, Pfannkuchen, Fischstaebchen, Bolognese, Schnitzel, Mac&Cheese
- Gib einen konkreten Eltern-Tipp (picky eater trick, gemeinsam kochen, etc.)
- allergensFree: nur auflisten wenn das Rezept tatsaechlich FREI von Allergenen ist. Wenn Milch drin ist, NICHT "laktose" listen.

Antworte NUR mit einem gueltigen JSON-Objekt (kein Markdown, kein Text davor/danach):
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
  "tip": "Lass dein Kind das Hack kruemeln - wer mithilft isst lieber."
}
''';

    try {
      final modelName = APIConfig.getGeminiModelName();
      debugPrint(
          'FamilyRecipeService: Verwende Modell=$modelName, Key-Laenge=${apiKey.length}');

      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        systemInstruction: Content.text(
            'Du bist ein Familien-Koch-Assistent. Antworte IMMER NUR mit gueltigem JSON. '
            'Kein Markdown, kein Text davor oder danach. Nur ein JSON-Objekt.'),
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '';
      debugPrint('FamilyRecipeService: Gemini Antwort (${raw.length} Zeichen)');

      if (raw.isEmpty) {
        debugPrint('FamilyRecipeService: Leere Antwort von Gemini!');
        return _fallbackRecipe();
      }

      final recipe = _parseRecipe(raw);
      if (recipe != null) return recipe;
      debugPrint(
          'FamilyRecipeService: Parsing fehlgeschlagen, Antwort: ${raw.substring(0, raw.length.clamp(0, 200))}');
      return _fallbackRecipe();
    } catch (e, stack) {
      debugPrint('FamilyRecipeService: KI-Fehler: $e');
      debugPrint(
          'FamilyRecipeService: Stack: ${stack.toString().split('\n').take(3).join('\n')}');
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

  String _currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'Frühling';
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
    // FLEISCH
    FamilyRecipe(
        id: '',
        title: 'Spaghetti Bolognese',
        description: 'DER Klassiker — Kinder-Liebling Nr. 1 weltweit.',
        prepMinutes: 30,
        costPerPortion: 2.00,
        minChildAge: 1,
        ingredients: [
          '400g Spaghetti',
          '300g Hackfleisch',
          '1 Dose Tomaten',
          '1 Karotte',
          '1 Zwiebel',
          'Olivenoel'
        ],
        steps: [
          'Zwiebel + Karotte fein hacken, in Oel anbraten.',
          'Hack dazu, kruemelig braten.',
          'Tomaten dazu, 15 Min koecheln.',
          'Nudeln kochen, servieren.'
        ],
        allergensFree: ['nuesse'],
        season: '',
        tip:
            'Lass dein Kind das Hackfleisch kruemeln — wer mithilft isst lieber.'),
    FamilyRecipe(
        id: '',
        title: 'Haehnchen-Nuggets aus dem Ofen',
        description: 'Knusprig wie aus dem Restaurant aber gesunder.',
        prepMinutes: 25,
        costPerPortion: 2.20,
        minChildAge: 1,
        ingredients: [
          '500g Haenchenbrust',
          '100g Semmelbrösel',
          '1 Ei',
          'Paprikapulver',
          'Salz'
        ],
        steps: [
          'Haehnchen in Stuecke schneiden.',
          'In Ei wenden, dann in Semmelbrösel.',
          '15 Min bei 200 Grad backen.',
          'Mit Ketchup oder Gurkensticks servieren.'
        ],
        allergensFree: ['nuesse'],
        season: '',
        tip:
            'Kinder ab 3 können beim Panieren helfen — Hände eintauchen macht Spass!'),
    FamilyRecipe(
        id: '',
        title: 'Mini-Schnitzel mit Kartoffelpueree',
        description: 'Schnell, saftig, und das Pueree ist wie eine Umarmung.',
        prepMinutes: 30,
        costPerPortion: 2.50,
        minChildAge: 1,
        ingredients: [
          '4 kleine Schweineschnitzel',
          '100g Semmelbrösel',
          '1 Ei',
          '600g Kartoffeln',
          '50ml Milch',
          'Butter'
        ],
        steps: [
          'Kartoffeln kochen, stampfen mit Milch + Butter.',
          'Schnitzel klopfen, in Ei + Brösel wenden.',
          'In Pfanne goldbraun braten.',
          'Mit Pueree + Gurkensalat servieren.'
        ],
        allergensFree: ['nuesse'],
        season: '',
        tip:
            'Kleine Schnitzel die in Kinderhände passen wirken einladender als grosse.'),
    // FISCH
    FamilyRecipe(
        id: '',
        title: 'Selbstgemachte Fischstaebchen',
        description: 'Besser als TK — und in 20 Min fertig.',
        prepMinutes: 20,
        costPerPortion: 2.30,
        minChildAge: 1,
        ingredients: [
          '400g Fischfilet (Kabeljau/Seelachs)',
          '80g Semmelbrösel',
          '1 Ei',
          'Zitrone',
          'Salz'
        ],
        steps: [
          'Fisch in Staebchen schneiden.',
          'In Ei, dann Semmelbrösel wenden.',
          'In Pfanne mit wenig Oel 3-4 Min pro Seite braten.',
          'Mit Zitrone und Kartoffeln servieren.'
        ],
        allergensFree: ['nuesse', 'laktose'],
        season: '',
        tip:
            'Fischstaebchen-Form macht Fisch für Kinder attraktiver als ein ganzes Filet.'),
    FamilyRecipe(
        id: '',
        title: 'Lachs-Nudeln mit Sahne-Sauce',
        description: 'Cremig, mild, reich an Omega-3 für kleine Gehirne.',
        prepMinutes: 20,
        costPerPortion: 3.00,
        minChildAge: 2,
        ingredients: [
          '300g Pasta',
          '200g Lachsfilet',
          '150ml Sahne',
          '1 EL Butter',
          'Dill',
          'Salz'
        ],
        steps: [
          'Nudeln kochen.',
          'Lachs in Stuecke schneiden, in Butter anbraten.',
          'Sahne dazu, kurz aufkochen.',
          'Mit Nudeln vermischen, Dill drauf.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip:
            'Lachs ist mild genug für Kinder die keinen Fischgeschmack moegen.'),
    // VEGETARISCH
    FamilyRecipe(
        id: '',
        title: 'Pizza vom Blech (mit Kindern belegt)',
        description: 'Jedes Kind belegt seine eigene Ecke — Spass garantiert.',
        prepMinutes: 30,
        costPerPortion: 1.50,
        minChildAge: 1,
        ingredients: [
          '1 Fertig-Pizzateig (oder 500g Mehl + Hefe)',
          '200ml Tomatensauce',
          '200g Kaese',
          'Belag nach Wunsch: Mais, Salami, Paprika'
        ],
        steps: [
          'Teig ausrollen auf Blech.',
          'Sauce verteilen.',
          'Kinder belegen lassen!',
          '12-15 Min bei 220 Grad backen.'
        ],
        allergensFree: ['nuesse'],
        season: '',
        tip: 'Jedes Familienmitglied bekommt ein Viertel zum Selbst-Belegen.'),
    FamilyRecipe(
        id: '',
        title: 'Mac and Cheese (Nudeln mit Kaese)',
        description:
            'Cremig, kaesig, geht immer. Comfort-Food für die ganze Familie.',
        prepMinutes: 20,
        costPerPortion: 1.30,
        minChildAge: 1,
        ingredients: [
          '400g Makkaroni',
          '200ml Milch',
          '150g geriebener Kaese',
          '1 EL Butter',
          '1 EL Mehl',
          'Muskat'
        ],
        steps: [
          'Nudeln kochen.',
          'Butter schmelzen, Mehl einruehren.',
          'Milch dazu, glatt ruehren.',
          'Kaese unterheben bis cremig.',
          'Nudeln in Sauce wenden.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip:
            'Kaese-Faeden ziehen finden Kinder faszinierend — das ist Teil des Spassses!'),
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
        title: 'Kartoffelsuppe mit Wuerstchen',
        description:
            'Waermt von innen. Kinder lieben die Wuerstchen-Stuecke drin.',
        prepMinutes: 25,
        costPerPortion: 1.40,
        minChildAge: 1,
        ingredients: [
          '600g Kartoffeln',
          '1 Karotte',
          '500ml Bruehe',
          '2 Wiener Wuerstchen',
          '100ml Sahne'
        ],
        steps: [
          'Kartoffeln + Karotte wuerfeln, in Bruehe kochen.',
          'Puerieren (nicht ganz glatt — Stuecke lassen).',
          'Sahne einruehren.',
          'Wuerstchen in Scheiben schneiden, dazu geben.'
        ],
        allergensFree: ['nuesse', 'ei'],
        season: '',
        tip: 'Lass dein Kind die Wuerstchen mit dem Kindermesser schneiden.'),
    FamilyRecipe(
        id: '',
        title: 'Reis-Pfanne mit Haehnchen und Gemuese',
        description: 'Bunt, schnell, alles in einer Pfanne.',
        prepMinutes: 25,
        costPerPortion: 2.00,
        minChildAge: 1,
        ingredients: [
          '250g Reis',
          '300g Haenchenbrust',
          '1 Paprika',
          '1 kleine Zucchini',
          '2 EL Sojasauce',
          'Oel'
        ],
        steps: [
          'Reis kochen.',
          'Haehnchen in Streifen schneiden, anbraten.',
          'Gemuese dazu, 5 Min braten.',
          'Reis unterheben, Sojasauce drueber.'
        ],
        allergensFree: ['nuesse', 'ei', 'laktose'],
        season: '',
        tip:
            'Wenn Kinder das Gemuese in lustigen Formen schneiden hilft das beim Probieren.'),
  ];
}
