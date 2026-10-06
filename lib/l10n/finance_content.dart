import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/finance_content_keys.dart';
import 'package:parentpeak/models/benefit_application_data.dart';
import 'package:parentpeak/models/country_finance_config.dart';

/// Source lookup preserves curated IDs, document order and unchanged legal data.
String financeContent(String source, String languageCode) {
  final key = financeContentKeys[source];
  return key == null ? source : AppStringsManager.getString(languageCode, key);
}

String financeBenefitText(
  SocialBenefit benefit,
  String countryCode,
  String languageCode,
  String field,
) {
  final index = switch (field) {
    'name' => 0,
    'description' => 1,
    'amount' => 2,
    'eligibility' => 3,
    _ => throw ArgumentError.value(field, 'field'),
  };
  if (countryCode == 'de') {
    return AppStringsManager.getString(
      languageCode, 'finance_benefit_de_${benefit.id}',
    ).split('|')[index];
  }
  return financeContent(switch (field) {
    'name' => benefit.name,
    'description' => benefit.description,
    'amount' => benefit.amount ?? '',
    _ => benefit.eligibility ?? '',
  }, languageCode);
}

BenefitApplicationData localizedFinanceApplication(
  BenefitApplicationData source,
  String languageCode,
) {
  String text(String value) => financeContent(value, languageCode);
  String? optional(String? value) => value == null ? null : text(value);
  return BenefitApplicationData(
    benefitId: source.benefitId,
    benefitName: text(source.benefitName),
    emoji: source.emoji,
    countryCode: source.countryCode,
    onlineApplicationUrl: source.onlineApplicationUrl,
    responsibleAuthority: text(source.responsibleAuthority),
    processingTime: text(source.processingTime),
    renewalNote: optional(source.renewalNote),
    proTip: optional(source.proTip),
    aiTemplatePrompt: optional(source.aiTemplatePrompt),
    documents: [
      for (final doc in source.documents)
        RequiredDocument(
          name: text(doc.name),
          whereToGet: optional(doc.whereToGet),
          isOptional: doc.isOptional,
        ),
    ],
    steps: [
      for (final step in source.steps)
        ApplicationStep(
          stepNumber: step.stepNumber,
          title: text(step.title),
          description: text(step.description),
          url: step.url,
        ),
    ],
  );
}
