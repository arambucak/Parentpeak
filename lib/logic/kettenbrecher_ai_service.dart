import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';

class KettenbrecherAiService {
  KettenbrecherAiService({GeminiAIService? geminiService})
      : _geminiService = geminiService ??
            (APIConfig.isGeminiApiKeyConfigured()
                ? GeminiAIService(apiKey: APIConfig.getGeminiApiKey())
                : null);

  final GeminiAIService? _geminiService;

  bool get isAvailable => _geminiService != null;

  Future<String?> generateGuerillaMappingJson({
    required String baseRecipeTitle,
    required String parentPrompt,
    required List<String> candidateIngredients,
  }) async {
    if (_geminiService == null) return null;

    final prompt = '''
Erzeuge ein JSON ohne Zusatztext für ein Parentpeak Guerilla-Rezept-Mapping.

Eingaben:
- Rezept: $baseRecipeTitle
- Eltern-Briefing: $parentPrompt
- Kandidaten: ${candidateIngredients.join(', ')}

Ausgabeformat (exakt):
{
  "aiTarnMapping": [
    {
      "ingredientKey": "zucchini",
      "hiddenIngredient": "Zucchini",
      "camouflageMethod": "...",
      "textureHint": "...",
      "colorHint": "..."
    }
  ]
}

Regeln:
- Maximal 5 Eintraege
- Nur Kandidaten verwenden
- Methoden alltagstauglich und kindgerecht formulieren
- Keine Markdown-Formatierung
''';

    final response = await _geminiService!.chat(prompt);
    if (response.trim().isEmpty) return null;
    return response;
  }
}
