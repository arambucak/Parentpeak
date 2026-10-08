import 'package:parentpeak/logic/account_ai_consent.dart';

class DevelopmentReportConsentRequiredException implements Exception {
  const DevelopmentReportConsentRequiredException();

  @override
  String toString() => 'Development report consent is required for this account.';
}

class DevelopmentReportConsent extends AccountAiConsent {
  DevelopmentReportConsent({
    String Function()? scopeProvider,
    Future<bool> Function(String key, bool value)? persist,
  }) : super(
          storagePrefix: 'dev.ai_report_consent.v1',
          scopeProvider: scopeProvider,
          persist: persist,
          requiredException: () =>
              const DevelopmentReportConsentRequiredException(),
        );

  static final instance = DevelopmentReportConsent();
}
