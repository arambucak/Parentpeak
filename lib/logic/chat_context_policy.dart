import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/models/family_profile_model.dart';

class ChatContextPolicy {
  static const maxHistoryRounds = 6;
  static const maxHistoryCharacters = 12000;

  static List<Map<String, String>> limitHistory(
    List<Map<String, String>> history,
  ) {
    final rounds = <List<Map<String, String>>>[];
    for (final item in history) {
      if (item['role'] == 'user') {
        rounds.add([item]);
      } else if (item['role'] == 'assistant' && rounds.isNotEmpty) {
        rounds.last.add(item);
      }
    }
    final selected = <List<Map<String, String>>>[];
    var characters = 0;
    for (final round in rounds.reversed) {
      final size = round.fold(0, (sum, item) => sum + item['content']!.length);
      if (selected.length == maxHistoryRounds ||
          characters + size > maxHistoryCharacters) {
        break;
      }
      selected.add(round);
      characters += size;
    }
    return [
      for (final round in selected.reversed)
        for (final item in round) Map<String, String>.from(item),
    ];
  }

  static int? completedAge(ChildEntry? child, {DateTime? now}) {
    if (child == null) return null;
    final today = now ?? DateTime.now();
    final birth = child.birthDate;
    final date = DateTime(today.year, today.month, today.day);
    if (DateTime(birth.year, birth.month, birth.day).isAfter(date)) return null;
    var years = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      years--;
    }
    return years;
  }

  static String tipPrompt(String tip, String languageCode, int? age) {
    final ageText = AppStringsManager.getString(
      languageCode,
      age == null ? 'chat_tip_age_unknown' : 'chat_tip_age_known',
    ).replaceAll('{age}', '$age');
    return AppStringsManager.getString(
      languageCode,
      'chat_tip_prompt',
    ).replaceAll('{ageContext}', ageText).replaceAll('{tip}', tip);
  }
}
