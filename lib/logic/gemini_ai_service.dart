import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/language_service.dart';
import 'package:parentpeak/logic/privacy_sanitizer.dart';

class GeminiAIService {
  GeminiAIService({String? modelName, BackendApiClient? apiClient})
      : _modelName = modelName ?? APIConfig.getGeminiModelName(),
        _apiClient = apiClient ?? BackendServiceFactory.createApiClient();

  final String _modelName;
  final BackendApiClient? _apiClient;

  Future<String> generateText(
    String prompt, {
    String? systemInstruction,
    bool useGoogleSearch = false,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    String? appLanguage,
  }) async {
    final response = await generate(
      prompt,
      systemInstruction: systemInstruction,
      useGoogleSearch: useGoogleSearch,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      appLanguage: appLanguage,
    );
    return response.text;
  }

  Future<GeminiProxyResponse> generate(
    String prompt, {
    String? systemInstruction,
    bool useGoogleSearch = false,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    String? appLanguage,
  }) async {
    final client = _apiClient;
    if (client == null) {
      throw Exception('Backend-URL nicht konfiguriert.');
    }

    final response = await client.postJson('/ai/generate', {
      'model': _modelName,
      'prompt': PrivacySanitizer.sanitizeForAi(prompt),
      if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
        'systemInstruction': systemInstruction.trim(),
      'useGoogleSearch': useGoogleSearch,
      'language': appLanguage ?? LanguageService.activeCode,
      if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
      if (imageBytes != null) 'imageMimeType': imageMimeType,
    });
    final text = response['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      throw Exception('KI-Dienst lieferte keine Antwort.');
    }
    final groundingUrls = (response['groundingUrls'] as List<dynamic>?)
            ?.map((url) => url.toString())
            .where((url) => url.startsWith('https://'))
            .toList() ??
        const <String>[];
    return GeminiProxyResponse(text: text, groundingUrls: groundingUrls);
  }

  Stream<String> chatWithStreaming(String userMessage) async* {
    try {
      yield await generateText(
        userMessage,
        systemInstruction: APIConfig.parentAssistantSystemPrompt,
      );
    } catch (error) {
      debugPrint('GeminiAIService.chatWithStreaming(): $error');
      yield 'Fehler: $error';
    }
  }

  Future<String> chatWithHistory(List<Map<String, String>> messages) async {
    try {
      return await generateText(
        _historyPrompt(messages),
        systemInstruction: APIConfig.parentAssistantSystemPrompt,
      );
    } catch (error) {
      return 'Fehler: $error';
    }
  }

  Future<String> chat(String userMessage) async {
    try {
      return await generateText(
        userMessage,
        systemInstruction: APIConfig.parentAssistantSystemPrompt,
      );
    } catch (error) {
      return 'Fehler: $error';
    }
  }

  Stream<String> chatWithHistoryStreaming(
    List<Map<String, String>> messages,
  ) async* {
    yield await chatWithHistory(messages);
  }

  String _historyPrompt(List<Map<String, String>> messages) {
    final safeMessages = PrivacySanitizer.sanitizeHistoryForAi(messages);
    return safeMessages.map((message) {
      final role = message['role'] == 'user' ? 'User' : 'Assistant';
      return '$role: ${message['content'] ?? ''}';
    }).join('\n\n');
  }
}

class GeminiProxyResponse {
  const GeminiProxyResponse({required this.text, required this.groundingUrls});

  final String text;
  final List<String> groundingUrls;
}
