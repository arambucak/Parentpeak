import 'package:flutter/material.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/ui/widgets/account_ai_consent_dialog.dart';

Future<bool> ensureFamilyRecipeConsent(
  BuildContext context, {
  FamilyRecipeConsent? consent,
}) => ensureAccountAiConsent(
  context,
  consent: consent ?? FamilyRecipeConsent.instance,
  titleKey: 'recipe_ai_consent_title',
  bodyKey: 'recipe_ai_consent_body',
  acceptKey: 'recipe_ai_consent_accept',
  failedKey: 'recipe_ai_consent_failed',
);
