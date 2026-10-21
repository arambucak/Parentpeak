import 'package:parentpeak/logic/account_ai_consent.dart';

class ChatMemoryConsentRequiredException implements Exception {
  const ChatMemoryConsentRequiredException();
}

class ChatMemoryConsent extends AccountAiConsent {
  ChatMemoryConsent({
    super.scopeProvider,
    Future<bool> Function(String key, bool value)? persist,
  }) : super(
          storagePrefix: 'chat.memory_consent.v1',
          persist: persist,
          requiredException: () => const ChatMemoryConsentRequiredException(),
        );

  static const version = 'chat-memory-v1';
  static final instance = ChatMemoryConsent();
}
