// Vertrauens-Vertrag für KI-entdeckte Events ("Events & Aktivitäten").
//
// Diese Kachel ist geschäftskritisch: Wenn Eltern sich auf ein Event verlassen,
// hinfahren und es existiert nicht, zerstört das Vertrauen. Die folgenden
// Garantien schützen davor. Sie sind hier BEWUSST an einem Ort gebündelt und
// als Vertrag dokumentiert — wer künftig den Event-Discovery-Code ändert und
// eine dieser Garantien bricht, bekommt hier sofort einen roten Test.
//
// GARANTIEN:
//  1. Kein vergangenes Einzel-Event erreicht den Feed.
//  2. Jedes Event hat eine eindeutige id (sonst öffnet die Detailansicht
//     für verschiedene Karten dasselbe Event).
//  3. Eine verortbare Adresse bekommt echte Koordinaten und gilt als bestätigt.
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
                  {'lat': '52.5200', 'lon': '13.4050'}
                ])
              : jsonEncode([]),
          200,
        );
      }),
    );

EventDiscoveryAgent _agent(String responseText, {EventGeocoder? geocoder}) =>
    EventDiscoveryAgent(
      geocoder: geocoder ?? _geocoder(),
      aiService: GeminiAIService(
        apiClient: _client(
          (_) => http.Response(jsonEncode({'text': responseText}), 200),
        ),
      ),
    );

void main() {
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
