import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ProfileAccountStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());
  void switchTo(String? next) { uid = next; store.synchronize(); }

  test('coordinates and cache isolate A/B/logout/restart; legacy is not read', () async {
    SharedPreferences.setMockInitialValues({
      'location.latitude': 55.0, 'location.longitude': 13.0, 'location.city': 'Legacy',
    });
    final location = LocationService(store: store);
    await location.initialize();
    expect(location.hasLocation, false);
    await location.setCoordinates(50, 10, city: 'A');
    expect(location.city, 'A');
    switchTo('b');
    expect(location.hasLocation, false);
    expect(location.city, null);
    await location.initialize();
    await location.setCoordinates(40, 30, city: 'B');
    switchTo(null);
    expect(location.hasLocation, false);
    switchTo('a');
    await location.initialize();
    expect(location.latitude, 50);
    expect(location.city, 'A');
    await location.clear();
    expect(location.hasLocation, false);
    final restarted = LocationService(store: store);
    await restarted.initialize();
    expect(restarted.city, null);
    restarted.dispose();
    location.dispose();
  });

  test('pending GPS cannot geocode or save after account switch', () async {
    final gate = Completer<(double, double)>();
    var requests = 0;
    final location = LocationService(store: store, gpsProvider: () => gate.future,
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{"address":{"city":"A"}}', 200);
        }));
    final operation = location.requestGPSLocation();
    switchTo(null); switchTo('a');
    gate.complete((50.0, 10.0));
    expect(await operation, false);
    expect(requests, 0);
    expect(await store.read(store.ticket), isEmpty);
    expect(location.hasLocation, false);
    location.dispose();
  });

  for (final reverse in [false, true]) {
    test('pending ${reverse ? "reverse" : "forward"} response cannot save into B', () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final location = LocationService(store: store,
          gpsProvider: () async => (50.0, 10.0),
          httpClient: MockClient((_) { started.complete(); return response.future; }));
      final Future<bool> operation = reverse
          ? location.requestGPSLocation()
          : (() async { await location.setManualLocation('Unlisted Place'); return true; })();
      await started.future;
      switchTo('b');
      response.complete(http.Response(reverse
          ? '{"address":{"city":"Old A"}}'
          : '[{"lat":"50","lon":"10"}]', 200));
      if (reverse) {
        expect(await operation, false);
      } else {
        await expectLater(operation, throwsA(isA<ProfileAccountChanged>()));
      }
      expect(await store.read(store.ticket), isEmpty);
      expect(location.city, null);
      location.dispose();
    });
  }

  test('failed location persistence leaves cache and account unchanged', () async {
    final failing = ProfileAccountStore(userIdProvider: () => uid,
        persist: (key, value) async => false);
    final location = LocationService(store: failing);
    await expectLater(location.setCoordinates(50, 10, city: 'Unsaved'), throwsStateError);
    expect(location.hasLocation, false);
    expect(await failing.read(failing.ticket), isEmpty);
    location.dispose(); failing.dispose();
  });
}
