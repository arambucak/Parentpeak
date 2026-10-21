import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyReflectionAiService {
  WeeklyReflectionAiService({
    AccountAiConsent? consent,
    GeminiAIService? aiService,
  })  : consent = consent ?? weeklyConsent,
        _aiService = aiService;

  static final weeklyConsent = AccountAiConsent(
    storagePrefix: 'weekly_reflection.ai_consent.v1',
  );

  final AccountAiConsent consent;
  final GeminiAIService? _aiService;

  Future<String> generate(
    String prompt, {
    required String expectedScope,
    required String languageCode,
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
      if (client == null) {
        throw StateError('Weekly reflection backend unavailable');
      }
      ai = GeminiAIService(apiClient: client);
    }
    final response = await ai.generateText(
      prompt,
      appLanguage: languageCode,
      systemInstruction: APIConfig.parentAssistantSystemPrompt,
      requestGuard: guard,
    );
    guard();
    await consent.require(expectedScope);
    guard();
    return response;
  }
}
