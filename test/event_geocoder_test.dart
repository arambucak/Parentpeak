import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/event_geocoder.dart';

void main() {
  test(
    'only the entered address is requested; cache and inflight deduplicate',
    () async {
      var calls = 0;
      final geocoder = EventGeocoder(
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.queryParameters['q'], 'Grunewald, Berlin');
          expect(request.headers['User-Agent'], 'ParentPeak-App/1.0');
          return http.Response('[{"lat":"52.46","lon":"13.26"}]', 200);
        }),
      );
      final results = await Future.wait([
        geocoder.resolve(' Grunewald,  Berlin '),
        geocoder.resolve('Grunewald, Berlin'),
      ]);
      expect(results, [(52.46, 13.26), (52.46, 13.26)]);
      expect(await geocoder.resolve('grunewald, berlin'), (52.46, 13.26));
      expect(calls, 1);
    },
  );

  for (final body in [
    '[]',
    '{}',
    'invalid',
    '[{"lat":"NaN","lon":"13"}]',
    '[{"lat":"91","lon":"13"}]',
    '[{"lat":"0","lon":"0"}]',
  ]) {
    test('unknown for invalid provider result $body', () async {
      final geocoder = EventGeocoder(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      expect(await geocoder.resolve('Berlin'), isNull);
    });
  }
  test('HTTP errors, transport errors and timeout remain unknown', () async {
    for (final handler in <Future<http.Response> Function(http.Request)>[
      (_) async => http.Response('denied', 429),
      (_) async => throw http.ClientException('offline'),
      (_) => Completer<http.Response>().future,
    ]) {
      final geocoder = EventGeocoder(
        client: MockClient(handler),
        timeout: const Duration(milliseconds: 10),
      );
      expect(await geocoder.resolve('Neuruppin'), isNull);
    }
  });
  test(
    'provider-resolved Berlin coordinates are not rejected as placeholders',
    () async {
      final geocoder = EventGeocoder(
        client: MockClient(
          (_) async => http.Response('[{"lat":"52.52","lon":"13.405"}]', 200),
        ),
      );
      expect(await geocoder.resolve('Berlin'), (52.52, 13.405));
    },
  );
  test(
    'coordinate validity rejects unknown but accepts real Berlin coordinates',
    () {
      expect(validCoordinates(52.52, 13.405), isTrue);
      expect(reliableEventCoordinates(52.52, 13.405), isTrue);
      expect(reliableEventCoordinates(0, 0), isFalse);
      expect(reliableEventCoordinates(null, 13), isFalse);
      expect(reliableEventCoordinates(52.46, 13.26), isTrue);
      expect(validCoordinates(0, 13), isTrue);
    },
  );
  group('roundCoordinate (Datensparsamkeit)', () {
    test('rundet standardmäßig auf 2 Nachkommastellen (~1 km)', () {
      expect(roundCoordinate(52.5234567), 52.52);
      expect(roundCoordinate(13.4087654), 13.41);
      // Metergenaue Varianten desselben Orts kollabieren auf denselben Wert.
      expect(roundCoordinate(52.520008), roundCoordinate(52.519900));
    });
    test('rundet negative Koordinaten korrekt', () {
      expect(roundCoordinate(-33.868819), -33.87);
      expect(roundCoordinate(-0.004), 0.0);
    });
    test('respektiert fractionDigits und lässt nicht-endliche Werte durch', () {
      expect(roundCoordinate(52.5234567, fractionDigits: 1), 52.5);
      expect(roundCoordinate(double.nan).isNaN, isTrue);
      expect(roundCoordinate(double.infinity), double.infinity);
    });
  });
}
