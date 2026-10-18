import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/meetup_event.dart';

BackendApiClient _client(http.Response Function(http.Request) respond) =>
    BackendApiClient(
        baseUrl: 'http://localhost:3000',
        authToken: 'test-only',
        httpClient: MockClient((request) async => respond(request)));

/// Geocoder, der ohne echte Netzwerk-Calls antwortet. Standardmäßig löst jede
/// Adresse auf gültige Berliner Koordinaten auf; mit [resolvable] = false
/// liefert er leere Ergebnisse (Adresse nicht verortbar).
EventGeocoder _fakeGeocoder({bool resolvable = true}) => EventGeocoder(
      minimumInterval: Duration.zero,
      client: MockClient((_) async => http.Response(
            resolvable
                ? jsonEncode([
                    {'lat': '52.5200', 'lon': '13.4050'}
                  ])
                : jsonEncode([]),
            200,
          )),
    );

void main() {
  test('AI discovery requests a small grounded batch without invented dates',
      () async {
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient: _client((request) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final prompt = body['prompt'] as String;
            expect(body['useGoogleSearch'], isTrue);
            expect(prompt, contains('bis zu 5'));
            expect(prompt, contains('höchstens ein kurzer Satz'));
            expect(prompt, contains('eventDate=null'));
            expect(prompt, contains('ohne Treffer []'));
            // Der gelockerte Prompt erlaubt neben Einzel-Events auch
            // wiederkehrende/dauerhaft offene Familienorte und fordert dafür einen
            // Rhythmus-Hinweis statt eines erfundenen Datums.
            expect(prompt, contains('recurringNote'));
            expect(prompt, contains('wiederkehrende'));
            // Weiterhin keine erfundenen Platzhalter-Daten/-Mengen.
            expect(prompt, contains('Nichts erfinden'));
            expect(prompt, isNot(contains('genau 10')));
            expect(prompt, isNot(contains('T10:00:00')));
            return http.Response(jsonEncode({'text': '[]'}), 200);
          }),
        ));

    expect(await agent.discoverEvents(city: 'Berlin'), isEmpty);
  });

  test('recurring offer without a date is marked as recurring (not dropped)',
      () async {
    // Ein dauerhaft offenes Angebot (Familienzentrum mit Wochenprogramm) kommt
    // ohne eventDate, aber mit recurringNote. Es muss als isRecurring markiert
    // werden, damit es die Zeitfenster-Filter übersteht.
    final payload = jsonEncode([
      {
        'title': 'Offener Familientreff',
        'description': 'Jeden Samstag Spiel und Austausch',
        'category': 'familienzentrum',
        'ageLabels': ['0-6 Jahre'],
        'location': 'Kreuzberg',
        'eventDate': null,
        'recurringNote': 'jeden Samstag 10-13 Uhr',
        'price': 'kostenlos',
        'url': 'https://example.org/treff',
        'organizer': 'Familienzentrum',
      },
    ]);
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient:
              _client((_) => http.Response(jsonEncode({'text': payload}), 200)),
        ));
    final events = await agent.discoverEvents(city: 'Berlin');
    expect(events, hasLength(1));
    expect(events.first.eventDate, isNull);
    expect(events.first.isRecurring, isTrue);
    expect(events.first.recurringNote, 'jeden Samstag 10-13 Uhr');
  });

  test('AI failure makes one request and never invents replacement events',
      () async {
    var requests = 0;
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient: _client((request) {
            requests++;
            expect(jsonDecode(request.body)['useGoogleSearch'], isTrue);
            return http.Response('{}', 503);
          }),
        ));
    await expectLater(agent.discoverEvents(city: 'Berlin'), throwsException);
    expect(requests, 1);
  });

  test('AI successful empty result is empty; malformed response is a failure',
      () async {
    var text = '[]';
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient:
              _client((_) => http.Response(jsonEncode({'text': text}), 200)),
        ));
    expect(await agent.discoverEvents(city: 'Berlin'), isEmpty);
    text = 'not a result';
    await expectLater(
        agent.discoverEvents(city: 'Berlin'), throwsFormatException);
  });

  test('community empty acknowledgement does not resurrect old local events',
      () async {
    var empty = false;
    var fail = false;
    final backend = EventBackendService(apiClient: _client((_) {
      if (fail) return http.Response('{}', 503);
      return http.Response(
          jsonEncode({
            'events': empty
                ? []
                : [
                    {
                      'id': 'previous-community-event',
                      'hosterId': 'owner',
                      'title': 'Previously loaded',
                      'latitude': 52.52,
                      'longitude': 13.405,
                      'visibility': 'publicNearby',
                      'status': 'upcoming'
                    },
                  ]
          }),
          200);
    }));
    final service = EventService(backend: backend);
    Future<List<MeetupEvent>> load() => service.getDiscoverableEventsForUser(
          viewerUserId: 'owner',
          viewerLatitude: 52.52,
          viewerLongitude: 13.405,
        );
    expect(await load(), hasLength(1));
    empty = true;
    expect(await load(), isEmpty);
    fail = true;
    await expectLater(load(), throwsException);
    await expectLater(service.getEvents(), throwsException);
    await expectLater(service.getInvitationsForUser('owner'), throwsException);
  });

  test('AI result skips non-object entries instead of failing the whole feed',
      () async {
    // Gemini liefert ein valides Event + einen Müll-Eintrag (String). Der
    // Müll-Eintrag darf nicht den ganzen Feed verwerfen.
    final mixed = jsonEncode([
      {
        'title': 'Laternenfest',
        'description': 'Kurzes Fest',
        'category': 'familienzentrum',
        'ageLabels': ['3-6 Jahre'],
        'location': 'Kreuzberg',
        'eventDate': null,
        'price': 'kostenlos',
        'url': 'https://example.org/laterne',
        'organizer': 'Familienzentrum',
      },
      'kein-objekt',
    ]);
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient:
              _client((_) => http.Response(jsonEncode({'text': mixed}), 200)),
        ));
    final events = await agent.discoverEvents(city: 'Berlin');
    expect(events, hasLength(1));
    expect(events.first.title, 'Laternenfest');
  });

  test('discovered events always get unique ids even on duplicate/missing ids',
      () async {
    // Regression (Tester-Feedback): Gemini liefert mitunter für mehrere Events
    // dieselbe oder gar keine `id`. Die Detailansicht löst Events per id auf
    // (firstOrNull) — ohne eindeutige ids zeigte jede Karte dasselbe Event.
    final payload = jsonEncode([
      {
        'id': 'dup',
        'title': 'Theater am Markt',
        'location': 'Marktplatz 1, Berlin',
        'category': 'theater',
      },
      {
        'id': 'dup', // gleiche id wie oben
        'title': 'Schwimmbad Nord',
        'location': 'Seestraße 9, Berlin',
        'category': 'sport',
      },
      {
        // gar keine id
        'title': 'Bibliothek Mitte',
        'location': 'Leseweg 4, Berlin',
        'category': 'sonstiges',
      },
      {
        // ebenfalls keine id
        'title': 'Zoo-Führung',
        'location': 'Tierparkallee 2, Berlin',
        'category': 'natur',
      },
    ]);
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient:
              _client((_) => http.Response(jsonEncode({'text': payload}), 200)),
        ));

    final events = await agent.discoverEvents(city: 'Berlin');
    expect(events, hasLength(4));

    // Jede id ist eindeutig — Grundvoraussetzung dafür, dass die
    // Detailansicht pro Karte das richtige Event auflöst.
    final ids = events.map((e) => e.id).toList();
    expect(ids.toSet(), hasLength(4), reason: 'ids must be unique: $ids');
    expect(ids.every((id) => id.trim().isNotEmpty), isTrue);

    // Und jede id gehört weiterhin zum korrekten Event (Titel/Adresse intakt).
    final byId = {for (final e in events) e.id: e};
    expect(byId[events[0].id]!.title, 'Theater am Markt');
    expect(byId[events[1].id]!.title, 'Schwimmbad Nord');
    expect(byId[events[1].id]!.location, 'Seestraße 9, Berlin');
    expect(byId[events[2].id]!.title, 'Bibliothek Mitte');
    expect(byId[events[3].id]!.title, 'Zoo-Führung');
  });

  test('past dated single events are dropped; future and recurring survive',
      () async {
    // Vertrauensschutz: Ein datiertes Einzel-Event in der Vergangenheit darf
    // nicht in den Feed — sonst sähen Eltern ein Event, das es nicht mehr gibt.
    // Zukünftige Events und wiederkehrende/offene Angebote bleiben erhalten.
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 3));
    final future = now.add(const Duration(days: 5));
    final payload = jsonEncode([
      {
        'title': 'Vergangenes Konzert',
        'location': 'Altstadt, Berlin',
        'category': 'musik',
        'eventDate':
            DateTime(past.year, past.month, past.day, 10).toIso8601String(),
      },
      {
        'title': 'Kommendes Theater',
        'location': 'Marktplatz, Berlin',
        'category': 'theater',
        'eventDate': DateTime(future.year, future.month, future.day, 15)
            .toIso8601String(),
      },
      {
        'title': 'Offener Familientreff',
        'location': 'Kreuzberg, Berlin',
        'category': 'familienzentrum',
        'eventDate': null,
        'recurringNote': 'jeden Samstag 10-13 Uhr',
      },
    ]);
    final agent = EventDiscoveryAgent(
        geocoder: _fakeGeocoder(),
        aiService: GeminiAIService(
          apiClient:
              _client((_) => http.Response(jsonEncode({'text': payload}), 200)),
        ));

    final events = await agent.discoverEvents(city: 'Berlin');
    final titles = events.map((e) => e.title).toList();
    expect(titles, isNot(contains('Vergangenes Konzert')));
    expect(titles, contains('Kommendes Theater'));
    expect(titles, contains('Offener Familientreff'));
    expect(events, hasLength(2));
  });

  test('resolvable address gets coordinates and stays confirmed', () async {
    final payload = jsonEncode([
      {
        'title': 'Theater am Markt',
        'location': 'Marktplatz 1, Berlin',
        'category': 'theater',
        'recurringNote': 'täglich',
      },
    ]);
    final agent = EventDiscoveryAgent(
      geocoder: _fakeGeocoder(resolvable: true),
      aiService: GeminiAIService(
        apiClient:
            _client((_) => http.Response(jsonEncode({'text': payload}), 200)),
      ),
    );
    final events = await agent.discoverEvents(city: 'Berlin');
    expect(events, hasLength(1));
    expect(events.first.locationConfirmed, isTrue);
    // Echte Koordinaten vom Geocoder gesetzt → richtige Entfernungsanzeige.
    expect(events.first.latitude, 52.52);
    expect(events.first.longitude, 13.405);
  });

  test('unresolvable address is kept but flagged as unconfirmed', () async {
    // Vertrauensschutz Stufe 2 (Option B): Eine vage/nicht verortbare Adresse
    // verwirft das Event NICHT (könnte echt sein), markiert es aber als
    // nicht bestätigt, damit die UI ehrlich warnen kann.
    final payload = jsonEncode([
      {
        'title': 'Familienzentrum irgendwo',
        'location': 'Erfundene Gasse 999, Nirgendwo',
        'category': 'familienzentrum',
        'recurringNote': 'täglich',
      },
    ]);
    final agent = EventDiscoveryAgent(
      geocoder: _fakeGeocoder(resolvable: false),
      aiService: GeminiAIService(
        apiClient:
            _client((_) => http.Response(jsonEncode({'text': payload}), 200)),
      ),
    );
    final events = await agent.discoverEvents(city: 'Berlin');
    expect(events, hasLength(1), reason: 'event must not be dropped');
    expect(events.first.locationConfirmed, isFalse);
  });
}
