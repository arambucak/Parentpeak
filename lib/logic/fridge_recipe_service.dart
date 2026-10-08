import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/fridge_photo_consent.dart';

import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/logic/allergen_guard.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';

/// Phase 3b: KI-Kühlschrank-Foto.
///
/// Aus einem Foto vorhandener Lebensmittel erkennt Gemini die Zutaten und
/// schlägt daraus ein kindgerechtes Rezept vor — unter Berücksichtigung von
/// Alter und Allergien aus dem Kind-Dossier. Das Foto wird NICHT gespeichert,
/// sondern nur zur Analyse an den KI-Dienst gesendet.
class FridgeRecipeService {
  static final FridgeRecipeService instance = FridgeRecipeService();
  FridgeRecipeService({
    GeminiAIService? aiService,
    FridgePhotoConsent? consent,
  }) : _aiService = aiService,
       consent = consent ?? FridgePhotoConsent.instance;
  final GeminiAIService? _aiService;
  final FridgePhotoConsent consent;

  int _childAgeYears = 3;
  List<String> _allergies = [];
  Set<String> _allergenKeys = {};

  /// Lädt Alter (jüngstes Kind) + Allergien aus Profil/Einstellungen.
  Future<String> _ensureContext() async {
    final scope = FamilyHubStore.instance.scope;
    _childAgeYears = 3;
    _allergies = [];
    _allergenKeys = {};
      final profile = await FamilyMatchProfile.load(throwOnError: true);
      if (profile != null && profile.children.isNotEmpty) {
        final youngest = profile.children
            .map((c) => c.ageMonths)
            .reduce((a, b) => a < b ? a : b);
        _childAgeYears = (youngest / 12).round().clamp(0, 16);
      }
    // SICHERHEIT: Allergien aus dem Kind-Dossier (echte Quelle) + Legacy-Key.
    final data = await FamilyHubStore.instance.read(expectedScope: scope);
    final legacy = List<String>.from(
      data[FamilyHubStore.allergyKey] as List? ?? [],
    );
    final fromDossiers = <String>{};
    await KindDossierService.instance.load();
    for (final d in KindDossierService.instance.dossiers) {
      for (final a in d.allergies) {
        final clean = a.trim();
        if (clean.isNotEmpty) fromDossiers.add(clean);
      }
    }
    FamilyHubStore.instance.requireScope(scope);
    _allergies = {...fromDossiers, ...legacy}.toList();
    _allergenKeys = _allergies.map(AllergenGuard.canonicalAllergen).toSet();
    return scope;
  }

  String _ageText() {
    if (_childAgeYears < 1) {
      return 'Baby (6-12 Monate, Brei/Fingerfood, BLW-geeignet)';
    }
    if (_childAgeYears < 3) {
      return 'Kleinkind ($_childAgeYears Jahre, weich, kleine Stücke)';
    }
    if (_childAgeYears < 6) return 'Kita-Kind ($_childAgeYears Jahre, normal)';
    return 'Schulkind ($_childAgeYears Jahre, alles)';
  }

  String _allergyText() => _allergies.isEmpty
      ? 'Keine bekannten Allergien'
      : 'WICHTIG - Das Rezept MUSS frei sein von: ${_allergies.join(", ")}';

  /// Erkennt Zutaten auf einem Foto. Gibt eine Liste erkannter Lebensmittel
  /// zurück (leere Liste bei Fehler). Nicht-essbare Objekte werden ignoriert.
  Future<List<String>> detectIngredients(
    XFile image, {
    required String expectedScope,
    String mimeType = 'image/jpeg',
    String languageCode = 'de',
  }) async {
    await consent.require(expectedScope);
    final scope = await _ensureContext();
    void guard() {
      consent.requireScope(expectedScope);
      FamilyHubStore.instance.requireScope(scope);
    }
    guard();
    await consent.require(expectedScope);
    final imageBytes = await image.readAsBytes();
    guard();
    await consent.require(expectedScope);
    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('FridgeRecipeService: Rate limit erreicht');
      throw AiRateLimitException(AIRateLimiter.limitReachedMessage);
    }

    final outputLanguage = _outputLanguage(languageCode);
    final prompt =
        '''
Auf diesem Foto sind Lebensmittel (z. B. aus einem Kühlschrank oder einer Vorratskammer).
Erkenne NUR die essbaren Lebensmittel/Zutaten, die du sicher siehst.

Regeln:
- Nur essbare Lebensmittel auflisten (keine Verpackungen, Möbel, Hände, sonstige Objekte).
- Bezeichnungen auf $outputLanguage, im Singular oder als übliche Zutat (z. B. "Eier", "Karotten", "Käse").
- Wenn du unsicher bist, lieber weglassen.
- Maximal 20 Zutaten.

Antworte NUR mit einem gültigen JSON-Array aus Strings (kein Markdown, kein Text davor/danach):
["Eier", "Karotten", "Käse", "Milch"]
''';

    try {
      final modelName = APIConfig.getGeminiModelName();
      await consent.require(expectedScope);
      guard();
      final raw = await (_aiService ?? GeminiAIService(modelName: modelName)).generateText(
        prompt,
        systemInstruction:
            'Du erkennst Lebensmittel auf Fotos. Antworte IMMER NUR mit einem '
            'gültigen JSON-Array aus Zutaten-Namen auf $outputLanguage. Kein Markdown.',
        imageBytes: imageBytes,
        imageMimeType: mimeType,
        appLanguage: languageCode,
        requestGuard: guard,
      );
      guard();
      await consent.require(expectedScope);
      await AIRateLimiter.recordRequest();
      guard();
      await consent.require(expectedScope);
      return _parseIngredientList(raw);
    } on FamilyHubAccountChanged {
      rethrow;
    } on FridgePhotoConsentRequiredException {
      rethrow;
    } catch (e) {
      debugPrint('FridgeRecipeService.detectIngredients: $e');
      return [];
    }
  }

  /// Generiert ein kindgerechtes Rezept aus den (vom Nutzer bestätigten)
  /// Zutaten. Gibt null zurück, wenn nichts erzeugt werden konnte.
  Future<FamilyRecipe?> generateFromIngredients(
    List<String> ingredients, {
    required String expectedScope,
    String languageCode = 'de',
  }) async {
    await consent.require(expectedScope);
    final scope = await _ensureContext();
    void guard() {
      consent.requireScope(expectedScope);
      FamilyHubStore.instance.requireScope(scope);
    }
    guard();
    final clean = ingredients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (clean.isEmpty) return null;

    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('FridgeRecipeService: Rate limit erreicht (generate)');
      throw AiRateLimitException(AIRateLimiter.limitReachedMessage);
    }

    final outputLanguage = _outputLanguage(languageCode);
    final prompt =
        '''
Erstelle EIN kinderfreundliches Familien-Rezept auf $outputLanguage, das möglichst viele
dieser vorhandenen Zutaten nutzt:
${clean.join(", ")}

Kontext:
- Jüngstes Kind: ${_ageText()}
- ${_allergyText()}
- Zeit: möglichst unter 30 Minuten
- Portionen: 4

Regeln:
- Nutze bevorzugt die vorhandenen Zutaten. Wenn wenige Grund-Zutaten fehlen
  (z. B. Salz, Öl, Gewürze), dürfen sie ergänzt werden.
- Das Rezept MUSS für das angegebene Kindesalter sicher und geeignet sein.
- Kinder müssen es mögen (nicht zu scharf, nicht zu bitter).
- Liste unter "missingIngredients" die Zutaten auf, die NICHT in der vorhandenen
  Liste stehen, aber fürs Rezept gebraucht werden (für die Einkaufsliste).
- Alle nutzersichtbaren JSON-Werte müssen auf $outputLanguage sein. Die JSON-Schlüssel bleiben exakt wie vorgegeben.

Antworte NUR mit einem gültigen JSON-Objekt (kein Markdown, kein Text davor/danach):
{
  "title": "Name des Gerichts",
  "description": "1 Satz warum Kinder das mögen",
  "prepMinutes": 25,
  "minChildAge": 2,
  "ingredients": ["500g Nudeln", "300g Hackfleisch"],
  "missingIngredients": ["1 Dose Tomaten"],
  "steps": ["Schritt 1.", "Schritt 2."],
  "tip": "Ein kurzer Eltern-Tipp."
}
''';

    try {
      final modelName = APIConfig.getGeminiModelName();
      await consent.require(expectedScope);
      guard();
      final raw = await (_aiService ?? GeminiAIService(modelName: modelName)).generateText(
        prompt,
        systemInstruction:
            'Du bist ein Familien-Koch-Assistent. Antworte IMMER NUR mit gültigem '
            'JSON. Kein Markdown, kein Text davor oder danach. Nur ein JSON-Objekt.',
        appLanguage: languageCode,
        requestGuard: guard,
      );
      guard();
      await consent.require(expectedScope);
      await AIRateLimiter.recordRequest();
      guard();
      await consent.require(expectedScope);
      final recipe = _parseRecipe(raw);
      if (recipe == null) return null;
      // SICHERHEIT: Kühlschrank-Rezept gegen die Allergene gegenprüfen. Enthält
      // es ein Allergen, nicht ausliefern (die UI zeigt dann eine Warnung).
      if (!AllergenGuard.isRecipeSafe(recipe, _allergenKeys)) {
        debugPrint('FridgeRecipeService: Rezept enthält Allergen → verworfen');
        return null;
      }
      return recipe;
    } on FamilyHubAccountChanged {
      rethrow;
    } on FridgePhotoConsentRequiredException {
      rethrow;
    } catch (e) {
      debugPrint('FridgeRecipeService.generateFromIngredients: $e');
      return null;
    }
  }

  /// Ermittelt die fehlenden Zutaten für die Einkaufsliste: alles, was im
  /// Rezept steht, aber (nach einfachem Namensvergleich) nicht in [available].
  List<String> missingIngredients(FamilyRecipe recipe, List<String> available) {
    final have = available
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    bool isAvailable(String recipeIngredient) {
      final lower = recipeIngredient.toLowerCase();
      return have.any((h) => lower.contains(h) || h.contains(_coreWord(lower)));
    }

    return recipe.ingredients.where((ing) => !isAvailable(ing)).toList();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  /// Mappt einen Sprachcode auf die (deutsche) Bezeichnung für den KI-Prompt,
  /// damit Gemini in der aktiven App-Sprache antwortet.
  static String _outputLanguage(String languageCode) => switch (languageCode) {
    'de' => 'Deutsch',
    'tr' => 'Türkisch',
    'ku' => 'Kurmandschi (lateinische Schrift)',
    _ => 'Englisch',
  };

  // Grobes Kernwort einer Zutatenzeile (letztes Wort, oft der Zutatenname).
  String _coreWord(String s) {
    final parts = s
        .replaceAll(RegExp(r'[0-9]'), '')
        .trim()
        .split(RegExp(r'\s+'));
    return parts.isEmpty ? s : parts.last;
  }

  List<String> _parseIngredientList(String raw) {
    try {
      var text = raw.trim();
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final list = jsonDecode(text.substring(start, end + 1)) as List;
      final seen = <String>{};
      final out = <String>[];
      for (final e in list) {
        final s = e.toString().trim();
        if (s.isEmpty) continue;
        final key = s.toLowerCase();
        if (seen.add(key)) out.add(s);
      }
      return out.take(20).toList();
    } catch (e) {
      debugPrint('FridgeRecipeService._parseIngredientList: $e');
      return [];
    }
  }

  FamilyRecipe? _parseRecipe(String raw) {
    try {
      var text = raw.trim();
      text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1) return null;
      final map =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      // "missingIngredients" gehört nicht ins FamilyRecipe-Modell — wir hängen
      // sie den Zutaten NICHT an, sondern der Screen ermittelt Fehlendes selbst
      // über missingIngredients(). Falls das Modell sie liefert, ignorieren wir
      // sie hier bewusst, um das Modell schlank zu halten.
      map['id'] = 'fridge_${DateTime.now().millisecondsSinceEpoch}';
      map['costPerPortion'] = map['costPerPortion'] ?? 2.0;
      map['season'] = map['season'] ?? 'alle';
      return FamilyRecipe.fromJson(map);
    } catch (e) {
      debugPrint('FridgeRecipeService._parseRecipe: $e');
      return null;
    }
  }
}
