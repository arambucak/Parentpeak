import 'package:parentpeak/l10n/app_localizations_all.dart';

class ChatPromptPolicy {
  static String text(String language, String key, [Map<String, String> values = const {}]) {
    return AppStringsManager.getString(language, key).replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) => values[match.group(1)] ?? match.group(0)!,
    );
  }

  static String focus(String topic, String language) {
    const keys = {
      'Trotz und Wut': 'anger',
      'Geschwisterkonflikt': 'siblings',
      'Schlaf': 'sleep',
      'Medien': 'media',
      'Kita und Schule': 'school',
      'Lernen und Selbststaendigkeit': 'learning',
      'Spielen und Kreativitaet': 'play',
    };
    return text(language, 'chat_focus_${keys[topic] ?? 'general'}');
  }

  static String followUp(String language, bool needed) =>
      text(language, needed ? 'chat_ask_one' : 'chat_ask_none');

  static String coaching({
    required String language,
    required String message,
    required String topic,
    required bool needsFollowUp,
    required List<String> context,
    required List<String> history,
  }) => text(language, 'chat_coaching_prompt', {
    'message': message,
    'focus': focus(topic, language),
    'followUp': followUp(language, needsFollowUp),
    'continuation': text(language, history.isEmpty ? 'chat_new_context' : 'chat_continue_context'),
    'context': context.isEmpty ? text(language, 'chat_no_context') : context.join(', '),
    'history': history.isEmpty ? text(language, 'chat_no_context') : history.join(', '),
  });

  static String quality(String language, String topic, bool needsFollowUp) =>
      text(language, 'chat_quality_retry', {
        'focus': focus(topic, language),
        'followUp': followUp(language, needsFollowUp),
      });

  static String fallback(String topic, String language) {
    final suffix = topic == 'Schlaf' ? 'sleep' : topic == 'Trotz und Wut' ? 'anger' : 'general';
    return '${text(language, 'chat_fallback_label')}\n\n${text(language, 'chat_fallback_$suffix')}';
  }

  static String medical(String language, String? country) {
    final base = text(language, 'chat_boundary_medical');
    return country?.trim().toUpperCase() == 'DE'
        ? '$base ${text(language, 'chat_medical_de')}'
        : base;
  }
}
