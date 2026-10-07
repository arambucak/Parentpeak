import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/models/treasure_category.dart';
import 'package:parentpeak/models/treasure_geometry.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:shared_preferences/shared_preferences.dart';

TreasureListing listing(String category, {double radius = 25}) =>
    TreasureListing(
      id: 'item',
      title: 'A book',
      category: category,
      sizeAge: '',
      conditionKey: 'round2',
      distanceMeters: null,
      shareRadiusKm: radius,
      colorLabel: '',
      note: '',
      latitude: 50.123456,
      longitude: 8.123456,
      imagePath: 'https://example.invalid/photo.png',
      createdAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stable and legacy categories normalize without inventing toys', () {
    for (final id in TreasureCategory.ids) {
      expect(TreasureCategory.normalize(id), id);
      expect(TreasureListing.fromMap(listing(id).toMap()).category, id);
    }
    for (final alias in ['Bücher', 'Books', 'Pirtûk', 'Kitaplar']) {
      expect(TreasureCategory.normalize(alias), 'books');
    }
    for (final alias in ['Fahrzeuge', 'Vehicles', 'Wesayît', 'Araçlar']) {
      expect(TreasureCategory.normalize(alias), 'vehicles');
    }
    expect(TreasureCategory.normalize('unrecognized'), 'other');
    expect(
      TreasureListing.fromMap({'distanceMeters': 10000}).distanceMeters,
      isNull,
      reason: 'Legacy caches may have stored publication radius as distance',
    );
  });

  for (final status in ['archived', 'reserved', 'unknown']) {
    test('$status HTTP create retains outcome but excludes unavailable cache entries', () async {
      final backend = TreasureBackendService(apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        authToken: 'test',
        httpClient: MockClient((request) async => http.Response(jsonEncode({
          'treasure': {
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': 'created',
            if (status != 'unknown') 'status': status,
          },
        }), 201)),
      ));
      final store = TreasureAccountStore(userIdProvider: () => 'owner');
      final service = TreasureListingService(store: store, backend: backend);
      final created = await service.createListing(listing('books'));
      expect(created!.status, status);
      expect(TreasureListing.fromMap(created.toMap()).status, status);
      expect(created.copyWith(title: 'Edited').status, status);
      expect(await service.loadListings(), isEmpty);
      final cache = await store.read(expectedScope: store.scope);
      expect(cache[TreasureAccountStore.feedKey], isEmpty);
      service.dispose();
    });
  }

  test(
    'all selected categories survive real HTTP create, cache persist and reopen',
    () async {
      for (final id in TreasureCategory.ids) {
        Map<String, dynamic>? sent;
        final backend = TreasureBackendService(
          apiClient: BackendApiClient(
            baseUrl: 'https://example.invalid',
            authToken: 'test',
            httpClient: MockClient((request) async {
              sent = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'treasure': {
                    ...sent!,
                    'id': id,
                    'status': 'available',
                    'createdAt': DateTime(2026).toIso8601String(),
                  },
                }),
                201,
              );
            }),
          ),
        );
        final store = TreasureAccountStore(userIdProvider: () => 'owner');
        final service = TreasureListingService(store: store, backend: backend);
        try {
          final created = await service.createListing(listing(id));
          expect(sent!['category'], id);
          expect(sent!['shareRadiusKm'], 25);
          expect(sent!['latitude'], 50.12);
          expect(sent!['longitude'], 8.12);
          expect(created!.category, id);
          expect(created.shareRadiusKm, 25);
          expect(
            created.distanceMeters,
            isNull,
            reason: 'Publication radius is not distance',
          );
          final cache = await store.read(expectedScope: store.scope);
          final restored = TreasureListing.fromMap(
            (cache[TreasureAccountStore.feedKey] as List).first
                as Map<String, dynamic>,
          );
          expect(restored.category, id);
          expect(restored.shareRadiusKm, 25);
          expect(restored.distanceMeters, isNull);
        } finally {
          service.dispose();
        }
      }
    },
  );

  test(
    'discovery rounds viewer query and retains server distance separately from radius',
    () async {
      final backend = TreasureBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) async {
            expect(request.url.queryParameters['latitude'], '50.12');
            expect(request.url.queryParameters['longitude'], '8.12');
            return http.Response(
              jsonEncode({
                'treasures': [
                  {
                    'id': 'one',
                    'category': 'books',
                    'shareRadiusKm': 25,
                    'distanceKm': 1.112,
                  },
                  {'id': 'missing', 'category': 'other', 'shareRadiusKm': 25},
                ],
              }),
              200,
            );
          }),
        ),
      );
      final results = await backend.fetchTreasures(
        latitude: 50.123456,
        longitude: 8.123456,
      );
      expect(results.first.distanceMeters, 1112);
      expect(results.first.shareRadiusKm, 25);
      expect(results.last.distanceMeters, isNull);
      expect(results.last.category, 'other');
      expect(
        await backend.fetchTreasures(latitude: 90.001, longitude: 8),
        isEmpty,
      );
      expect(backend.lastSyncError, 'treasureNetworkError');
    },
  );

  test(
    'coarse geometry matches backend, includes zero coordinates and handles boundaries',
    () {
      expect(TreasureGeometry.coarse(-0.125), -0.12);
      expect(TreasureGeometry.distanceMeters(50.001, 8.001, 50.004, 8.004), 0);
      expect(TreasureGeometry.distanceMeters(0, 0, 0.01, 0), 1112);
      expect(
        TreasureGeometry.distanceKm(0, 0, 0.01, 0),
        closeTo(1.1119492664455874, 1e-10),
      );
      for (final latitude in [null, double.nan, double.infinity, 90.001]) {
        expect(TreasureGeometry.distanceMeters(latitude, 0, 0, 0), isNull);
      }
      for (final radius in [1.0, 25.0]) {
        expect(TreasureGeometry.radius(radius), radius);
        expect(
          TreasureGeometry.withinRadius((radius * 1000).round(), radius),
          isTrue,
        );
        expect(
          TreasureGeometry.withinRadius((radius * 1000).round() + 1, radius),
          isFalse,
        );
      }
      for (final radius in [0.0, 0.8, 25.1, double.nan, double.infinity]) {
        expect(() => TreasureGeometry.radius(radius), throwsFormatException);
      }
      expect(
        () => TreasureListing.fromMap({'shareRadiusKm': 'invalid'}),
        throwsFormatException,
      );
    },
  );

  test(
    'draft radius validates boundaries while retaining legacy metre drafts unchanged',
    () async {
      final store = TreasureAccountStore(userIdProvider: () => 'owner');
      final service = TreasureListingService(store: store);
      addTearDown(service.dispose);
      await service.saveDraft({'categoryKey': 'books', 'distanceMeters': 800});
      expect(await service.loadDraft(), {
        'categoryKey': 'books',
        'distanceMeters': 800,
      });
      for (final radius in [1, 25]) {
        await service.saveDraft({
          'categoryKey': 'books',
          'shareRadiusKm': radius,
        });
        expect((await service.loadDraft())!['shareRadiusKm'], radius);
      }
      for (final radius in [0, 0.8, 25.1, '25']) {
        await expectLater(
          service.saveDraft({'shareRadiusKm': radius}),
          throwsFormatException,
        );
      }
      await expectLater(
        store.update(
          (data) => data[TreasureAccountStore.draftKey] = {
            'shareRadiusKm': double.nan,
          },
          expectedScope: store.scope,
        ),
        throwsFormatException,
      );
      expect((await service.loadDraft())!['shareRadiusKm'], 25);
    },
  );
}
