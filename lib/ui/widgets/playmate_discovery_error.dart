import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';

class PlaymateDiscoveryError extends StatelessWidget {
  const PlaymateDiscoveryError({
    super.key,
    required this.onRetry,
    this.messageKey = 'network_discovery_failed',
  });

  final VoidCallback onRetry;
  final String messageKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded),
          const SizedBox(height: 12),
          Text(context.tr(messageKey), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(context.tr('network_discovery_retry')),
          ),
        ],
      ),
    );
  }
}
