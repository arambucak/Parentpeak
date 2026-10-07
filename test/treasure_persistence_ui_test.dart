import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/logic/treasure_draft_images.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/services/image_upload_service.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:parentpeak/ui/treasure_handover_screen.dart';
import 'package:parentpeak/ui/treasure_upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Photo extends XFile {
  _Photo(String path) : super(path);
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);
}

class _Picker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth, double? maxHeight, int? imageQuality,
    int? limit, bool requestFullMetadata = true,
  }) async => [_Photo('/fake-one.png'), _Photo('/fake-two.png')];
}

TreasureListing _listing() => TreasureListing(
  id: 'item', title: 'Test offer', category: 'Vehicles', sizeAge: '3 years',
  conditionKey: 'good', distanceMeters: 120, colorLabel: 'red', note: '',
  latitude: 50, longitude: 8, createdAt: DateTime(2026),
);

class _Backend extends TreasureBackendService {
  bool enabled = true;
  bool createConfirmed = true;
  int creates = 0;
  int reservations = 0;
  int cancellations = 0;
  @override
  bool get isEnabled => enabled;
  @override
  Future<TreasureListing?> createTreasure({
    required TreasureListing listing, required String userId, required String location,
    required double latitude, required double longitude,
  }) async { creates++; return createConfirmed ? listing : null; }
  @override
  Future<List<TreasureListing>> fetchTreasures({
    String status = 'available', String visibility = 'nearby', String? category,
    String? condition, int limit = 50, int offset = 0,
    double? latitude, double? longitude, double radiusKm = 25,
  }) async => [_listing()];
  @override
  Future<TreasureMineOverview?> fetchMine({required String userId}) async =>
      const TreasureMineOverview(offers: [], reservedByMe: [
        TreasureHandoverSummary(id: 'handover', treasureId: 'item',
          status: 'pending', location: '', treasureTitle: 'Test offer'),
      ]);
  @override
  Future<bool> reserveTreasure({
    required String treasureId, required String requesterUserId,
    String? preferredSlot, String? handoverMode, String? message,
  }) async { reservations++; return true; }
  @override
  Future<bool> cancelReservation({required String treasureId, required String requesterUserId}) async {
    cancellations++; return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizations(const Locale('en'));
  late _Backend backend;
  late TreasureAccountStore store;
  late TreasureListingService service;
  late List<String> removed;
  late int uploads;
  late ImageUploadService uploader;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _Backend();
    store = TreasureAccountStore();
    service = TreasureListingService(store: store, backend: backend);
    removed = [];
    uploads = 0;
    uploader = ImageUploadService(
      upload: (_, __) async => 'https://example.invalid/${++uploads}.png',
      remove: (url) async => removed.add(url),
    );
  });
  tearDown(() async {
    service.dispose();
    await AuthService.instance.logout();
    await LocationService.instance.clear();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.runAsync(() async {
      await AuthService.instance.debugSeedSessionForTesting();
      await LocationService.instance.setCoordinates(50, 8, city: 'Test city');
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'), supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate, AppLanguages.materialLocalizationsDelegate,
        AppLanguages.widgetsLocalizationsDelegate, AppLanguages.cupertinoLocalizationsDelegate,
      ], home: screen,
    ));
    await settle(tester);
  }
  Future<void> tapKey(WidgetTester tester, String key, {double delta = 350}) async {
    final text = find.text(l10n.t(key));
    await tester.scrollUntilVisible(text, delta, scrollable: find.byType(Scrollable).first);
    await tester.tap(text.first);
    await settle(tester);
  }
  Future<void> photos(WidgetTester tester, {TreasureDraftImages codec = const TreasureDraftImages()}) async {
    await mount(tester, TreasureUploadScreen(listingService: service, imagePicker: _Picker(),
      imageUploadService: uploader, draftImages: codec));
    await tapKey(tester, 'treasureChooseFromLibrary');
  }

  for (final cleanupFails in [false, true]) {
    testWidgets('partial photo upload is visible; cleanup failure = $cleanupFails', (tester) async {
      uploader = ImageUploadService(
        upload: (_, __) async {
          if (++uploads == 2) throw StateError('second image failed');
          return 'https://example.invalid/one.png';
        },
        remove: (url) async {
          removed.add(url);
          if (cleanupFails) throw StateError('cleanup denied');
        },
      );
      await photos(tester);
      await tapKey(tester, 'treasurePublishNow');
      expect(find.text(l10n.t(cleanupFails ? 'treasure_upload_cleanup_failed' : 'treasure_upload_batch_failed')), findsOneWidget);
      expect(backend.creates, 0);
      expect(removed.length, 1);
      expect(find.text(l10n.t('treasureUploadSuccess')), findsNothing);
    });
  }

  for (final failCache in [true, false]) {
    testWidgets('confirmed publish is not presented as failed when ${failCache ? 'cache' : 'draft clear'} fails', (tester) async {
      store = TreasureAccountStore(persist: (key, value) async {
        final root = jsonDecode(value) as Map<String, dynamic>;
        final accounts = root['accounts'] as Map;
        final data = (accounts.values.first as Map)['data'] as Map;
        if (failCache && data.containsKey(TreasureAccountStore.feedKey)) return false;
        if (!failCache && data.containsKey(TreasureAccountStore.draftKey) && data[TreasureAccountStore.draftKey] == null) return false;
        return (await SharedPreferences.getInstance()).setString(key, value);
      });
      service.dispose();
      service = TreasureListingService(store: store, backend: backend);
      await photos(tester);
      await tapKey(tester, 'treasurePublishNow');
      expect(backend.creates, 1);
      expect(find.text(l10n.t('treasure_published_local_failed')), findsWidgets);
      expect(find.text(l10n.t('treasure_publish_uncertain')), findsNothing);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, l10n.t('treasurePublishNow')));
      expect(button.onPressed, isNull);
      expect(removed, isEmpty, reason: 'Confirmed listing photos must not be deleted');
    });
  }

  testWidgets('uncertain creation warns about uploaded photos and blocks blind duplicate publish', (tester) async {
    backend.createConfirmed = false;
    await photos(tester);
    await tapKey(tester, 'treasurePublishNow');
    expect(find.text(l10n.t('treasure_publish_uncertain')), findsWidgets);
    expect(backend.creates, 1);
    expect(removed, isEmpty, reason: 'Timeout might have committed the listing');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, l10n.t('treasurePublishNow'))).onPressed, isNull);
  });

  testWidgets('backend unavailable publishes nothing and uploads no photos', (tester) async {
    backend.enabled = false;
    await photos(tester);
    await tapKey(tester, 'treasurePublishNow');
    expect(find.text(l10n.t('treasure_publish_unavailable')), findsOneWidget);
    expect(uploads, 0);
    expect(backend.creates, 0);
  });

  testWidgets('web photo bytes survive actual draft save and screen reopen', (tester) async {
    const codec = TreasureDraftImages(web: true);
    await photos(tester, codec: codec);
    await tapKey(tester, 'treasureSaveDraft');
    expect(find.text(l10n.t('treasureDraftSaved')), findsOneWidget);
    final draft = (await service.loadDraft())!;
    expect(draft.containsKey('imagePaths'), isFalse);
    expect((draft['images'] as List).length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, TreasureUploadScreen(listingService: service, draftImages: codec));
    expect(find.text(l10n.t('treasureDraftRestored')), findsOneWidget);
    expect((await service.loadDraft())!['images'], draft['images']);
    expect(await codec.decode(draft)!.first.readAsBytes(), [1, 2, 3]);
  });

  testWidgets('failed web draft acknowledgement never displays saved', (tester) async {
    store = TreasureAccountStore(persist: (_, __) async => false);
    service.dispose();
    service = TreasureListingService(store: store, backend: backend);
    await photos(tester, codec: const TreasureDraftImages(web: true));
    await tapKey(tester, 'treasureSaveDraft');
    expect(find.text(l10n.t('treasure_storage_failed')), findsWidgets);
    expect(find.text(l10n.t('treasureDraftSaved')), findsNothing);
    expect(await service.loadDraft(), isNull);
  });

  testWidgets('missing old web photo is visible and does not auto-overwrite the old draft', (tester) async {
    await tester.runAsync(() => AuthService.instance.debugSeedSessionForTesting());
    final old = {'title': 'Retained draft', 'imagePaths': ['blob:no-longer-available']};
    await tester.runAsync(() => service.saveDraft(old));
    await mount(tester, TreasureUploadScreen(listingService: service, draftImages: const TreasureDraftImages(web: true)));
    expect(find.text(l10n.t('treasure_draft_images_missing')), findsOneWidget);
    expect(find.text(l10n.t('treasureDraftRestored')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(await service.loadDraft(), old);
  });

  for (final ack in [true, false]) {
    testWidgets('cancel flow mirrors server commit and local marker acknowledgement = $ack', (tester) async {
      await tester.runAsync(() => AuthService.instance.debugSeedSessionForTesting());
      await tester.runAsync(() => store.update((data) => data[TreasureAccountStore.reservedKey] = ['item'],
        expectedScope: store.scope));
      if (!ack) {
        store = TreasureAccountStore(persist: (_, __) async => false);
        service.dispose();
        service = TreasureListingService(store: store, backend: backend);
      }
      await mount(tester, TreasureHandoverScreen(listingService: service, openMyListings: true));
      await tester.tap(find.text(l10n.t('treasureCancelReservation')));
      await settle(tester);
      expect(backend.cancellations, 1);
      expect(await service.loadReservedIds(), ack ? isEmpty : {'item'});
      expect(find.text(l10n.t(ack ? 'treasureHandoverUpdated' : 'treasure_cancel_local_failed')), findsWidgets);
    });
  }

  for (final outcome in ['offline', 'failed local acknowledgement', 'success']) {
    testWidgets('reserve flow reflects $outcome', (tester) async {
      final offline = outcome == 'offline';
      final success = outcome == 'success';
      await tester.runAsync(() => AuthService.instance.debugSeedSessionForTesting());
      await tester.runAsync(() => store.update((data) =>
        data[TreasureAccountStore.feedKey] = [_listing().toMap()], expectedScope: store.scope));
      if (offline) {
        backend.enabled = false;
      } else if (!success) {
        store = TreasureAccountStore(persist: (key, value) async {
          final root = jsonDecode(value) as Map<String, dynamic>;
          final data = ((root['accounts'] as Map).values.first as Map)['data'] as Map;
          if ((data[TreasureAccountStore.reservedKey] as List?)?.contains('item') ?? false) return false;
          return (await SharedPreferences.getInstance()).setString(key, value);
        });
        service.dispose();
        service = TreasureListingService(store: store, backend: backend);
      }
      await mount(tester, TreasureHandoverScreen(listingService: service));
      final title = find.textContaining('Test offer');
      await tester.scrollUntilVisible(title, 350, scrollable: find.byType(Scrollable).first);
      await tester.tap(title.first);
      await settle(tester);
      await tester.scrollUntilVisible(find.text(l10n.t('treasureSelectForHandover')), 350,
        scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text(l10n.t('treasureSelectForHandover')));
      await settle(tester);
      await tapKey(tester, 'treasureSlotSunday', delta: -350);
      await tester.tap(find.text(l10n.t('treasureReserveCoffeeMode')));
      await settle(tester);
      if (success) {
        expect(find.descendant(of: find.byType(SnackBar),
          matching: find.textContaining('Test offer')), findsOneWidget);
      } else {
        expect(find.text(l10n.t(offline ? 'treasure_reservation_offline' : 'treasure_reserve_local_failed')), findsWidgets);
      }
      expect(await service.loadReservedIds(), success ? {'item'} : isEmpty);
      expect(backend.reservations, offline ? 0 : 1);
    });
  }
}
