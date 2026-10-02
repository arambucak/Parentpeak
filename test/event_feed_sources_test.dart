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
}
