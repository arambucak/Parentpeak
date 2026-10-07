import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Offline extends TreasureBackendService {
  @override
  bool get isEnabled => false;
}

class _DelayedBackend extends TreasureBackendService {
  final result = Completer<TreasureMineOverview?>();
  String? requestedUid;
  @override
  bool get isEnabled => true;
  @override
  Future<TreasureMineOverview?> fetchMine({required String userId}) {
    requestedUid = userId;
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late TreasureAccountStore store;
  Map<String, Object> legacy() => {
    TreasureAccountStore.draftKey: jsonEncode({
      'title': 'Private draft',
      'conditionIndex': 1,
      'distanceMeters': 120,
    }),
    TreasureAccountStore.reservedKey: ['reserved'],
    TreasureAccountStore.blockedKey: ['blocked'],
    TreasureAccountStore.reportedKey: ['reported'],
    TreasureAccountStore.feedKey: jsonEncode([
      {'id': 'global-feed'},
    ]),
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = TreasureAccountStore(userIdProvider: () => uid);
  });

  test(
    'drafts, reservations, flags and feed separate A, B and guest',
    () async {
      final a = store.scope;
      await store.update(
        (data) => data.addAll({
          TreasureAccountStore.draftKey: {'title': 'A'},
          TreasureAccountStore.reservedKey: ['a-reserved'],
          TreasureAccountStore.blockedKey: ['a-blocked'],
          TreasureAccountStore.reportedKey: ['a-reported'],
          TreasureAccountStore.feedKey: [
            {'id': 'a-feed'},
          ],
        }),
        expectedScope: a,
      );
      for (final next in ['b', null]) {
        uid = next;
        expect(await store.read(expectedScope: store.scope), isEmpty);
        await store.update(
          (data) =>
              data[TreasureAccountStore.draftKey] = {'title': next ?? 'guest'},
          expectedScope: store.scope,
        );
      }
      uid = 'a';
      final data = await store.read(expectedScope: a);
      expect(data[TreasureAccountStore.draftKey], {'title': 'A'});
      expect(data[TreasureAccountStore.reservedKey], ['a-reserved']);
      expect(data[TreasureAccountStore.blockedKey], ['a-blocked']);
      expect(data[TreasureAccountStore.reportedKey], ['a-reported']);
      expect(data[TreasureAccountStore.feedKey], [
        {'id': 'a-feed'},
      ]);
    },
  );

  test(
    'explicit atomic claim retains every original and excludes global feed',
    () async {
      final original = legacy();
      SharedPreferences.setMockInitialValues(original);
      expect(await store.read(expectedScope: store.scope), isEmpty);
      expect(
        await store.hasUnassignedLegacy(expectedScope: store.scope),
        isTrue,
      );
      await store.claimLegacy(expectedScope: store.scope);
      final data = await store.read(expectedScope: store.scope);
      expect(
        (data[TreasureAccountStore.draftKey] as Map)['title'],
        'Private draft',
      );
      expect(data[TreasureAccountStore.reservedKey], ['reserved']);
      expect(data[TreasureAccountStore.blockedKey], ['blocked']);
      expect(data[TreasureAccountStore.reportedKey], ['reported']);
      expect(data.containsKey(TreasureAccountStore.feedKey), isFalse);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in original.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
      expect(
        jsonDecode(
          prefs.getString(TreasureAccountStore.storageKey)!,
        )['legacyOwner'],
        store.scope,
      );
      await store.claimLegacy(expectedScope: store.scope);
      expect(
        await store.hasUnassignedLegacy(expectedScope: store.scope),
        isFalse,
      );
      uid = 'b';
      await expectLater(
        store.claimLegacy(expectedScope: store.scope),
        throwsStateError,
      );
      expect(await store.read(expectedScope: store.scope), isEmpty);
    },
  );

  test(
    'Treasure ownership is independent of finance and central claims',
    () async {
      final original = {
        ...legacy(),
        FamilyHubStore.storageKey: jsonEncode({
          'accounts': {},
          'legacyOwner': 'account.other',
        }),
        FamilyFinanceStore.storageKey: jsonEncode({
          'accounts': {},
          'legacyOwner': 'account.other',
        }),
        'treasure.ai_photo_consent.v1.account.a': true,
      };
      SharedPreferences.setMockInitialValues(original);
      await store.claimLegacy(expectedScope: store.scope);
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        FamilyHubStore.storageKey,
        FamilyFinanceStore.storageKey,
      ]) {
        expect(prefs.getString(key), original[key]);
      }
      expect(
        (await store.read(expectedScope: store.scope)).keys,
        isNot(contains('treasure.ai_photo_consent.v1.account.a')),
      );
    },
  );

  test(
    'account draft and deliberate clear take priority; flags merge',
    () async {
      for (final draft in [
        {'title': 'Current'},
        null,
      ]) {
        SharedPreferences.setMockInitialValues(legacy());
        await store.update(
          (data) => data.addAll({
            TreasureAccountStore.draftKey: draft,
            TreasureAccountStore.reservedKey: ['current', 'reserved'],
          }),
          expectedScope: store.scope,
        );
        await store.claimLegacy(expectedScope: store.scope);
        final data = await store.read(expectedScope: store.scope);
        expect(data[TreasureAccountStore.draftKey], draft);
        expect(data[TreasureAccountStore.reservedKey], ['current', 'reserved']);
      }
    },
  );

  test(
    'guest cannot claim and global discovery cache alone is not legacy ownership',
    () async {
      SharedPreferences.setMockInitialValues(legacy());
      uid = null;
      await expectLater(
        store.claimLegacy(expectedScope: store.scope),
        throwsStateError,
      );
      SharedPreferences.setMockInitialValues({
        TreasureAccountStore.feedKey: '[]',
      });
      expect(
        await store.hasUnassignedLegacy(expectedScope: store.scope),
        isFalse,
      );
    },
  );

  test(
    'malformed legacy and unsafe slider/index values never acquire an owner',
    () async {
      for (final draft in [
        'bad json',
        '[]',
        '{"conditionIndex":99}',
        '{"distanceMeters":0}',
        '{"imagePaths":[9]}',
      ]) {
        SharedPreferences.setMockInitialValues({
          TreasureAccountStore.draftKey: draft,
        });
        await expectLater(
          store.claimLegacy(expectedScope: store.scope),
          throwsFormatException,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(TreasureAccountStore.draftKey), draft);
        expect(prefs.containsKey(TreasureAccountStore.storageKey), isFalse);
      }
    },
  );

  test('malformed envelope and wrong owner are explicit read errors', () async {
    for (final raw in [
      '{',
      '{"accounts":[]}',
      '{"accounts":{"account.a":{"owner":"account.b","data":{}}}}',
    ]) {
      SharedPreferences.setMockInitialValues({
        TreasureAccountStore.storageKey: raw,
      });
      await expectLater(
        store.read(expectedScope: store.scope),
        throwsFormatException,
      );
    }
  });

  test(
    'false and thrown claim acknowledgements leave legacy unassigned',
    () async {
      for (final failByThrowing in [false, true]) {
        SharedPreferences.setMockInitialValues(legacy());
        final failed = TreasureAccountStore(
          userIdProvider: () => uid,
          persist: (_, __) async {
            if (failByThrowing) throw StateError('storage unavailable');
            return false;
          },
        );
        await expectLater(
          failed.claimLegacy(expectedScope: failed.scope),
          throwsStateError,
        );
        expect(await failed.read(expectedScope: failed.scope), isEmpty);
        expect(
          await failed.hasUnassignedLegacy(expectedScope: failed.scope),
          isTrue,
        );
      }
    },
  );

  test(
    'queued writes preserve changes and recover after a rejected write',
    () async {
      final failed = TreasureAccountStore(
        userIdProvider: () => uid,
        persist: (_, __) async => false,
      );
      final rejected = failed.update(
        (data) => data[TreasureAccountStore.reservedKey] = ['lost'],
        expectedScope: store.scope,
      );
      final rejection = expectLater(rejected, throwsStateError);
      await Future.wait([
        rejection,
        store.update(
          (data) => data[TreasureAccountStore.blockedKey] = ['one'],
          expectedScope: store.scope,
        ),
        store.update(
          (data) => data[TreasureAccountStore.reportedKey] = ['two'],
          expectedScope: store.scope,
        ),
      ]);
      final data = await store.read(expectedScope: store.scope);
      expect(data[TreasureAccountStore.blockedKey], ['one']);
      expect(data[TreasureAccountStore.reportedKey], ['two']);
      expect(data.containsKey(TreasureAccountStore.reservedKey), isFalse);
    },
  );

  test(
    'account change during commit never writes into the new account',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final changing = TreasureAccountStore(
        userIdProvider: () => uid,
        persist: (key, value) async {
          uid = 'b';
          return prefs.setString(key, value);
        },
      );
      await expectLater(
        changing.claimLegacy(expectedScope: 'account.a'),
        throwsA(isA<TreasureAccountChanged>()),
      );
      expect(await changing.read(expectedScope: 'account.b'), isEmpty);
      uid = 'a';
      await expectLater(
        store.read(expectedScope: 'account.b'),
        throwsA(isA<TreasureAccountChanged>()),
      );
    },
  );

  test(
    'service draft snapshot, cache and reservations obey account boundaries',
    () async {
      final service = TreasureListingService(store: store, backend: _Offline());
      addTearDown(service.dispose);
      final draft = {'title': 'A'};
      final saved = service.saveDraft(draft);
      draft['title'] = 'mutated';
      await saved;
      expect(await service.loadDraft(), {'title': 'A'});
      expect(await service.reserveListing(listingId: 'A-reserved'), isFalse);
      await store.update((data) => data[TreasureAccountStore.reservedKey] = ['A-reserved'],
        expectedScope: store.scope);
      final listing = TreasureListing(
        id: 'a',
        title: 'Private feed',
        category: 'other',
        sizeAge: '',
        conditionKey: 'good',
        distanceMeters: 120,
        colorLabel: '',
        note: '',
        createdAt: DateTime(2026),
      );
      await store.update(
        (data) => data[TreasureAccountStore.feedKey] = [listing.toMap()],
        expectedScope: store.scope,
      );
      expect((await service.loadListings()).single.title, 'Private feed');
      uid = 'b';
      expect(await service.loadDraft(), isNull);
      expect(await service.loadReservedIds(), isEmpty);
      expect(await service.loadListings(), isEmpty);
      uid = null;
      expect(await service.loadDraft(), isNull);
      expect(
        await service.reserveListing(listingId: 'guest-reserved'),
        isFalse,
      );
      uid = 'a';
      expect(await service.loadReservedIds(), {'A-reserved'});
    },
  );

  test(
    'late backend response and old bound service cannot cross accounts',
    () async {
      final backend = _DelayedBackend();
      final root = TreasureListingService(store: store, backend: backend);
      final bound = root.forScope(store.scope);
      addTearDown(root.dispose);
      addTearDown(bound.dispose);
      final loading = bound.loadMine();
      final rejected = expectLater(
        loading,
        throwsA(isA<TreasureAccountChanged>()),
      );
      expect(backend.requestedUid, 'a');
      uid = 'b';
      backend.result.complete(
        const TreasureMineOverview(offers: [], reservedByMe: []),
      );
      await rejected;
      await expectLater(
        bound.saveDraft({'title': 'Old A'}),
        throwsA(isA<TreasureAccountChanged>()),
      );
      expect(await store.read(expectedScope: store.scope), isEmpty);
      expect(bound.lastSyncError, isNull);
    },
  );

  for (final action in [
    'reserve',
    'delete',
    'confirm',
    'complete',
    'cancel',
    'report',
    'mine',
    'create',
  ]) {
    test(
      'HTTP $action retains originating UID and rejects a late account response',
      () async {
        final response = Completer<http.Response>();
        final started = Completer<http.Request>();
        final backend = TreasureBackendService(
          apiClient: BackendApiClient(
            baseUrl: 'https://example.invalid',
            authToken: 'test-token',
            httpClient: MockClient((request) {
              started.complete(request);
              return response.future;
            }),
          ),
        );
        final service = TreasureListingService(
          store: store,
          backend: backend,
          expectedScope: store.scope,
        );
        addTearDown(service.dispose);
        final operation = switch (action) {
          'reserve' => service.reserveListing(listingId: 'item'),
          'delete' => service.deleteListing(listingId: 'item'),
          'confirm' => service.confirmHandover(
            listingId: 'item',
            handoverId: 'handover',
          ),
          'complete' => service.completeHandover(
            listingId: 'item',
            handoverId: 'handover',
          ),
          'cancel' => service.cancelReservation(listingId: 'item'),
          'report' => service.reportListing(listingId: 'item', reason: 'other'),
          'mine' => service.loadMine(),
          _ => service.createListing(
            TreasureListing(
              id: 'item',
              title: 'Origin A',
              category: 'other',
              sizeAge: '',
              conditionKey: 'good',
              distanceMeters: 120,
              colorLabel: '',
              note: '',
              latitude: 50,
              longitude: 8,
              imagePath: 'https://example.invalid/photo.jpg',
              createdAt: DateTime(2026),
            ),
          ),
        };
        final rejection = expectLater(
          operation,
          throwsA(isA<TreasureAccountChanged>()),
        );
        final request = await started.future;
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body.values.contains('a') ||
              request.url.queryParameters['userId'] == 'a',
          isTrue,
        );
        uid = 'b';
        response.complete(http.Response('{}', 200));
        await rejection;
        expect(await store.read(expectedScope: store.scope), isEmpty);
        uid = 'a';
        expect(await store.read(expectedScope: store.scope), isEmpty);
      },
    );
  }
}
