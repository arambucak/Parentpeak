import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/playmate_publication_failure.dart';

String playmatePublicationDiagnosticText({
  required String language,
  required PlaymatePublicationFailure failure,
}) =>
    AppStringsManager.getString(language, 'network_publish_error_code')
        .replaceAll('{code}', '\u2068${failure.diagnosticCode}\u2069');

SnackBar playmatePublicationErrorSnackBar(
  BuildContext context, {
  required String language,
  required PlaymatePublicationFailure failure,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final message = AppStringsManager.getString(language, failure.messageKey);
  final code =
      playmatePublicationDiagnosticText(language: language, failure: failure);
  return SnackBar(
    backgroundColor: colorScheme.error,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: TextStyle(color: colorScheme.onError)),
        const SizedBox(height: 4),
        Text(
          code,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onError,
              ),
        ),
      ],
    ),
  );
}
