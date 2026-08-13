import 'package:flutter/material.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/logic/event_cache_service.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/create_community_event_screen.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/widgets/event_attendees_widget.dart';

/// Home-Widget: Events in deiner Naehe — Carousel + "Event eintragen" CTA.
///
/// Laedt Events automatisch basierend auf dem Spielfreunde-Profil Stadtteil.
/// Zeigt 3 Events als horizontale Karten + "Alle anzeigen" + "Event eintragen".
class EventsCarouselWidget extends StatefulWidget {
  const EventsCarouselWidget({super.key});

  @override
  State<EventsCarouselWidget> createState() => _EventsCarouselWidgetState();
}

class _EventsCarouselWidgetState extends State<EventsCarouselWidget> {
  List<CommunityEvent> _events = [];
  bool _loading = true;
  String _city = 'Berlin';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    // Stadt aus Spielfreunde-Profil laden
    final profile = await FamilyMatchProfile.load();
    if (profile != null && profile.district.isNotEmpty) {
      _city = profile.district;
    }

    final events = await EventCacheService.instance.getEvents(city: _city);
    if (mounted) {
      setState(() {
        _events = events.take(5).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Text('\u{1F389}', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Events in deiner Naehe',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(_city,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          )),
          TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EventsActivitiesScreen())),
            child: const Text('Alle',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 10),

      // Carousel oder Loading/Empty State
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (_events.isEmpty)
        _emptyState(theme)
      else
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _events.length + 1, // +1 für "Event eintragen" Card
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              if (i == _events.length) return _createEventCard(theme);
              return _eventCard(theme, _events[i]);
            },
          ),
        ),
    ]);
  }

  Widget _eventCard(ThemeData theme, CommunityEvent event) {
    return GestureDetector(behavior: HitTestBehavior.opaque, 
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EventsActivitiesScreen())),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Kategorie + Source Badge
          Row(children: [
            Text(event.category.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    event.category.label.replaceFirst(RegExp(r'^.\s'), ''),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: event.source == EventSource.kiAgent
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                    : const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.source == EventSource.kiAgent ? 'KI' : '\u{2714}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: event.source == EventSource.kiAgent
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF16A34A),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Titel
          Text(event.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const Spacer(),
          // Meta-Zeile
          Row(children: [
            if (event.isFree)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Kostenlos',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A))),
              ),
            if (!event.isFree)
              Text(event.price,
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEA580C))),
            const Spacer(),
            if (event.interestCount > 0) ...[
              EventAttendeesWidget(
                eventId: event.id,
                initialCount: event.interestCount,
                compact: true,
              ),
            ],
          ]),
          const SizedBox(height: 4),
          // Datum + Ort
          Text(
            '${event.eventDate.day}.${event.eventDate.month}. \u{2022} ${event.safeLocation}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }

  Widget _createEventCard(ThemeData theme) {
    return GestureDetector(behavior: HitTestBehavior.opaque, 
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CreateCommunityEventScreen())),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              const Color(0xFF8B5CF6).withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFF8B5CF6), size: 24),
            ),
            const SizedBox(height: 10),
            Text('Event\neintragen',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    height: 1.3)),
            const SizedBox(height: 4),
            Text('Kostenlos',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          const Text('\u{1F50D}', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text('Noch keine Events in deiner Naehe',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Sei der Erste! Trage ein Event ein und hilf anderen Familien.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateCommunityEventScreen())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Event eintragen'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}
