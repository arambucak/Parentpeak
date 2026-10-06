import 'package:parentpeak/logic/account_ai_consent.dart';

class BenefitGuideConsent extends AccountAiConsent {
  BenefitGuideConsent({
    super.scopeProvider,
    super.persist,
  }) : super(storagePrefix: 'famgeld.ai_guide_consent.v1');

  static final instance = BenefitGuideConsent();
}
