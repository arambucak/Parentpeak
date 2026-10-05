import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/ui/widgets/event_attendees_widget.dart';
import 'package:parentpeak/ui/widgets/event_safety_widgets.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/ui/widgets/event_photo.dart';

/// Event-Detail Seite — zeigt alle Infos zu einem Event.
class EventDetailPage extends StatelessWidget {
  final DiscoveredEvent event;

  const EventDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('event_details_title')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (event.imageUrl?.trim().isNotEmpty == true) ...[
            EventPhoto(photoUrl: event.imageUrl),
            const SizedBox(height: 12),
          ],
          // Kategorie-Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                context.tr(switch (event.category) {
                  DiscoveredEventCategory.sport => 'event_category_sports',
                  DiscoveredEventCategory.sonstiges => 'event_category_other',
                  _ => 'event_community_category_${event.category.name}',
                }),
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
          if (_formatWann(context, event) case final wann
              when wann.isNotEmpty) ...[
            _infoCard(
                theme, '\u{1F4C5}', context.tr('event_scan_field_date'), wann),
            const SizedBox(height: 10),
          ],
          _infoCard(theme, '\u{1F4CD}', context.tr('event_owner_location'),
              event.location),
          const SizedBox(height: 10),
          _infoCard(theme, '\u{1F476}', context.tr('event_detail_age_groups'),
              event.ageLabels.join(', ')),
          const SizedBox(height: 10),
          _infoCard(theme, '\u{1F4B0}', context.tr('event_price'),
              event.price ?? context.tr('event_not_specified')),
          if (event.organizer != null && event.organizer!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoCard(theme, '\u{1F3E2}', context.tr('event_create_organizer'),
                event.organizer!),
          ],
          const SizedBox(height: 20),
          // In Maps oeffnen
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openInMaps(event.location),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: Text(context.tr('open_in_maps')),
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
          // Website-Link / Veranstalter-Suche
          if (event.url != null && event.url!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openUrl(event.url!),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(context.tr('event_open_website')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5A4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final parts = [
                    event.title,
                    if (event.organizer != null && event.organizer!.isNotEmpty)
                      event.organizer!,
                    event.cityHint,
                    'Veranstaltung',
                  ];
                  _openUrl(
                      'https://www.google.com/search?q=${Uri.encodeComponent(parts.join(' '))}');
                },
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(context.tr('search_event_online')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0EA5A4),
                  side: BorderSide(
                      color: const Color(0xFF0EA5A4).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],

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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('\u{2139}\u{FE0F}', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  context.tr('event_ai_verify_hint'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF92400E), height: 1.3),
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
              label: Text(context.tr('event_report_title'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, String emoji, String label, String value) {
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  /// Formatiert den Wann-Text mit Datum + Uhrzeit + Zeitraum.
  String _formatWann(BuildContext context, DiscoveredEvent event) {
    if (event.isRecurring) {
      return event.recurringNote ?? context.tr('recurring_event');
    }
    if (event.eventDate == null && event.eventTimeRange == null) {
      return '';
    }
    final parts = <String>[];
    if (event.eventDate != null) {
      final d = event.eventDate!.toLocal();
      parts.add(MaterialLocalizations.of(context).formatFullDate(d));
    }
    if (event.eventTimeRange != null && event.eventTimeRange!.isNotEmpty) {
      parts.add(event.eventTimeRange!);
    } else if (event.eventDate != null) {
      final d = event.eventDate!.toLocal();
      if (d.hour != 0 || d.minute != 0) {
        parts.add(MaterialLocalizations.of(context)
            .formatTimeOfDay(TimeOfDay.fromDateTime(d)));
      }
    }
    return parts.join(' · ');
  }

  void _openInMaps(String location) async {
    // Plattformneutraler Karten-Link: Die Google-Maps-Such-URL öffnet auf
    // Android/iOS die jeweilige Karten-App und auf Web den Browser. Zuvor war
    // der Link fest auf Apple Maps, was auf Android/Web schlecht funktioniert.
    final query = Uri.encodeComponent(location);
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openUrl(String urlString) async {
    final url = Uri.tryParse(urlString);
    if (url != null && await canLaunchUrl(url)) {
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
