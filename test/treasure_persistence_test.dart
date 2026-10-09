import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/logic/treasure_draft_images.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/services/image_upload_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend extends TreasureBackendService {
  bool enabled = true;
  bool acknowledged = true;
  int calls = 0;
  @override
  bool get isEnabled => enabled;
  @override
  Future<bool> reserveTreasure({
    required String treasureId,
    required String requesterUserId,
    String? preferredSlot,
    String? handoverMode,
    String? message,
  }) async {
    calls++;
    return acknowledged;
  }

  @override
  Future<bool> cancelReservation({
    required String treasureId,
    required String requesterUserId,
  }) async {
    calls++;
    return acknowledged;
  }

  @override
  Future<TreasureListing?> createTreasure({
    required TreasureListing listing,
    required String userId,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    return acknowledged ? listing : null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TreasureAccountStore store;
  late _Backend backend;
  late TreasureListingService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = TreasureAccountStore(userIdProvider: () => 'a');
    backend = _Backend();
    service = TreasureListingService(store: store, backend: backend);
  });
  tearDown(() => service.dispose());

  test('image content types retain native and browser image formats', () {
    expect(ImageUploadService.contentTypeFor('CAMERA.HEIC'), 'image/heic');
    expect(ImageUploadService.contentTypeFor('image.heif'), 'image/heif');
    expect(ImageUploadService.contentTypeFor('image.avif'), 'image/avif');
    expect(ImageUploadService.contentTypeFor('image.tiff'), 'image/tiff');
    expect(ImageUploadService.contentTypeFor('image.jpeg'), 'image/jpeg');
  });

  test(
    'disabled backend never creates an offline reservation or marker',
    () async {
      backend.enabled = false;
      expect(await service.reserveListing(listingId: 'item'), isFalse);
      expect(service.lastSyncError, 'treasure_reservation_offline');
      expect(backend.calls, 0);
      expect(await service.loadReservedIds(), isEmpty);
      expect(await store.read(expectedScope: store.scope), isEmpty);
    },
  );

  test(
    'HTTP first success and alreadyReserved retry keep one persistent marker',
    () async {
      var calls = 0;
      final remote = TreasureBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'test',
          httpClient: MockClient((request) async {
            calls++;
            return http.Response(
              jsonEncode({
                'handover': {'id': 'same', 'status': 'reserved'},
                'alreadyReserved': calls > 1,
              }),
              calls == 1 ? 201 : 200,
            );
          }),
        ),
      );
      final actual = TreasureListingService(store: store, backend: remote);
      addTearDown(actual.dispose);
      expect(await actual.reserveListing(listingId: 'item'), isTrue);
      expect(await actual.reserveListing(listingId: 'item'), isTrue);
      expect(calls, 2);
      final data = await store.read(expectedScope: store.scope);
      expect(data[TreasureAccountStore.reservedKey], ['item']);
    },
  );

  test('failed remote reservation does not acquire a local marker', () async {
    backend.acknowledged = false;
    expect(await service.reserveListing(listingId: 'item'), isFalse);
    expect(await service.loadReservedIds(), isEmpty);
  });

  test('HTTP cancellation error preserves existing reservation marker', () async {
    final remote = TreasureBackendService(apiClient: BackendApiClient(
      baseUrl: 'https://example.invalid',
      authToken: 'test',
      httpClient: MockClient((request) async => request.url.path.endsWith('/cancel-reservation')
          ? http.Response('{"error":"Status write failed"}', 500)
          : http.Response('{"handover":{"id":"saved"}}', 201)),
    ));
    final actual = TreasureListingService(store: store, backend: remote);
    addTearDown(actual.dispose);
    expect(await actual.reserveListing(listingId: 'item'), isTrue);
    expect(await actual.cancelReservation(listingId: 'item'), isFalse);
    expect(await actual.loadReservedIds(), {'item'});
    expect(actual.lastSyncError, 'treasureNetworkError');
  });

  test('reservation requires both server and local acknowledgement', () async {
    expect(await service.reserveListing(listingId: 'item'), isTrue);
    final reopened = TreasureListingService(store: store, backend: backend);
    addTearDown(reopened.dispose);
    expect(await reopened.loadReservedIds(), {'item'});
    final failed = TreasureListingService(
      store: TreasureAccountStore(
        userIdProvider: () => 'a',
        persist: (_, __) async => false,
      ),
      backend: backend,
    );
    addTearDown(failed.dispose);
    await expectLater(
      failed.reserveListing(listingId: 'another'),
      throwsA(
        isA<TreasureRemoteCommitException>().having(
          (e) => e.action,
          'action',
          'reserve',
        ),
      ),
    );
    expect(await service.loadReservedIds(), {'item'});
  });

  test(
    'successful cancellation removes only the target marker durably',
    () async {
      await service.reserveListing(listingId: 'one');
      await service.reserveListing(listingId: 'two');
      expect(await service.cancelReservation(listingId: 'one'), isTrue);
      final reopened = TreasureListingService(store: store, backend: backend);
      addTearDown(reopened.dispose);
      expect(await reopened.loadReservedIds(), {'two'});
    },
  );

  test(
    'failed cancellation retains markers; local failure reports server commit',
    () async {
      await service.reserveListing(listingId: 'item');
      backend.acknowledged = false;
      expect(await service.cancelReservation(listingId: 'item'), isFalse);
      expect(await service.loadReservedIds(), {'item'});
      backend.acknowledged = true;
      final failed = TreasureListingService(
        store: TreasureAccountStore(
          userIdProvider: () => 'a',
          persist: (_, __) async => throw StateError('disk full'),
        ),
        backend: backend,
      );
      addTearDown(failed.dispose);
      await expectLater(
        failed.cancelReservation(listingId: 'item'),
        throwsA(
          isA<TreasureRemoteCommitException>().having(
            (e) => e.action,
            'action',
            'cancel',
          ),
        ),
      );
      expect(await service.loadReservedIds(), {'item'});
    },
  );

  test(
    'created listing is retained in the error if local cache acknowledgement fails',
    () async {
      final listing = TreasureListing(
        id: 'created',
        title: 'Created',
        category: 'other',
        sizeAge: '',
        conditionKey: 'good',
        distanceMeters: 120,
        colorLabel: '',
        note: '',
        latitude: 50,
        longitude: 8,
        createdAt: DateTime(2026),
      );
      final failed = TreasureListingService(
        store: TreasureAccountStore(
          userIdProvider: () => 'a',
          persist: (_, __) async => false,
        ),
        backend: backend,
      );
      addTearDown(failed.dispose);
      await expectLater(
        failed.createListing(listing),
        throwsA(
          isA<TreasureRemoteCommitException>()
              .having((e) => e.action, 'action', 'create')
              .having((e) => e.listing?.id, 'confirmed listing', 'created'),
        ),
      );
      expect(backend.calls, 1);
      expect(await store.read(expectedScope: store.scope), isEmpty);
    },
  );

  test(
    'web draft persists exact bytes and order without temporary paths across reopen',
    () async {
      const codec = TreasureDraftImages(web: true);
      final photos = [
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'first.png',
          mimeType: 'image/png',
        ),
        XFile.fromData(
          Uint8List.fromList([4, 5, 6]),
          name: 'second.jpg',
          mimeType: 'image/jpeg',
        ),
      ];
      final payload = await codec.encode(photos);
      expect(payload.containsKey('imagePaths'), isFalse);
      await service.saveDraft({'title': 'Local photo draft', ...payload});
      final reopened = TreasureListingService(store: store, backend: backend);
      addTearDown(reopened.dispose);
      final decoded = codec.decode((await reopened.loadDraft())!)!;
      expect(await decoded[0].readAsBytes(), [1, 2, 3]);
      expect(await decoded[1].readAsBytes(), [4, 5, 6]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(TreasureAccountStore.storageKey),
        contains(base64Encode([1, 2, 3])),
      );
      expect(backend.calls, 0);
    },
  );

  test(
    'native drafts retain path contract; empty web photos and corrupt bytes fail explicitly',
    () async {
      expect(
        await const TreasureDraftImages(
          web: false,
        ).encode([XFile('/local/photo.png')]),
        {
          'imagePath': '/local/photo.png',
          'imagePaths': ['/local/photo.png'],
        },
      );
      await expectLater(
        const TreasureDraftImages(
          web: true,
        ).encode([XFile.fromData(Uint8List(0), name: 'empty.png')]),
        throwsFormatException,
      );
      for (final images in [
        [
          {'name': 'x', 'mimeType': '', 'base64': '%%%'},
        ],
        [
          {'name': 'x', 'mimeType': '', 'base64': ''},
        ],
        [
          {'name': 1, 'mimeType': '', 'base64': 'AQ=='},
        ],
      ]) {
        await expectLater(
          service.saveDraft({'images': images}),
          throwsFormatException,
        );
      }
      expect(await service.loadDraft(), isNull);
    },
  );

  test('photo draft quota failure keeps the last acknowledged draft', () async {
    await service.saveDraft({'title': 'Prior draft'});
    final failed = TreasureListingService(
      store: TreasureAccountStore(
        userIdProvider: () => 'a',
        persist: (_, __) async => throw StateError('Quota exceeded'),
      ),
      backend: backend,
    );
    addTearDown(failed.dispose);
    await expectLater(
      failed.saveDraft({
        'title': 'Not saved',
        ...await const TreasureDraftImages(web: true).encode([
          XFile.fromData(Uint8List.fromList([1, 2]), name: 'x.png'),
        ]),
      }),
      throwsStateError,
    );
    expect(await service.loadDraft(), {'title': 'Prior draft'});
  });

  test(
    'batch upload returns every URL in order and no cleanup on success',
    () async {
      final removed = <String>[];
      final upload = ImageUploadService(
        userIdProvider: () => 'owner-a',
        upload: (file, _) async => 'https://example.invalid/${file.path}',
        remove: (url) async => removed.add(url),
      );
      expect(await upload.uploadImages([XFile('one.png'), XFile('two.png')]), [
        'https://example.invalid/one.png',
        'https://example.invalid/two.png',
      ]);
      expect(removed, isEmpty);
    },
  );

  test(
    'partial upload rolls back successes and never returns a partial URL list',
    () async {
      final removed = <String>[];
      var calls = 0;
      final upload = ImageUploadService(
        userIdProvider: () => 'owner-a',
        upload: (_, __) async {
          if (++calls == 2) throw StateError('network unavailable');
          return 'uploaded-one';
        },
        remove: (url) async => removed.add(url),
      );
      await expectLater(
        upload.uploadImages([
          XFile('one.png'),
          XFile('two.png'),
          XFile('three.png'),
        ]),
        throwsA(
          isA<ImageBatchUploadException>().having(
            (e) => e.remainingUploads,
            'remaining',
            0,
          ),
        ),
      );
      expect(removed, ['uploaded-one']);
      expect(calls, 2);
    },
  );

  test(
    'cleanup failure is explicit and each known upload still gets a cleanup attempt',
    () async {
      final removed = <String>[];
      var calls = 0;
      final upload = ImageUploadService(
        userIdProvider: () => 'owner-a',
        upload: (_, __) async {
          if (++calls == 3) throw StateError('failed third photo');
          return 'uploaded-$calls';
        },
        remove: (url) async {
          removed.add(url);
          if (url == 'uploaded-1') throw StateError('delete denied');
        },
      );
      await expectLater(
        upload.uploadImages([XFile('1.png'), XFile('2.png'), XFile('3.png')]),
        throwsA(
          isA<ImageBatchUploadException>().having(
            (e) => e.remainingUploads,
            'remaining',
            1,
          ),
        ),
      );
      expect(removed, ['uploaded-1', 'uploaded-2']);
    },
  );

  test(
    'account change during upload stops the batch and cleans completed photos',
    () async {
      var current = true;
      final removed = <String>[];
      final upload = ImageUploadService(
        userIdProvider: () => 'owner-a',
        upload: (_, __) async {
          current = false;
          return 'old-account-photo';
        },
        remove: (url) async => removed.add(url),
      );
      await expectLater(
        upload.uploadImages(
          [XFile('one.png'), XFile('two.png')],
          requireCurrent: () {
            if (!current) throw const TreasureAccountChanged();
          },
        ),
        throwsA(isA<ImageBatchUploadException>()),
      );
      expect(removed, ['old-account-photo']);
    },
  );
}
