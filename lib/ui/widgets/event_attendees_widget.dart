import 'package:flutter/material.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/models/event_attendee.dart';

/// "Bekannte Gesichter" Widget fuer Events.
///
/// Zeigt:
/// - Avatar-Reihe der Teilnehmer (max 5 sichtbar)
/// - "Sarah M.", "Yasemin S." + X weitere
/// - Netzwerk-Kontakte hervorgehoben mit Stern
/// - "Ich bin auch dabei!" Button mit optionaler Kurznachricht
///
/// Kompakt genug fuer Event-Cards UND ausfuehrlich fuer Detail-View.
class EventAttendeesWidget extends StatefulWidget {
  final String eventId;
  final int initialCount;
  final bool compact; // true = nur Avatare + Zahl, false = voll

  const EventAttendeesWidget({
    super.key,
    required this.eventId,
    this.initialCount = 0,
    this.compact = false,
  });

  @override
  State<EventAttendeesWidget> createState() => _EventAttendeesWidgetState();
}

class _EventAttendeesWidgetState extends State<EventAttendeesWidget> {
  EventAttendeesResult? _result;
  bool _joined = false;
  bool _loading = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = widget.initialCount;
    if (!widget.compact) _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    final result =
        await CommunityEventService.instance.getAttendees(widget.eventId);
    if (mounted) {
      setState(() {
        _result = result;
        _total = result.total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _compactView(context);
    return _fullView(context);
  }

  // ─── Compact View (fuer Event-Cards im Carousel) ──────────────────────────
  Widget _compactView(BuildContext context) {
    final theme = Theme.of(context);
    if (_total == 0 && !_joined) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // Mini-Avatare
      SizedBox(
        width: 36,
        height: 18,
        child: Stack(children: [
          _miniAvatar(0, const Color(0xFF8B5CF6)),
          if (_total > 1)
            Positioned(
                left: 10, child: _miniAvatar(1, const Color(0xFF0EA5A4))),
          if (_total > 2)
            Positioned(
                left: 20, child: _miniAvatar(2, const Color(0xFFF97316))),
        ]),
      ),
      const SizedBox(width: 4),
      Text(
        '$_total dabei',
        style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline, fontWeight: FontWeight.w600),
      ),
    ]);
  }

  Widget _miniAvatar(int index, Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
          child: Text(
        '\u{1F464}',
        style: const TextStyle(fontSize: 8),
      )),
    );
  }

  // ─── Full View (fuer Event-Detail) ────────────────────────────────────────
  Widget _fullView(BuildContext context) {
    final theme = Theme.of(context);
    final attendees = _result?.attendees ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Text('\u{1F465}', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            _total == 0
                ? 'Noch niemand dabei'
                : '$_total ${_total == 1 ? "Familie" : "Familien"} dabei',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ]),
        // Attendee-Liste
        if (attendees.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...attendees.take(5).map((a) => _attendeeRow(theme, a)),
          if (_total > 5)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+ ${_total - 5} weitere Familien',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
        const SizedBox(height: 14),
        // "Ich bin dabei!" Button
        if (!_joined)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _showJoinSheet(context),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.waving_hand_rounded, size: 18),
              label: const Text('Ich bin auch dabei!'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF16A34A)),
                  SizedBox(width: 6),
                  Text('Du bist dabei!',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A))),
                ]),
          ),
      ]),
    );
  }

  Widget _attendeeRow(ThemeData theme, EventAttendee attendee) {
    final isNetwork = attendee.isNetworkContact;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        // Avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isNetwork
                ? const Color(0xFFF97316).withValues(alpha: 0.12)
                : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              attendee.displayName.isNotEmpty
                  ? attendee.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isNetwork
                    ? const Color(0xFFF97316)
                    : const Color(0xFF8B5CF6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name + Message
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(attendee.shortName,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (isNetwork) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('\u{2B50} Netzwerk',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF97316))),
                ),
              ],
            ]),
            if (attendee.message != null && attendee.message!.isNotEmpty)
              Text('"${attendee.message}"',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  // ─── Join Sheet ───────────────────────────────────────────────────────────
  void _showJoinSheet(BuildContext context) {
    final msgCtrl = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('\u{1F44B}', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Text('Ich bin dabei!',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Andere Familien sehen deinen Vornamen.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLength: 80,
              decoration: InputDecoration(
                hintText:
                    'Optional: kurze Nachricht (z.B. "Wir kommen um 10!")',
                hintStyle:
                    TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _joinEvent(msgCtrl.text.trim());
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Bestaetigen'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _joinEvent(String message) async {
    setState(() => _loading = true);
    final success = await CommunityEventService.instance.showInterest(
      widget.eventId,
      message: message.isEmpty ? null : message,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        if (success) {
          _joined = true;
          _total++;
        }
      });
      if (success) _loadAttendees();
    }
  }
}
