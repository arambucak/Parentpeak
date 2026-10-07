import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/language_service.dart';
import 'package:parentpeak/logic/privacy_sanitizer.dart';
import 'package:parentpeak/logic/chat_memory_consent.dart';

class GeminiAIService {
  GeminiAIService({
    String? modelName,
    BackendApiClient? apiClient,
    ChatMemoryConsent? memoryConsent,
  }) : _modelName = modelName ?? APIConfig.getGeminiModelName(),
       _apiClient = apiClient ?? BackendServiceFactory.createApiClient(),
       memoryConsent = memoryConsent ?? ChatMemoryConsent.instance;

  final String _modelName;
  final BackendApiClient? _apiClient;
  final ChatMemoryConsent memoryConsent;

  Future<String> generateText(
    String prompt, {
    String? systemInstruction,
    bool useGoogleSearch = false,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    String? appLanguage,
    String? childProfileId,
    void Function()? requestGuard,
  }) async {
    final response = await generate(
      prompt,
      systemInstruction: systemInstruction,
      useGoogleSearch: useGoogleSearch,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
      appLanguage: appLanguage,
      childProfileId: childProfileId,
      requestGuard: requestGuard,
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
    String? childProfileId,
    void Function()? requestGuard,
  }) async {
    final owner = memoryConsent.scope;
    final memoryChildId = childProfileId?.trim();
    final useMemory =
        memoryChildId != null &&
        memoryChildId.isNotEmpty &&
        await memoryConsent.hasConsent();
    final revision = memoryConsent.revision(owner);
    void guard() {
      requestGuard?.call();
      if (useMemory) memoryConsent.requireRevision(owner, revision);
    }

    if (useMemory) await memoryConsent.require(owner);
    guard();
    final client = requestGuard == null && !useMemory
        ? _apiClient
        : _apiClient?.withRequestGuard(guard);
    if (client == null) {
      throw Exception('Backend-URL nicht konfiguriert.');
    }

    final Map<String, dynamic> response;
    try {
      response = await client.postJson(
      '/ai/generate',
      {
        'model': _modelName,
        'prompt': PrivacySanitizer.sanitizeForAi(prompt),
        if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
          'systemInstruction': systemInstruction.trim(),
        'useGoogleSearch': useGoogleSearch,
        'language': appLanguage ?? LanguageService.activeCode,
        if (useMemory) 'childProfileId': memoryChildId,
        if (useMemory) 'memoryConsentVersion': ChatMemoryConsent.version,
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
        if (imageBytes != null) 'imageMimeType': imageMimeType,
      },
      // Grounding-Suche darf serverseitig bis ~35s dauern; mehr Client-Puffer,
      // besonders auf Mobilfunk, damit echte Antworten nicht abreißen.
      timeout: useGoogleSearch
          ? const Duration(seconds: 50)
          : const Duration(seconds: 30),
      );
    } on BackendApiException catch (error) {
      guard();
      if (useMemory && error.isForbidden) {
        throw const ChatMemoryConsentRequiredException();
      }
      rethrow;
    }
    final text = response['text']?.toString().trim();
    guard();
    if (useMemory) await memoryConsent.require(owner);
    guard();
    if (text == null || text.isEmpty) {
      throw Exception('KI-Dienst lieferte keine Antwort.');
    }
    final groundingUrls =
        (response['groundingUrls'] as List<dynamic>?)
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

  Future<String> chatWithHistory(
    List<Map<String, String>> messages, {
    String? childProfileId,
    void Function()? requestGuard,
  }) async {
    try {
      return await generateText(
        _historyPrompt(messages),
        systemInstruction: APIConfig.parentAssistantSystemPrompt,
        childProfileId: childProfileId,
        requestGuard: requestGuard,
      );
    } on ChatMemoryConsentRequiredException {
      rethrow;
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
    return safeMessages
        .map((message) {
          final role = message['role'] == 'user' ? 'User' : 'Assistant';
          return '$role: ${message['content'] ?? ''}';
        })
        .join('\n\n');
  }
}

class GeminiProxyResponse {
  const GeminiProxyResponse({required this.text, required this.groundingUrls});

  final String text;
  final List<String> groundingUrls;
}
