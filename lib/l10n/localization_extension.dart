import 'package:flutter/widgets.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

extension LocalizationBuildContext on BuildContext {
  String tr(String key, {Map<String, Object?> values = const {}}) {
    var text = AppStringsManager.getString(
      Localizations.localeOf(this).languageCode,
      key,
    );
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return text;
  }
}
