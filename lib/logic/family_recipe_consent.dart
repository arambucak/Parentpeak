import 'package:parentpeak/logic/account_ai_consent.dart';

class RecipeAiConsentRequiredException implements Exception {
  const RecipeAiConsentRequiredException();

  @override
  String toString() => 'AI recipe consent is required for the current account.';
}

class FamilyRecipeConsent extends AccountAiConsent {
  FamilyRecipeConsent({String Function()? scopeProvider})
      : super(
          storagePrefix: 'familykueche.ai_recipe_consent.v1',
          scopeProvider: scopeProvider,
          requiredException: () => const RecipeAiConsentRequiredException(),
        );

  static final instance = FamilyRecipeConsent();
}
