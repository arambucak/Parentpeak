import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/finance_link_policy.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openFinanceLink(BuildContext context, String url) async {
  var opened = false;
  try {
    if (FinanceLinkPolicy.isHttps(url)) {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } else {
      debugPrint('Finance link rejected: invalid HTTPS URL');
    }
  } catch (error) {
    debugPrint('Finance link launch failed: $error');
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('finance_link_open_failed'))),
    );
  }
}
