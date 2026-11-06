import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/crisis_support.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/report_reasons.dart';

class ReportSelection {
  const ReportSelection(this.reason, this.note);
  final String reason;
  final String note;
}

Future<ReportSelection?> selectReportReason(BuildContext context,
        {bool allowNote = true}) =>
    showModalBottomSheet<ReportSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ContentReportForm(
        allowNote: allowNote,
        onSubmit: (selection) => Navigator.pop(context, selection),
      ),
    );

class ContentReportForm extends StatefulWidget {
  const ContentReportForm({
    super.key,
    required this.onSubmit,
    this.allowNote = true,
  });

  final ValueChanged<ReportSelection> onSubmit;
  final bool allowNote;

  @override
  State<ContentReportForm> createState() => _ContentReportFormState();
}

class _ContentReportFormState extends State<ContentReportForm> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('report_content_title'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(context.tr('report_content_hint')),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _reason,
                    onChanged: (reason) => setState(() => _reason = reason),
                    child: Column(
                      children: [
                        for (final reason in ReportReasons.keys)
                          RadioListTile<String>(
                            key: ValueKey('report-reason-$reason'),
                            value: reason,
                            title: Text(context.tr('report_reason_$reason')),
                            secondary: ReportReasons.needsAttention(reason)
                                ? const Icon(Icons.warning_amber_rounded,
                                    size: 20)
                                : null,
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  if (widget.allowNote) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                          labelText: context.tr('report_optional_note')),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('report-submit'),
                    onPressed: _reason == null
                        ? null
                        : () => widget.onSubmit(
                            ReportSelection(_reason!, _note.text.trim())),
                    child: Text(context.tr('event_report_send')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('cancel')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

Future<String> reportCountryCode() async {
  final accounts = ProfileAccountStore.instance;
  final ticket = accounts.ticket;
  try {
    final data = await accounts.read(ticket);
    accounts.require(ticket);
    final country = data[ProfileAccountStore.countryKey] as String?;
    return country?.trim().isNotEmpty == true ? country!.trim() : 'DE';
  } on ProfileAccountChanged {
    return 'DE';
  } catch (error) {
    debugPrint('Report crisis country lookup failed: $error');
    return 'DE';
  }
}

Future<void> showReportCrisisSupport(BuildContext context,
    {Future<String> Function()? countryProvider}) async {
  // Resolve the account country independently of the delivery request.
  final country = await (countryProvider ?? reportCountryCode)();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('report_help_title'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(context.tr('report_help_intro')),
            const SizedBox(height: 12),
            SelectableText(CrisisSupport.crisisResponse(
              languageCode: Localizations.localeOf(context).languageCode,
              countryCode: country,
            )),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Starts delivery before showing help, without waiting for the network.
Future<bool> deliverContentReport(
  BuildContext context, {
  required String reason,
  required Future<bool> Function() send,
  Future<String> Function()? countryProvider,
}) {
  final delivery = Future<bool>.sync(send);
  if (reason == 'self_harm') {
    unawaited(showReportCrisisSupport(context, countryProvider: countryProvider)
        .catchError((Object error) {
      debugPrint('Report crisis support presentation failed: $error');
    }));
  }
  return delivery;
}
