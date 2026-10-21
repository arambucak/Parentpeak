import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RitualAiService {
  RitualAiService({AccountAiConsent? consent, GeminiAIService? aiService})
      : consent = consent ?? ritualConsent,
        _aiService = aiService;

  static final ritualConsent = AccountAiConsent(
    storagePrefix: 'ritual.ai_consent.v1',
  );

  final AccountAiConsent consent;
  final GeminiAIService? _aiService;

  Future<String> generate(
    String prompt, {
    required String systemInstruction,
    required String languageCode,
    required String expectedScope,
    required void Function() requestGuard,
  }) async {
    final revision = consent.revision(expectedScope);
    await consent.require(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    void guard() {
      requestGuard();
      consent.requireRevision(expectedScope, revision);
      if (prefs.getBool('${consent.storagePrefix}.$expectedScope') != true) {
        throw const AccountAiConsentRequiredException();
      }
    }

    guard();
    var ai = _aiService;
    if (ai == null) {
      final client = BackendServiceFactory.createVerifiedApiClient();
      if (client == null) throw StateError('Ritual AI backend unavailable');
      ai = GeminiAIService(apiClient: client);
    }
    final response = await ai.generateText(
      prompt,
      systemInstruction: systemInstruction,
      appLanguage: languageCode,
      requestGuard: guard,
    );
    await consent.require(expectedScope);
    guard();
    return response;
  }
}
