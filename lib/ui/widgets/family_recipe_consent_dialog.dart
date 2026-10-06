import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';

Future<bool> ensureFamilyRecipeConsent(
  BuildContext context, {
  FamilyRecipeConsent? consent,
}) async {
  final store = consent ?? FamilyRecipeConsent.instance;
  final scope = store.scope;
  try {
    if (await store.hasConsent()) return store.scope == scope;
    if (!context.mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('recipe_ai_consent_title')),
        content: SingleChildScrollView(
          child: Text(context.tr('recipe_ai_consent_body')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('recipe_ai_consent_accept')),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return false;
    await store.grant(scope);
    return true;
  } catch (error) {
    debugPrint('ensureFamilyRecipeConsent: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('recipe_ai_consent_failed'))),
      );
    }
    return false;
  }
}
