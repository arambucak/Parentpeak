import 'package:parentpeak/logic/development_report_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevelopmentReportService {
  DevelopmentReportService({
    DevelopmentReportConsent? consent,
    GeminiAIService? aiService,
  }) : consent = consent ?? DevelopmentReportConsent.instance,
       _aiService = aiService;

  final DevelopmentReportConsent consent;
  final GeminiAIService? _aiService;

  String _reportKey(String scope) => 'dev.ai_report.v4.$scope';
  String _historyKey(String scope) => 'dev.report_history.v2.$scope';

  Future<String?> loadReport(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    consent.requireScope(scope);
    return prefs.getString(_reportKey(scope));
  }

  Future<List<String>> loadHistory(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    consent.requireScope(scope);
    return prefs.getStringList(_historyKey(scope)) ?? [];
  }

  Future<String> generate(
    String prompt, {
    required String expectedScope,
    void Function()? requestGuard,
  }) async {
    await consent.require(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    void guard() {
      requestGuard?.call();
      consent.requireScope(expectedScope);
      if (prefs.getBool('${consent.storagePrefix}.$expectedScope') != true) {
        throw const DevelopmentReportConsentRequiredException();
      }
    }

    guard();
    final text = await (_aiService ?? GeminiAIService()).generateText(
      prompt,
      requestGuard: guard,
    );
    guard();
    await consent.require(expectedScope);
    guard();
    return text;
  }

  Future<void> saveReport(
    String text, {
    required String expectedScope,
    required void Function() requestGuard,
  }) async {
    await consent.require(expectedScope);
    final prefs = await SharedPreferences.getInstance();
    void guard() {
      requestGuard();
      consent.requireScope(expectedScope);
      if (prefs.getBool('${consent.storagePrefix}.$expectedScope') != true) {
        throw const DevelopmentReportConsentRequiredException();
      }
    }

    guard();
    if (!await prefs.setString(_reportKey(expectedScope), text)) {
      throw StateError('Could not persist development report.');
    }
    guard();
    final history = prefs.getStringList(_historyKey(expectedScope)) ?? [];
    history.insert(0, '${DateTime.now().toIso8601String()}|||$text');
    if (history.length > 12) history.removeRange(12, history.length);
    if (!await prefs.setStringList(_historyKey(expectedScope), history)) {
      throw StateError('Could not persist development report history.');
    }
    guard();
  }
}
