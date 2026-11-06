import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/ui/widgets/content_report_form.dart';

/// Disclaimer-Banner das einmalig beim ersten Event-Besuch angezeigt wird.
class EventDisclaimerBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const EventDisclaimerBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u{26A0}\u{FE0F}', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(context.tr('event_safety_title'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E)))),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Icon(Icons.close_rounded,
                size: 18,
                color: const Color(0xFF92400E).withValues(alpha: 0.6)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          context.tr('event_safety_disclaimer'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: const Color(0xFF92400E), height: 1.4),
        ),
      ]),
    );
  }
}

/// "Melden" Bottom-Sheet mit Gruenden.
class ReportEventSheet extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  /// Overrides the default community-event flag, e.g. for AI-discovered or
  /// user-hosted events that are not stored as community events.
  final Future<bool> Function(String reason)? onSubmit;

  const ReportEventSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ContentReportForm(
        allowNote: false,
        onSubmit: (selection) => _submit(context, selection.reason),
      ),
    );
  }

  Future<void> _submit(BuildContext context, String reason) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final successText = context.tr('event_report_thanks');
    final failedText = context.tr('report_delivery_failed');
    navigator.pop();
    bool success;
    try {
      success = await deliverContentReport(
        navigator.context,
        reason: reason,
        send: () => onSubmit != null
            ? onSubmit!(reason)
            : CommunityEventService.instance.flagEvent(eventId, reason),
      );
    } catch (error) {
      debugPrint('Event report delivery failed: $error');
      success = false;
    }
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(success ? successText : failedText),
      ));
    }
  }
}

/// Interesse-Button mit Counter.
class EventInterestButton extends StatefulWidget {
  final String eventId;
  final int initialCount;
  final CommunityEventService? service;

  const EventInterestButton({
    super.key,
    required this.eventId,
    this.initialCount = 0,
    this.service,
  });

  @override
  State<EventInterestButton> createState() => _EventInterestButtonState();
}

class _EventInterestButtonState extends State<EventInterestButton> {
  late int _count;
  bool _tapped = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tapped || _loading ? null : _onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _tapped
              ? const Color(0xFFEC4899).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _tapped
                ? const Color(0xFFEC4899).withValues(alpha: 0.4)
                : Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _tapped ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 16,
            color: _tapped
                ? const Color(0xFFEC4899)
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            _count > 0
                ? context
                    .tr('event_interested_families', values: {'count': _count})
                : context.tr('event_show_interest'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _tapped
                  ? const Color(0xFFEC4899)
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _onTap() async {
    setState(() => _loading = true);
    final success = await (widget.service ?? CommunityEventService.instance)
        .showInterest(widget.eventId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (success) {
        _tapped = true;
        _count++;
      }
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('event_action_failed'))),
      );
    }
  }
}

/// Source-Badge (KI-Vorschlag / Eltern-Tipp / Verifiziert)
class EventSourceBadge extends StatelessWidget {
  final CommunityEvent event;

  const EventSourceBadge({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    switch (event.source) {
      case EventSource.kiAgent:
        color = const Color(0xFF8B5CF6);
        label = context.tr('event_source_ai_suggestion');
        icon = Icons.auto_awesome_rounded;
        break;
      case EventSource.partner:
        color = event.isVerified
            ? const Color(0xFF16A34A)
            : const Color(0xFF2563EB);
        label = context.tr(event.isVerified
            ? 'event_source_verified'
            : 'event_source_partner');
        icon =
            event.isVerified ? Icons.verified_rounded : Icons.business_rounded;
        break;
      case EventSource.community:
        color = const Color(0xFFF97316);
        label = context.tr('event_source_parent_tip');
        icon = Icons.people_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Private-Adresse Hinweis
class PrivateAddressHint extends StatelessWidget {
  const PrivateAddressHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outline_rounded,
            size: 12, color: Color(0xFF92400E)),
        const SizedBox(width: 4),
        Flexible(
            child: Text(context.tr('event_private_address_hint'),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
