import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileAccountStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = ProfileAccountStore(userIdProvider: () => 'onboarding-owner');
  });
  tearDown(() => store.dispose());

  test(
    'direct coordinates are rounded before persistence and reload',
    () async {
      final location = LocationService(store: store);
      addTearDown(location.dispose);
      await location.setCoordinates(52.5234567, 13.4078912, city: 'Berlin');
      final data = await store.read(store.ticket);
      expect(data[ProfileAccountStore.latitudeKey], 52.52);
      expect(data[ProfileAccountStore.longitudeKey], 13.41);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ProfileAccountStore.storageKey)!;
      expect(raw, isNot(contains('52.5234567')));
      expect(raw, isNot(contains('13.4078912')));
      final restarted = LocationService(store: store);
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restarted.latitude, 52.52);
      expect(restarted.longitude, 13.41);
    },
  );

  test(
    'already rounded coordinates remain stable including negatives',
    () async {
      final location = LocationService(store: store);
      addTearDown(location.dispose);
      await location.setCoordinates(-33.87, 151.21);
      await location.setCoordinates(location.latitude!, location.longitude!);
      final data = await store.read(store.ticket);
      expect(data[ProfileAccountStore.latitudeKey], -33.87);
      expect(data[ProfileAccountStore.longitudeKey], 151.21);
    },
  );

  test('GPS sends and persists only rounded coordinates', () async {
    final requests = <Uri>[];
    final location = LocationService(
      store: store,
      gpsProvider: () async => (52.5234567, 13.4078912),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response('{"address":{"city":"Berlin"}}', 200);
      }),
    );
    addTearDown(location.dispose);
    expect(await location.requestGPSLocation(), isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['lat'], '52.52');
    expect(requests.single.queryParameters['lon'], '13.41');
    final data = await store.read(store.ticket);
    expect(data[ProfileAccountStore.latitudeKey], 52.52);
    expect(data[ProfileAccountStore.longitudeKey], 13.41);
    expect(location.latitude, 52.52);
    expect(location.longitude, 13.41);
  });

  test('manual geocoding results are rounded before persistence', () async {
    final location = LocationService(
      store: store,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'lat': '52.5234567', 'lon': '13.4078912'},
          ]),
          200,
        ),
      ),
    );
    addTearDown(location.dispose);
    await location.setManualLocation('Unlisted Place');
    final data = await store.read(store.ticket);
    expect(data[ProfileAccountStore.latitudeKey], 52.52);
    expect(data[ProfileAccountStore.longitudeKey], 13.41);
  });
}
