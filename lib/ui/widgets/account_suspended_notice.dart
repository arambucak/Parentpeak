import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';

/// Ruhiger, sachlicher Hinweis fuer gesperrte Konten — im ParentPeak-Ton,
/// ohne Beschaemung. Wird angezeigt, wenn der Server ein gesperrtes Konto
/// meldet (SuspendedAccountException).
Future<void> showAccountSuspendedNotice(
  BuildContext context, {
  String? message,
}) async {
  if (!context.mounted) return;
  final theme = Theme.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.info_outline_rounded,
          size: 36, color: theme.colorScheme.primary),
      title: Text(context.tr('account_suspended_title')),
      content: Text(
        message ?? context.tr('account_suspended_message'),
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.tr('common_understood')),
        ),
      ],
    ),
  );
}
