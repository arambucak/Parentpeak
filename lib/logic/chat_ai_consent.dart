import 'package:parentpeak/logic/account_ai_consent.dart';

class ChatAiConsent extends AccountAiConsent {
  ChatAiConsent({super.scopeProvider, super.persist})
      : super(storagePrefix: 'chat.ai_consent.v1');

  static final instance = ChatAiConsent();
}
