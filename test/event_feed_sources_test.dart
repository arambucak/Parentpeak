import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/meetup_event.dart';

BackendApiClient _client(http.Response Function(http.Request) respond) =>
    BackendApiClient(
        baseUrl: 'http://localhost:3000',
        authToken: 'test-only',
        httpClient: MockClient((request) async => respond(request)));

void main() {
  test('AI discovery requests a small grounded batch without invented dates',
      () async {
    final agent = EventDiscoveryAgent(aiService: GeminiAIService(
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
    final agent = EventDiscoveryAgent(aiService: GeminiAIService(
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
        aiService: GeminiAIService(
      apiClient: _client((_) => http.Response(jsonEncode({'text': text}), 200)),
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
        aiService: GeminiAIService(
      apiClient:
          _client((_) => http.Response(jsonEncode({'text': mixed}), 200)),
    ));
    final events = await agent.discoverEvents(city: 'Berlin');
    expect(events, hasLength(1));
    expect(events.first.title, 'Laternenfest');
  });
}
