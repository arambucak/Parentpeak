// Vertrauens-Vertrag für KI-entdeckte Events ("Events & Aktivitäten").
//
// Diese Kachel ist geschäftskritisch: Wenn Eltern sich auf ein Event verlassen,
// hinfahren und es existiert nicht, zerstört das Vertrauen. Die folgenden
// Garantien schützen davor. Sie sind hier BEWUSST an einem Ort gebündelt und
// als Vertrag dokumentiert — wer künftig den Event-Discovery-Code ändert und
// eine dieser Garantien bricht, bekommt hier sofort einen roten Test.
//
// GARANTIEN:
//  1. Kein vergangenes datiertes Event erreicht den Feed, auch bei Wiederholung.
//  2. Jedes Event hat eine eindeutige id (sonst öffnet die Detailansicht
//     für verschiedene Karten dasselbe Event).
//  3. Nur ein konkret verorteter Veranstaltungsort gilt als ortsbestätigt.
//  4. Eine nicht verortbare Adresse wird NICHT verworfen (könnte echt sein),
//     aber als locationConfirmed = false markiert.
//  5. Ein Geocoder-Ausfall verwirft ein Event nie, markiert es aber
//     konservativ als nicht bestätigt (locationConfirmed = false).
//  6. Reiner Müll statt JSON ist ein echter Fehler, kein stilles "0 Treffer".

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/discovered_event.dart';

BackendApiClient _client(http.Response Function(http.Request) respond) =>
    BackendApiClient(
      baseUrl: 'http://localhost:3000',
      authToken: 'test-only',
      httpClient: MockClient((request) async => respond(request)),
    );

/// Geocoder ohne Netzwerk. [resolvable] steuert, ob Adressen verortet werden;
/// [throwing] simuliert einen Geocoder-Ausfall.
EventGeocoder _geocoder({bool resolvable = true, bool throwing = false}) =>
    EventGeocoder(
      minimumInterval: Duration.zero,
      client: MockClient((_) async {
        if (throwing) return http.Response('boom', 500);
        return http.Response(
          resolvable
              ? jsonEncode([
                  {'lat': '52.5200', 'lon': '13.4050', 'place_rank': 30}
                ])
              : jsonEncode([]),
          200,
        );
      }),
    );

EventDiscoveryAgent _agent(String responseText, {
  EventGeocoder? geocoder,
  List<String> groundingUrls = const [],
}) =>
    EventDiscoveryAgent(
      geocoder: geocoder ?? _geocoder(),
      aiService: GeminiAIService(
        apiClient: _client(
          (_) => http.Response(jsonEncode({
            'text': responseText,
            'groundingUrls': groundingUrls,
          }), 200),
        ),
      ),
    );

void main() {
  test('unexamined discovered events default to an unconfirmed location', () {
    final event = DiscoveredEvent(
      id: 'unknown', title: 'Offer', description: '',
      category: DiscoveredEventCategory.sonstiges,
      ageLabels: const [], location: 'Berlin', cityHint: 'Berlin',
      discoveredAt: DateTime.now(),
    );
    expect(event.locationConfirmed, isFalse);
    expect(event.copyWith(interestCount: 1).locationConfirmed, isFalse);
  });

  test('recurrence flags and notes cannot rescue an explicitly past date', () async {
    final past = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
    final events = await _agent(jsonEncode([
      {'title': 'Past flag', 'eventDate': past, 'isRecurring': true},
      {'title': 'Past note', 'eventDate': past, 'recurringNote': 'every week'},
      {'title': 'Ongoing', 'eventDate': null, 'recurringNote': 'every week'},
    ])).discoverEvents(city: 'Berlin');
    expect(events.map((e) => e.title), ['Ongoing']);
    expect(events.single.eventDate, isNull);
  });

  test('today remains valid even when recurring, without inventing a new date', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final events = await _agent(jsonEncode([
      {'title': 'Today', 'eventDate': today, 'isRecurring': true},
    ])).discoverEvents(city: 'Berlin');
    expect(events.single.eventDate, DateTime.parse(today));
    expect(events.single.isRecurring, isFalse);
  });

  test('unassociated grounding URLs never become event source links', () async {
    final events = await _agent(jsonEncode([
      {'title': 'Missing source'},
      {'title': 'Placeholder', 'url': 'https://...'},
      {'title': 'Associated', 'url': 'https://organizer.example/own-event'},
    ]), groundingUrls: ['https://unrelated.example/another-event'])
        .discoverEvents(city: 'Berlin');
    expect(events[0].url, isNull);
    expect(events[1].url, isNull);
    expect(events[2].url, 'https://organizer.example/own-event');
  });

  for (final url in [
    'javascript:alert(1)', 'https://...', 'https://example.org/...',
    'https://user:password@example.org/event', 'https://localhost/event',
    'https://.invalid/event',
  ]) {
    test('invalid source URL stays unknown: $url', () async {
      final events = await _agent(jsonEncode([
        {'title': 'Unknown source', 'url': url},
      ])).discoverEvents(city: 'Berlin');
      expect(events.single.url, isNull);
    });
  }

  for (final entry in <String, dynamic>{
    'title': 42, 'description': {}, 'category': [], 'ageLabels': '3 years',
    'location': 42, 'cityHint': [], 'eventDate': false, 'recurringNote': true,
    'isRecurring': 'true', 'eventTimeRange': {}, 'price': 5, 'url': [],
    'organizer': {},
  }.entries) {
    test('malformed ${entry.key} does not discard neighboring valid events', () async {
      final events = await _agent(jsonEncode([
        {'title': 'Valid first'},
        {'title': 'Malformed', entry.key: entry.value},
        {'title': 'Valid last'},
      ])).discoverEvents(city: 'Berlin');
      expect(events.map((e) => e.title), ['Valid first', 'Valid last']);
    });
  }

  for (final date in [
    'not-a-date', '2030-02-30', '2030-13-01', '2030-00-10',
    '2030-12-01T25:00:00', '2030-12-01T12:60:00',
    '2030-12-01T12:00:60', '2030-12-01T12:00:00+25:00',
  ]) {
    test('invalid calendar date is not normalized into a real event: $date', () async {
      final events = await _agent(jsonEncode([
        {'title': 'Invalid', 'eventDate': date, 'recurringNote': 'every week'},
        {'title': 'Valid', 'eventDate': '2030-12-01T12:00:00'},
      ])).discoverEvents(city: 'Berlin');
      expect(events.map((e) => e.title), ['Valid']);
    });
  }

  for (final date in [
    '2030-12-01', '2030-12-01T12:00:00Z',
    '2030-12-01T00:30:00+02:00', '2030-12-01T23:30:00-03:00',
  ]) {
    test('valid ISO dates keep their actual timezone and instant: $date', () async {
      final events = await _agent(jsonEncode([
        {'title': 'Valid', 'eventDate': date},
      ])).discoverEvents(city: 'Berlin');
      expect(events.single.eventDate, DateTime.parse(date));
    });
  }

  test('an entirely malformed array is a failure, not a successful empty feed', () async {
    for (final payload in [
      [42, 'invalid'],
      [{'title': ''}],
      [{'title': 'Invalid', 'ageLabels': [1]}],
      [{'title': 'Invalid', 'eventDate': 'invalid'}],
    ]) {
      await expectLater(_agent(jsonEncode(payload)).discoverEvents(city: 'Berlin'),
          throwsFormatException);
    }
  });

  test('a missing venue is never replaced with the geocoded search city', () async {
    var calls = 0;
    final events = await _agent(
      jsonEncode([{'title': 'No venue'}]),
      geocoder: EventGeocoder(client: MockClient((_) async {
        calls++;
        return http.Response('[{"lat":"52.52","lon":"13.4","place_rank":30}]', 200);
      })),
    ).discoverEvents(city: 'Berlin');
    expect(events.single.location, isEmpty);
    expect(events.single.cityHint, 'Berlin');
    expect(events.single.locationConfirmed, isFalse);
    expect(events.single.latitude, isNull);
    expect(calls, 0);
  });

  test('city-centroid coordinates are not a confirmed venue in discovery', () async {
    final events = await _agent(
      jsonEncode([{'title': 'Vague venue', 'location': 'Berlin'}]),
      geocoder: EventGeocoder(client: MockClient((_) async => http.Response(
        '[{"lat":"52.52","lon":"13.4","place_rank":16,"addresstype":"city","class":"boundary"}]', 200,
      ))),
    ).discoverEvents(city: 'Berlin');
    expect(events.single.locationConfirmed, isFalse);
    expect(events.single.latitude, isNull);
  });

  group('event trust contract', () {
    test('a mixed AI response is cleaned to only trustworthy events', () async {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 2));
      final future = now.add(const Duration(days: 4));
      final payload = jsonEncode([
        // vergangenes Einzel-Event -> muss raus (Garantie 1)
        {
          'id': 'a',
          'title': 'Vergangenes Fest',
          'location': 'Altstadt, Berlin',
          'category': 'festival',
          'eventDate':
              DateTime(past.year, past.month, past.day, 11).toIso8601String(),
        },
        // zukünftiges Event mit gleicher id -> bleibt, id wird eindeutig
        // gemacht (Garantien 1 + 2)
        {
          'id': 'a',
          'title': 'Kommendes Fest',
          'location': 'Marktplatz, Berlin',
          'category': 'festival',
          'eventDate': DateTime(future.year, future.month, future.day, 11)
              .toIso8601String(),
        },
        // wiederkehrendes offenes Angebot ohne Datum -> bleibt (Garantie 1)
        {
          'id': 'b',
          'title': 'Offener Treff',
          'location': 'Kreuzberg, Berlin',
          'category': 'familienzentrum',
          'eventDate': null,
          'recurringNote': 'jeden Mittwoch',
        },
      ]);

      final events = await _agent(payload).discoverEvents(city: 'Berlin');
      final titles = events.map((e) => e.title).toList();

      // Garantie 1: nur zukünftige/laufende Events.
      expect(titles, isNot(contains('Vergangenes Fest')));
      expect(titles, containsAll(['Kommendes Fest', 'Offener Treff']));
      expect(events, hasLength(2));

      // Garantie 2: eindeutige ids trotz Duplikat in der Antwort.
      final ids = events.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'ids must be unique');
      expect(ids.every((id) => id.trim().isNotEmpty), isTrue);

      // Garantie 3: verortbare Adressen -> Koordinaten + bestätigt.
      expect(events.every((e) => e.locationConfirmed), isTrue);
      expect(events.every((e) => e.latitude != null && e.longitude != null),
          isTrue);
    });

    test('unresolvable address is flagged, never dropped (guarantee 4)',
        () async {
      final payload = jsonEncode([
        {
          'id': 'x',
          'title': 'Vager Ort',
          'location': 'Nirgendwostraße 1, Erfundenheim',
          'category': 'sonstiges',
          'recurringNote': 'täglich',
        },
      ]);
      final events =
          await _agent(payload, geocoder: _geocoder(resolvable: false))
              .discoverEvents(city: 'Berlin');
      expect(events, hasLength(1));
      expect(events.first.locationConfirmed, isFalse);
    });

    test(
        'geocoder outage keeps the event but marks it unconfirmed (guarantee 5)',
        () async {
      final payload = jsonEncode([
        {
          'id': 'y',
          'title': 'Robustes Event',
          'location': 'Marktplatz, Berlin',
          'category': 'theater',
          'recurringNote': 'täglich',
        },
      ]);
      final events = await _agent(payload, geocoder: _geocoder(throwing: true))
          .discoverEvents(city: 'Berlin');
      // Ein Ausfall darf das Event nie verwerfen — es bleibt erhalten,
      // ehrlich als „Ort nicht bestätigt" gekennzeichnet.
      expect(events, hasLength(1));
      expect(events.first.locationConfirmed, isFalse);
    });

    test(
        'pure garbage is a real error, not a silent empty result (guarantee 6)',
        () async {
      await expectLater(
        _agent('totally not json').discoverEvents(city: 'Berlin'),
        throwsA(isA<FormatException>()),
      );
    });

    test('an explicit empty array is a legitimate "no results"', () async {
      final events = await _agent('[]').discoverEvents(city: 'Berlin');
      expect(events, isEmpty);
    });
  });
}
