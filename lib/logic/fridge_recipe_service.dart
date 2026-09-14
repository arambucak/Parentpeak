import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';

/// Phase 3b: KI-Kühlschrank-Foto.
///
/// Aus einem Foto vorhandener Lebensmittel erkennt Gemini die Zutaten und
/// schlägt daraus ein kindgerechtes Rezept vor — unter Berücksichtigung von
/// Alter und Allergien aus dem Kind-Dossier. Das Foto wird NICHT gespeichert,
/// sondern nur zur Analyse an den KI-Dienst gesendet.
class FridgeRecipeService {
  static final FridgeRecipeService instance = FridgeRecipeService._();
  FridgeRecipeService._();

  int _childAgeYears = 3;
  List<String> _allergies = [];
  bool _loaded = false;

  /// Lädt Alter (jüngstes Kind) + Allergien aus Profil/Einstellungen.
  Future<void> _ensureContext() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final profile = await FamilyMatchProfile.load();
      if (profile != null && profile.children.isNotEmpty) {
        final youngest = profile.children
            .map((c) => c.ageMonths)
            .reduce((a, b) => a < b ? a : b);
        _childAgeYears = (youngest / 12).round().clamp(0, 16);
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      _allergies = prefs.getStringList('familyküche.allergies') ?? [];
    } catch (_) {}
  }

  String _ageText() {
    if (_childAgeYears < 1)
      return 'Baby (6-12 Monate, Brei/Fingerfood, BLW-geeignet)';
    if (_childAgeYears < 3)
      return 'Kleinkind ($_childAgeYears Jahre, weich, kleine Stücke)';
    if (_childAgeYears < 6) return 'Kita-Kind ($_childAgeYears Jahre, normal)';
    return 'Schulkind ($_childAgeYears Jahre, alles)';
  }

  String _allergyText() => _allergies.isEmpty
      ? 'Keine bekannten Allergien'
      : 'WICHTIG - Das Rezept MUSS frei sein von: ${_allergies.join(", ")}';

  /// Erkennt Zutaten auf einem Foto. Gibt eine Liste erkannter Lebensmittel
  /// zurück (leere Liste bei Fehler). Nicht-essbare Objekte werden ignoriert.
  Future<List<String>> detectIngredients(Uint8List imageBytes,
      {String mimeType = 'image/jpeg'}) async {
    await _ensureContext();
    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('FridgeRecipeService: Rate limit erreicht');
      throw AiRateLimitException(AIRateLimiter.limitReachedMessage);
    }

    const prompt = '''
Auf diesem Foto sind Lebensmittel (z. B. aus einem Kühlschrank oder einer Vorratskammer).
Erkenne NUR die essbaren Lebensmittel/Zutaten, die du sicher siehst.

Regeln:
- Nur essbare Lebensmittel auflisten (keine Verpackungen, Möbel, Hände, sonstige Objekte).
- Deutsche Bezeichnungen, im Singular oder als übliche Zutat (z. B. "Eier", "Karotten", "Käse").
- Wenn du unsicher bist, lieber weglassen.
- Maximal 20 Zutaten.

Antworte NUR mit einem gültigen JSON-Array aus Strings (kein Markdown, kein Text davor/danach):
["Eier", "Karotten", "Käse", "Milch"]
''';

    try {
      final modelName = APIConfig.getGeminiModelName();
      final raw = await GeminiAIService(modelName: modelName).generateText(
        prompt,
        systemInstruction:
            'Du erkennst Lebensmittel auf Fotos. Antworte IMMER NUR mit einem '
            'gültigen JSON-Array aus deutschen Zutaten-Namen. Kein Markdown.',
        imageBytes: imageBytes,
        imageMimeType: mimeType,
      );
      await AIRateLimiter.recordRequest();
      return _parseIngredientList(raw);
    } catch (e) {
      debugPrint('FridgeRecipeService.detectIngredients: $e');
      return [];
    }
  }

  /// Generiert ein kindgerechtes Rezept aus den (vom Nutzer bestätigten)
  /// Zutaten. Gibt null zurück, wenn nichts erzeugt werden konnte.
  Future<FamilyRecipe?> generateFromIngredients(
      List<String> ingredients) async {
    await _ensureContext();
    final clean =
        ingredients.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (clean.isEmpty) return null;

    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('FridgeRecipeService: Rate limit erreicht (generate)');
      throw AiRateLimitException(AIRateLimiter.limitReachedMessage);
    }

    final prompt = '''
Erstelle EIN kinderfreundliches Familien-Rezept auf Deutsch, das möglichst viele
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
      final raw = await GeminiAIService(modelName: modelName).generateText(
        prompt,
        systemInstruction:
            'Du bist ein Familien-Koch-Assistent. Antworte IMMER NUR mit gültigem '
            'JSON. Kein Markdown, kein Text davor oder danach. Nur ein JSON-Objekt.',
      );
      await AIRateLimiter.recordRequest();
      return _parseRecipe(raw);
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

  // Grobes Kernwort einer Zutatenzeile (letztes Wort, oft der Zutatenname).
  String _coreWord(String s) {
    final parts =
        s.replaceAll(RegExp(r'[0-9]'), '').trim().split(RegExp(r'\s+'));
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
