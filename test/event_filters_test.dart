import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/meetup_event.dart';

void main() {
  test('Kreuzberg to Grunewald uses actual haversine distance', () {
    expect(
      eventDistanceKm(52.4986, 13.4033, 52.4861, 13.2599),
      closeTo(9.81, 0.1),
    );
    expect(
      eventDistanceKm(52.4986, 13.4033, 52.4986, 13.4033),
      closeTo(0, 0.001),
    );
    expect(eventDistanceKm(double.nan, 13, 52, 13), isNull);
    expect(eventDistanceKm(52, 13, null, 13), isNull);
    expect(eventDistanceKm(52, 13, 0, 0), isNull);
  });
  test('missing, mixed and known age groups retain honest semantics', () {
    expect(eventMatchesAges([], [AgeGroup.infant]), isTrue);
    expect(eventMatchesAges([AgeGroup.mixed], [AgeGroup.infant]), isTrue);
    expect(eventMatchesAges([AgeGroup.teenager], [AgeGroup.infant]), isFalse);
    expect(eventAgesFromLabel('11-16 Jahre'), [AgeGroup.teenager]);
    expect(eventAgesFromLabel('4-10 Jahre'), [
      AgeGroup.preschool,
      AgeGroup.elementary,
    ]);
    expect(eventAgesFromLabel('unbekannt'), isEmpty);
  });
  test('time filters keep today all day, drop yesterday; unknown only in all',
      () {
    final now = DateTime(2026, 10, 3, 12);
    // Heutige Events bleiben den ganzen Tag sichtbar — auch wenn ihr Datum
    // schon früher am Tag liegt (z.B. 00:00) oder vor einer Minute war.
    expect(
      eventMatchesTime(now.subtract(const Duration(minutes: 1)), 'all', now),
      isTrue,
    );
    expect(eventMatchesTime(DateTime(2026, 10, 3), 'all', now), isTrue);
    expect(eventMatchesTime(DateTime(2026, 10, 3), 'today', now), isTrue);
    // Gestern bleibt ausgeschlossen.
    expect(eventMatchesTime(DateTime(2026, 10, 2, 23), 'all', now), isFalse);
    // Unbekanntes Datum nur bei "all".
    expect(eventMatchesTime(null, 'all', now), isTrue);
    expect(eventMatchesTime(null, 'today', now), isFalse);
    expect(eventMatchesTime(DateTime(2026, 10, 3, 15), 'today', now), isTrue);
    expect(eventMatchesTime(DateTime(2026, 10, 4, 15), 'weekend', now), isTrue);
    expect(
      eventMatchesTime(DateTime(2026, 10, 10, 15), 'weekend', now),
      isFalse,
    );
  });
  test('recurring/open offers without a date pass every time window', () {
    final now = DateTime(2026, 10, 3, 12);
    // Wiederkehrende/dauerhaft offene Angebote (z.B. Familienzentrum mit
    // Wochenprogramm, offener Spielplatz) haben kein festes Datum, sind aber
    // an jedem Tag relevant — sie dürfen bei "Heute"/"Wochenende" nicht
    // herausfallen.
    expect(eventMatchesTime(null, 'today', now, isRecurring: true), isTrue);
    expect(eventMatchesTime(null, 'weekend', now, isRecurring: true), isTrue);
    expect(eventMatchesTime(null, 'all', now, isRecurring: true), isTrue);
    // Einmalige Angebote ohne Datum bleiben weiterhin nur bei "all" sichtbar.
    expect(eventMatchesTime(null, 'today', now, isRecurring: false), isFalse);
    expect(eventMatchesTime(null, 'weekend', now), isFalse);
  });
  test('ranking rewards known proximity, time and confirmed age fit', () {
    final now = DateTime(2026, 10, 3);
    double score(double? km, int days, List<AgeGroup> ages) =>
        eventRankingScore(
          distance: km,
          date: now.add(Duration(days: days)),
          ages: ages,
          selected: [AgeGroup.preschool],
          now: now,
        );
    expect(
      score(2, 1, [AgeGroup.preschool]),
      greaterThan(score(15, 1, [AgeGroup.preschool])),
    );
    expect(score(2, 1, []), greaterThan(score(2, 10, [])));
    expect(score(2, 1, [AgeGroup.preschool]), greaterThan(score(2, 1, [])));
    expect(score(null, 1, []), lessThan(score(2, 1, [])));
  });
  test(
    'API receives dynamic filters, maps prices and rechecks legacy Berlin addresses',
    () async {
      final geocoder = EventGeocoder(
        minimumInterval: Duration.zero,
        client: MockClient((request) async {
          expect(request.url.queryParameters['q'], 'Grunewald, Berlin');
          return http.Response('[{"lat":"52.4861","lon":"13.2599"}]', 200);
        }),
      );
      final backend = EventBackendService(
        geocoder: geocoder,
        apiClient: BackendApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient((request) async {
            expect(request.url.queryParameters['radiusKm'], '50.0');
            expect(request.url.queryParameters['nearbyOnly'], 'false');
            expect(request.url.queryParameters['onlyFree'], 'true');
            expect(request.url.queryParameters['timeWindow'], 'today');
            expect(request.url.queryParameters['ageGroups'], 'preschool');
            return http.Response(
              jsonEncode({
                'events': [
                  {
                    'id': 'legacy',
                    'location': 'Grunewald, Berlin',
                    'latitude': 52.52,
                    'longitude': 13.405,
                    'costPerPerson': '12.50',
                  },
                  {'id': 'unknown', 'latitude': null, 'longitude': 13},
                ],
              }),
              200,
            );
          }),
        ),
      );
      final events = await backend.discoverEventsForUser(
        viewerUserId: 'viewer',
        viewerLatitude: double.nan,
        viewerLongitude: double.nan,
        radiusKm: 50,
        onlyFree: true,
        timeWindow: 'today',
        ageGroups: [AgeGroup.preschool],
      );
      expect(events.first.latitude, 52.4861);
      expect(events.first.price, 12.5);
      expect(events.last.hasReliableCoordinates, isFalse);
      expect(events.last.latitude.isNaN, isTrue);
      expect(events.last.toJson()['latitude'], isNull);
    },
  );
  test(
    'unknown coordinates remain visible unless proximity-only is selected',
    () async {
      final backend = EventBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'events': [
                  {
                    'id': 'unknown',
                    'startDate': DateTime.now()
                        .add(const Duration(days: 1))
                        .toIso8601String(),
                  },
                  {
                    'id': 'past',
                    'startDate': DateTime.now()
                        .subtract(const Duration(days: 1))
                        .toIso8601String(),
                  },
                ],
              }),
              200,
            ),
          ),
        ),
      );
      final service = EventService(backend: backend);
      Future<List<MeetupEvent>> load(bool nearbyOnly) =>
          service.getFilteredDiscoverableEventsForUser(
            viewerUserId: 'viewer',
            viewerLatitude: double.nan,
            viewerLongitude: double.nan,
            nearbyOnly: nearbyOnly,
            ageGroups: [AgeGroup.preschool],
          );
      expect((await load(false)).map((event) => event.id), ['unknown']);
      expect(await load(true), isEmpty);
    },
  );
  test(
    'legacy resolution preserves true Berlin and keeps failed addresses unknown',
    () async {
      final geocoder = EventGeocoder(
        minimumInterval: Duration.zero,
        client: MockClient(
          (request) async => http.Response(
            request.url.queryParameters['q'] == 'Berlin'
                ? '[{"lat":"52.52","lon":"13.405"}]'
                : '[]',
            200,
          ),
        ),
      );
      final backend = EventBackendService(
        geocoder: geocoder,
        apiClient: BackendApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'events': [
                  {
                    'id': 'real',
                    'location': 'Berlin',
                    'latitude': null,
                    'longitude': null,
                    'coordinatesNeedResolution': true,
                  },
                  {
                    'id': 'unknown',
                    'location': 'Unknown street',
                    'latitude': 52.52,
                    'longitude': 13.405,
                  },
                ],
              }),
              200,
            ),
          ),
        ),
      );
      final events = await backend.fetchEvents();
      expect(events.first.hasReliableCoordinates, isTrue);
      expect(events.first.latitude, 52.52);
      expect(events.last.hasReliableCoordinates, isFalse);
      expect(events.last.toJson()['latitude'], isNull);
      expect(events.last.toJson()['longitude'], isNull);
    },
  );
  test(
    'resolved legacy addresses are filtered by actual distance, not the old Berlin point',
    () async {
      final geocoder = EventGeocoder(
        client: MockClient(
          (_) async =>
              http.Response('[{"lat":"52.4861","lon":"13.2599"}]', 200),
        ),
      );
      final backend = EventBackendService(
        geocoder: geocoder,
        apiClient: BackendApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'events': [
                  {
                    'id': 'legacy',
                    'location': 'Grunewald, Berlin',
                    'coordinatesNeedResolution': true,
                    'startDate': DateTime.now()
                        .add(const Duration(days: 1))
                        .toIso8601String(),
                  },
                ],
              }),
              200,
            ),
          ),
        ),
      );
      final service = EventService(backend: backend);
      Future<List<MeetupEvent>> load(double radius) =>
          service.getFilteredDiscoverableEventsForUser(
            viewerUserId: 'viewer',
            viewerLatitude: 52.4986,
            viewerLongitude: 13.4033,
            radiusKm: radius,
            nearbyOnly: true,
          );
      expect(await load(5), isEmpty);
      expect((await load(10)).map((event) => event.id), ['legacy']);
    },
  );
}
