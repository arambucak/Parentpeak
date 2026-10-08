import 'package:parentpeak/logic/account_ai_consent.dart';

class FridgePhotoConsentRequiredException implements Exception {
  const FridgePhotoConsentRequiredException();

  @override
  String toString() => 'Fridge AI consent is required for the originating account.';
}

class FridgePhotoConsent extends AccountAiConsent {
  FridgePhotoConsent({
    String Function()? scopeProvider,
    Future<bool> Function(String key, bool value)? persist,
  }) : super(
         storagePrefix: 'fridge.ai_photo_consent.v1',
         scopeProvider: scopeProvider,
         persist: persist,
         requiredException: () => const FridgePhotoConsentRequiredException(),
       );

  static final instance = FridgePhotoConsent();
}
