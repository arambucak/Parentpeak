import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/ui/widgets/event_attendees_widget.dart';
import 'package:parentpeak/ui/widgets/event_safety_widgets.dart';
import 'package:parentpeak/models/community_event.dart';

/// Event-Detail Seite — zeigt alle Infos zu einem Event.
class EventDetailPage extends StatelessWidget {
  final DiscoveredEvent event;

  const EventDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event-Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Kategorie-Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(event.categoryLabel,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6))),
          ),
          const SizedBox(height: 12),
          // Titel
          Text(event.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          // Beschreibung
          Text(event.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 20),
          // Info-Karten
          _infoCard(theme, '\u{1F4C5}', 'Wann',
              event.isRecurring
                  ? event.recurringNote ?? 'Regelmaessig'
                  : event.eventDate != null
                      ? '${event.eventDate!.day}.${event.eventDate!.month}.${event.eventDate!.year}'
                      : 'Bitte beim Veranstalter erfragen'),
          const SizedBox(height: 10),
          _infoCard(theme, '\u{1F4CD}', 'Wo', event.location),
          const SizedBox(height: 10),
          _infoCard(theme, '\u{1F476}', 'Fuer wen',
              event.ageLabels.join(', ')),
          const SizedBox(height: 10),
          _infoCard(theme, '\u{1F4B0}', 'Preis',
              event.price ?? 'Nicht angegeben'),
          if (event.organizer != null && event.organizer!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoCard(theme, '\u{1F3E2}', 'Veranstalter', event.organizer!),
          ],
          const SizedBox(height: 20),
          // In Maps oeffnen
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openInMaps(event.location),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('In Maps oeffnen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: BorderSide(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Teilnehmer
          EventAttendeesWidget(
            eventId: event.id,
            initialCount: event.interestCount,
            compact: false,
          ),
          const SizedBox(height: 20),
          // KI-Hinweis
          if (event.source == DiscoveredEventSource.kiAgent)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('\u{2139}\u{FE0F}',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      'Dieses Angebot wurde von unserer KI vorgeschlagen. '
                      'Bitte bestaetige Termine und Verfuegbarkeit direkt beim Veranstalter.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF92400E), height: 1.3),
                    )),
                  ]),
            ),
          const SizedBox(height: 14),
          // Melden Button
          Center(
            child: TextButton.icon(
              onPressed: () => _showReport(context),
              icon: Icon(Icons.flag_rounded,
                  size: 16, color: theme.colorScheme.outline),
              label: Text('Event melden',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard(
      ThemeData theme, String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 2),
              Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ])),
      ]),
    );
  }

  void _openInMaps(String location) async {
    final query = Uri.encodeComponent(location);
    final url = Uri.parse('https://maps.apple.com/?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReportEventSheet(
        eventId: event.id,
        eventTitle: event.title,
      ),
    );
  }
}
