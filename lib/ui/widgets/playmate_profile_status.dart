import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';

Future<bool> confirmPlaymateDraftOwnership(
    BuildContext context, String accountName) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('network_draft_assign_title')),
      content: Text(context.tr('network_draft_assign_body',
          values: {'account': accountName})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('network_draft_assign')),
        ),
      ],
    ),
  ) ?? false;
}

class PlaymateProfileStatusPanel extends StatelessWidget {
  const PlaymateProfileStatusPanel({
    super.key,
    required this.status,
    required this.onRetry,
    this.hasUnassignedDraft = false,
    this.onAssignDraft,
  });

  final PlaymateProfileStatus status;
  final bool hasUnassignedDraft;
  final VoidCallback onRetry;
  final VoidCallback? onAssignDraft;

  @override
  Widget build(BuildContext context) {
    final key = switch (status) {
      PlaymateProfileStatus.active => 'network_profile_active',
      PlaymateProfileStatus.draft => 'network_profile_draft',
      PlaymateProfileStatus.unavailable => 'network_profile_unverified',
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(context.tr(key), textAlign: TextAlign.center),
          if (status == PlaymateProfileStatus.unavailable)
            TextButton(
              onPressed: onRetry,
              child: Text(context.tr('network_profile_retry')),
            ),
          if (hasUnassignedDraft) ...[
            Text(context.tr('network_draft_unassigned'),
                textAlign: TextAlign.center),
            TextButton(
              onPressed: onAssignDraft,
              child: Text(context.tr('network_draft_assign')),
            ),
          ],
        ],
      ),
    );
  }
}
