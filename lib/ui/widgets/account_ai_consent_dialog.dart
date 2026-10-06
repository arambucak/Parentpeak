import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/auth_service.dart';

Future<bool> ensureAccountAiConsent(
  BuildContext context, {
  required AccountAiConsent consent,
  required String titleKey,
  required String bodyKey,
  required String acceptKey,
  required String failedKey,
}) async {
  final scope = consent.scope;
  try {
    if (await consent.hasConsent()) return consent.scope == scope;
    if (!context.mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: AuthService.instance,
        builder: (dialogContext, child) => consent.scope != scope
          ? AlertDialog(
              content: Text(context.tr('family_hub_account_changed')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('cancel')),
                ),
              ],
            )
          : AlertDialog(
          title: Text(context.tr(titleKey)),
          content: SingleChildScrollView(child: Text(context.tr(bodyKey))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr(acceptKey)),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return false;
    await consent.grant(scope);
    return true;
  } catch (error) {
    debugPrint('ensureAccountAiConsent: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(failedKey))),
      );
    }
    return false;
  }
}
