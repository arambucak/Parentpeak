import 'package:parentpeak/logic/account_ai_consent.dart';

class TreasurePhotoConsent extends AccountAiConsent {
  TreasurePhotoConsent({super.scopeProvider, super.persist})
      : super(storagePrefix: 'treasure.ai_photo_consent.v1');

  static final instance = TreasurePhotoConsent();
}
