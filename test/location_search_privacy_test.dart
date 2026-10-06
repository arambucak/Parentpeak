import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';

void main() {
  final cases = [
    (52.5234567, 13.4087654, '52.52,13.41'),
    (-33.868819, 151.209296, '-33.87,151.21'),
    (0.004, -0.004, '0.0,-0.0'),
    (90.0, -180.0, '90.0,-180.0'),
    (0.00000001, 13.4087654, '0.0,13.41'),
  ];
  for (final (lat, lon, expected) in cases) {
    test('outgoing Nominatim query rounds $lat / $lon before HTTP', () async {
      final queries = <String>[];
      final service = LocationAutocompleteService(
        client: MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.path, '/search');
          queries.add(request.url.queryParameters['q']!);
          expect(request.url.queryParameters['format'], 'json');
          expect(request.url.queryParameters['addressdetails'], '1');
          return http.Response(
            jsonEncode([
              {
                'lat': '52.520123',
                'lon': '13.410456',
                'address': {
                  'city': 'Berlin',
                  'suburb': 'Mitte',
                  'postcode': '10115',
                },
              },
            ]),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final results = await service.searchCoordinates(lat, lon);
      expect(queries, [expected]);
      expect(results.single.city, 'Berlin');
      expect(results.single.shortLabel, 'Mitte, Berlin');
      expect(results.single.lat, 52.520123);
      expect(results.single.lon, 13.410456);
    });
  }

  test(
    'immediate coordinate-text searches cannot bypass coarse rounding',
    () async {
      String? query;
      final service = LocationAutocompleteService(
        client: MockClient((request) async {
          query = request.url.queryParameters['q'];
          return http.Response('[]', 200);
        }),
      );
      addTearDown(service.dispose);
      await service.searchImmediate('  52.5234567, 13.4087654  ');
      expect(query, '52.52,13.41');
      await service.searchImmediate('1e-8, 1.34087654e1');
      expect(query, '0.0,13.41');
    },
  );

  test('district and postal-code text keeps its geocoding meaning', () async {
    final queries = <String>[];
    final service = LocationAutocompleteService(
      client: MockClient((request) async {
        queries.add(request.url.queryParameters['q']!);
        return http.Response('[]', 200);
      }),
    );
    addTearDown(service.dispose);
    await service.searchImmediate('  Kreuzberg, Berlin  ');
    await service.searchImmediate('10997');
    await service.searchImmediate('Berlin & Brandenburg');
    expect(queries, ['Kreuzberg, Berlin', '10997', 'Berlin & Brandenburg']);
  });

  test('invalid programmatic coordinates never leave the device', () {
    var requests = 0;
    final service = LocationAutocompleteService(
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(service.dispose);
    for (final coordinates in [
      (double.nan, 13.4),
      (52.5, double.infinity),
      (90.1, 0.0),
      (0.0, -180.1),
    ]) {
      expect(
        () => service.searchCoordinates(coordinates.$1, coordinates.$2),
        throwsArgumentError,
      );
    }
    expect(requests, 0);
  });

  test('nearby exact positions share the same coarse provider query', () async {
    final queries = <String>[];
    final service = LocationAutocompleteService(
      client: MockClient((request) async {
        queries.add(request.url.queryParameters['q']!);
        return http.Response('[]', 200);
      }),
    );
    addTearDown(service.dispose);
    await service.searchCoordinates(52.520008, 13.404954);
    await service.searchCoordinates(52.5199, 13.4049);
    expect(queries, ['52.52,13.4', '52.52,13.4']);
  });

  test('provider notice is explicit and localized in all audit languages', () {
    for (final language in ['de', 'en', 'tr', 'ku']) {
      final notice = AppStringsManager.getString(
        language,
        'location_osm_notice',
      );
      expect(notice, contains('OpenStreetMap Nominatim'));
      expect(notice, contains('1 km'));
      expect(notice, isNot('location_osm_notice'));
    }
  });
}
