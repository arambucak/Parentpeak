import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';

Future<bool> confirmPlaymatePublication(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('network_publish_title')),
      content: SingleChildScrollView(
        child: Text(ctx.tr('network_publish_body')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('network_publish_accept')),
        ),
      ],
    ),
  );
  return confirmed == true;
}
