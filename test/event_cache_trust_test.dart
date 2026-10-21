import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/event_cache_service.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/models/discovered_event.dart';

DiscoveredEvent _event({
  DateTime? eventDate,
  bool isRecurring = false,
  String? price,
  bool locationConfirmed = true,
}) {
  return DiscoveredEvent(
    id: 'ev_test',
    title: 'Kinderflohmarkt',
    description: 'Kleidung und Spielzeug',
    category: DiscoveredEventCategory.sonstiges,
    ageLabels: const ['0–3 Jahre'],
    location: 'Marktplatz 1',
    cityHint: 'Berlin',
    latitude: 52.5,
    longitude: 13.4,
    eventDate: eventDate,
    isRecurring: isRecurring,
    recurringNote: isRecurring ? 'Jeden Samstag' : null,
    price: price,
    locationConfirmed: locationConfirmed,
    discoveredAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('EventCacheService trust rules', () {
    test('one-off event without a date is dropped, never given a made-up date',
        () {
      expect(EventCacheService.toCommunityEvent(_event()), isNull);
    });

    test('recurring event without a date is kept and marked recurring', () {
      final converted =
          EventCacheService.toCommunityEvent(_event(isRecurring: true));
      expect(converted, isNotNull);
      expect(converted!.isRecurring, isTrue);
      expect(converted.recurringNote, 'Jeden Samstag');
    });

    test('unknown price is neither free nor a price label', () {
      final converted = EventCacheService.toCommunityEvent(
          _event(eventDate: DateTime(2030, 5, 1)))!;
      expect(converted.isFree, isFalse);
      expect(converted.price, isEmpty);
    });

    test('explicit free price is free, a paid price is kept', () {
      final free = EventCacheService.toCommunityEvent(
          _event(eventDate: DateTime(2030, 5, 1), price: 'Kostenlos'))!;
      final paid = EventCacheService.toCommunityEvent(
          _event(eventDate: DateTime(2030, 5, 1), price: '5 €'))!;
      expect(free.isFree, isTrue);
      expect(paid.isFree, isFalse);
      expect(paid.price, '5 €');
    });

    test('unconfirmed location only shows the city and no coordinates', () {
      final converted = EventCacheService.toCommunityEvent(_event(
          eventDate: DateTime(2030, 5, 1), locationConfirmed: false))!;
      expect(converted.location, 'Berlin');
      expect(converted.lat, isNull);
      expect(converted.lon, isNull);
      expect(converted.source, EventSource.kiAgent);
    });

    test('confirmed location keeps address and coordinates', () {
      final converted = EventCacheService.toCommunityEvent(
          _event(eventDate: DateTime(2030, 5, 1)))!;
      expect(converted.location, 'Marktplatz 1');
      expect(converted.lat, 52.5);
    });
  });
}
