import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/models/community_event.dart';

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
              child: Text('Hinweis zur Sicherheit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E)))),
          GestureDetector(behavior: HitTestBehavior.opaque, 
            onTap: onDismiss,
            child: Icon(Icons.close_rounded,
                size: 18,
                color: const Color(0xFF92400E).withValues(alpha: 0.6)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'ParentPeak vermittelt nur Informationen zu Events. '
          'Die Verantwortung liegt beim Veranstalter und den begleitenden Eltern. '
          'Bitte begleite dein Kind immer persoenlich zu Treffen.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: const Color(0xFF92400E), height: 1.4),
        ),
      ]),
    );
  }
}

/// "Melden" Bottom-Sheet mit Gruenden.
class ReportEventSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const ReportEventSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<ReportEventSheet> createState() => _ReportEventSheetState();
}

class _ReportEventSheetState extends State<ReportEventSheet> {
  String? _selectedReason;
  bool _sending = false;

  static const _reasons = [
    {
      'id': 'spam',
      'label': '\u{1F6AB} Spam oder Werbung',
      'desc': 'Keine echte Veranstaltung'
    },
    {
      'id': 'fake',
      'label': '\u{26A0}\u{FE0F} Falsche Informationen',
      'desc': 'Ort, Datum oder Inhalt stimmen nicht'
    },
    {
      'id': 'unsafe',
      'label': '\u{1F6A8} Unsicher für Kinder',
      'desc': 'Kein sicherer Ort oder Betreuer'
    },
    {
      'id': 'inappropriate',
      'label': '\u{1F645} Unangemessener Inhalt',
      'desc': 'Beleidigend oder nicht für Familien geeignet'
    },
    {
      'id': 'expired',
      'label': '\u{1F4C5} Veraltet / abgesagt',
      'desc': 'Event findet nicht mehr statt'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Event melden',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('"${widget.eventTitle}"',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        ..._reasons.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RadioListTile<String>(
                value: r['id']!,
                groupValue: _selectedReason,
                onChanged: (v) => setState(() => _selectedReason = v),
                title: Text(r['label']!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(r['desc']!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: _selectedReason == r['id']
                    ? theme.colorScheme.error.withValues(alpha: 0.05)
                    : null,
                activeColor: theme.colorScheme.error,
                dense: true,
              ),
            )),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedReason == null || _sending ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Meldung senden'),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final success = await CommunityEventService.instance.flagEvent(
      widget.eventId,
      _selectedReason!,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Danke für deine Meldung. Wir pruefen das Event.'
            : 'Meldung konnte nicht gesendet werden.'),
      ));
    }
  }
}

/// Interesse-Button mit Counter.
class EventInterestButton extends StatefulWidget {
  final String eventId;
  final int initialCount;

  const EventInterestButton({
    super.key,
    required this.eventId,
    this.initialCount = 0,
  });

  @override
  State<EventInterestButton> createState() => _EventInterestButtonState();
}

class _EventInterestButtonState extends State<EventInterestButton> {
  late int _count;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(behavior: HitTestBehavior.opaque, 
      onTap: _tapped ? null : _onTap,
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
            _count > 0 ? '$_count Familien interessiert' : 'Interesse zeigen',
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
    setState(() {
      _tapped = true;
      _count++;
    });
    await CommunityEventService.instance.showInterest(widget.eventId);
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
    final IconData? icon;

    switch (event.source) {
      case EventSource.kiAgent:
        color = const Color(0xFF8B5CF6);
        label = 'KI-Vorschlag';
        icon = Icons.auto_awesome_rounded;
        break;
      case EventSource.partner:
        color = event.isVerified
            ? const Color(0xFF16A34A)
            : const Color(0xFF2563EB);
        label = event.isVerified ? 'Verifiziert' : 'Partner';
        icon =
            event.isVerified ? Icons.verified_rounded : Icons.business_rounded;
        break;
      case EventSource.community:
        color = const Color(0xFFF97316);
        label = 'Eltern-Tipp';
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
        if (icon != null) Icon(icon, size: 12, color: color),
        if (icon != null) const SizedBox(width: 3),
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
        Text('Privater Ort — Adresse erst nach Kontakt sichtbar',
            style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF92400E), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
