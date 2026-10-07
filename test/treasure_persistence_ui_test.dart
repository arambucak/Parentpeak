import 'dart:async';
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
import 'package:parentpeak/ui/widgets/treasure_handover_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Photo extends XFile {
  _Photo(String path) : super(path);
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);
}

class _Picker extends ImagePicker {
  Completer<List<XFile>>? pending;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => pending != null ? await pending!.future : [_Photo('/fake-one.png'), _Photo('/fake-two.png')];
}

TreasureListing _listing() => TreasureListing(
  id: 'item',
  title: 'Test offer',
  category: 'Vehicles',
  sizeAge: '3 years',
  conditionKey: 'good',
  distanceMeters: 120,
  colorLabel: 'red',
  note: '',
  latitude: 50,
  longitude: 8,
  createdAt: DateTime(2026),
);

class _Backend extends TreasureBackendService {
  bool enabled = true;
  bool createConfirmed = true;
  int creates = 0;
  int reservations = 0;
  int cancellations = 0;
  TreasureListing? createdListing;
  List<TreasureListing>? offers;
  Completer<List<TreasureListing>>? pendingFetch;
  @override
  bool get isEnabled => enabled;
  @override
  Future<TreasureListing?> createTreasure({
    required TreasureListing listing,
    required String userId,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    creates++;
    createdListing = listing;
    return createConfirmed ? listing : null;
  }

  @override
  Future<List<TreasureListing>> fetchTreasures({
    String status = 'available',
    String visibility = 'nearby',
    String? category,
    String? condition,
    int limit = 50,
    int offset = 0,
    double? latitude,
    double? longitude,
    double radiusKm = 25,
  }) async => pendingFetch != null ? await pendingFetch!.future : offers ?? [_listing()];
  @override
  Future<TreasureMineOverview?> fetchMine({required String userId}) async =>
      const TreasureMineOverview(
        offers: [],
        reservedByMe: [
          TreasureHandoverSummary(
            id: 'handover',
            treasureId: 'item',
            status: 'pending',
            location: '',
            treasureTitle: 'Test offer',
          ),
        ],
      );
  @override
  Future<bool> reserveTreasure({
    required String treasureId,
    required String requesterUserId,
    String? preferredSlot,
    String? handoverMode,
    String? message,
  }) async {
    reservations++;
    return true;
  }

  @override
  Future<bool> cancelReservation({
    required String treasureId,
    required String requesterUserId,
  }) async {
    cancellations++;
    return true;
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

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    String language = 'en',
    bool settleAfter = true,
  }) async {
    await tester.runAsync(() async {
      await AuthService.instance.debugSeedSessionForTesting();
      await LocationService.instance.setCoordinates(50, 8, city: 'Test city');
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: screen,
      ),
    );
    if (settleAfter) await settle(tester);
  }

  for (final language in ['de', 'en', 'tr', 'ku']) {
    testWidgets('$language defaults and honest editable note suggestion', (tester) async {
      final strings = AppLocalizations(Locale(language));
      await mount(tester, TreasureUploadScreen(
        listingService: service,
        imagePicker: _Picker(),
      ), language: language);
      final title = find.byWidgetPredicate((widget) =>
          widget is TextField && widget.controller?.text == strings.t('treasureDefaultTitle'));
      await tester.scrollUntilVisible(title, 250, scrollable: find.byType(Scrollable).first);
      await tester.enterText(title, 'My own title');
      final button = find.text(strings.t('treasureInsertNoteSuggestion'));
      await tester.scrollUntilVisible(button, 250, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      final expected = strings.tFormat('treasureNoteSuggestion', {
        'title': 'My own title',
        'sizeAge': strings.t('treasureDefaultSizeAge'),
      });
      await tester.scrollUntilVisible(find.text(expected).first, -200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(expected), findsWidgets);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
      final note = find.byWidgetPredicate((widget) =>
          widget is TextField && widget.controller?.text == expected);
      await tester.ensureVisible(note);
      await tester.pumpAndSettle();
      await tester.enterText(note, 'My private handwritten note');
      await tester.pump();
      expect(find.text('My private handwritten note'), findsWidgets);
      expect(backend.creates, 0);
      expect(uploads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    test('$language handover codes and mode prefix localized; user text preserved', () {
      final strings = AppLocalizations(Locale(language));
      for (final entry in {
        'sunday_morning': 'treasureSlotSunday',
        'monday_evening': 'treasureSlotMonday',
        'tuesday_morning': 'treasureSlotTuesday',
        'front_door_box': 'treasureDropRetterBox',
        'daycare_locker': 'treasureDropKitaLocker',
        'entrance_mailbox': 'treasureDropMailbox',
      }.entries) {
        expect(treasureHandoverLocation(strings, entry.key), strings.t(entry.value));
      }
      expect(treasureHandoverLocation(strings, 'My chosen place'), 'My chosen place');
      expect(treasureHandoverNotes(strings, 'Kurz treffen · Do not translate my text'),
          '${strings.t('treasureHandoverCoffeeMode')} · Do not translate my text');
      expect(treasureHandoverNotes(strings, 'Stiller Tausch'),
          strings.t('treasureHandoverFlyingSwap'));
      expect(treasureHandoverNotes(strings, 'My handwritten note'), 'My handwritten note');
    });
  }

  testWidgets('late gallery response after disposal cannot update state or save photos', (tester) async {
    final picker = _Picker()..pending = Completer<List<XFile>>();
    await mount(tester, TreasureUploadScreen(listingService: service, imagePicker: picker));
    await tester.tap(find.text(l10n.t('treasureChooseFromLibrary')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    picker.pending!.complete([_Photo('/late.png')]);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect((await store.read(expectedScope: store.scope))['draft'], isNull);
  });

  testWidgets('late feed response after disposal stops initialization', (tester) async {
    backend.pendingFetch = Completer<List<TreasureListing>>();
    await mount(tester, TreasureHandoverScreen(listingService: service), settleAfter: false);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    backend.pendingFetch!.complete([_listing()]);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upload photo hit targets are opaque', (tester) async {
    await mount(tester, TreasureUploadScreen(listingService: service, imagePicker: _Picker()));
    await tester.tap(find.text(l10n.t('treasureChooseFromLibrary')));
    await settle(tester);
    final gestures = tester.widgetList<GestureDetector>(
      find.descendant(of: find.byType(TreasureUploadScreen), matching: find.byType(GestureDetector)),
    ).where((widget) => widget.onTap != null);
    expect(gestures.length, greaterThanOrEqualTo(4));
    expect(gestures.every((widget) => widget.behavior == HitTestBehavior.opaque), isTrue);
  });

  Future<void> tapKey(
    WidgetTester tester,
    String key, {
    double delta = 350,
  }) async {
    final text = find.text(l10n.t(key));
    await tester.scrollUntilVisible(
      text,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(text.first);
    await tester.pumpAndSettle();
    await tester.tap(text.first);
    await settle(tester);
  }

  Future<void> photos(
    WidgetTester tester, {
    TreasureDraftImages codec = const TreasureDraftImages(),
  }) async {
    await mount(
      tester,
      TreasureUploadScreen(
        listingService: service,
        imagePicker: _Picker(),
        imageUploadService: uploader,
        draftImages: codec,
      ),
    );
    await tapKey(tester, 'treasureChooseFromLibrary');
  }

  for (final language in ['de', 'en', 'tr', 'ku']) {
    testWidgets(
      'selected book category and 25 km radius reach publication in $language',
      (tester) async {
        final strings = AppLocalizations(Locale(language));
        await mount(
          tester,
          TreasureUploadScreen(
            listingService: service,
            imagePicker: _Picker(),
            imageUploadService: uploader,
          ),
          language: language,
        );
        Future<void> tap(String key) async {
          final text = find.text(strings.t(key));
          await tester.scrollUntilVisible(
            text,
            350,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(text.first);
          await tester.pumpAndSettle();
          await tester.tap(text.first);
          await settle(tester);
        }

        await tap('treasureChooseFromLibrary');
        await tap('treasureCategoryBooks');
        final slider = find.byType(Slider);
        await tester.scrollUntilVisible(
          slider,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(slider, const Offset(600, 0));
        await settle(tester);
        expect(tester.widget<Slider>(slider).value, 25);
        await tap('treasureSaveDraft');
        final draft = await service.loadDraft();
        expect(draft!['categoryKey'], 'books');
        expect(draft['shareRadiusKm'], 25);
        expect(draft.containsKey('distanceMeters'), isFalse);
        await tap('treasurePublishNow');
        expect(backend.createdListing!.category, 'books');
        expect(backend.createdListing!.shareRadiusKm, 25);
        expect(backend.createdListing!.distanceMeters, isNull);
        expect(
          find.text(strings.t('treasure_published_local_failed')),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'old metre draft restores its effective 1 km radius without rewriting on load',
    (tester) async {
      await tester.runAsync(() async {
        await AuthService.instance.debugSeedSessionForTesting();
        await service.saveDraft({
          'title': 'Old draft',
          'distanceMeters': 800,
          'categoryKey': 'books',
        });
      });
      await mount(tester, TreasureUploadScreen(listingService: service));
      final slider = find.byType(Slider);
      await tester.scrollUntilVisible(
        slider,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<Slider>(slider).value, 1);
      expect((await service.loadDraft())!['distanceMeters'], 800);
      expect(
        (await service.loadDraft())!.containsKey('shareRadiusKm'),
        isFalse,
      );
    },
  );

  testWidgets(
    'distance filter and displayed estimate agree, including exact thresholds and unknowns',
    (tester) async {
      TreasureListing at(String id, int? metres) => TreasureListing(
        id: id,
        title: 'Offer $id',
        category: 'books',
        sizeAge: '',
        conditionKey: 'round2',
        distanceMeters: metres,
        colorLabel: '',
        note: '',
        createdAt: DateTime(2026),
      );
      backend.offers = [
        at('501', 501),
        at('500', 500),
        at('251', 251),
        at('250', 250),
        at('unknown', null),
        _listing().copyWith(
          id: 'coarse',
          title: 'Offer coarse',
          distanceMeters: 9000,
        ),
      ];
      await mount(tester, TreasureHandoverScreen(listingService: service));
      await tapKey(tester, 'treasureFilterDistance250');
      expect(find.textContaining('Offer 250'), findsWidgets);
      expect(find.textContaining('Offer 251'), findsNothing);
      expect(find.textContaining('Offer unknown'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Offer coarse'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Offer coarse'), findsWidgets);
      expect(
        find.text(
          l10n.tFormat('treasureDistanceApproximate', {'distance': '0 m'}),
        ),
        findsWidgets,
      );
      await tapKey(tester, 'treasureFilterDistance500', delta: -350);
      await tester.scrollUntilVisible(
        find.textContaining('Offer 500'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Offer 500'), findsWidgets);
      expect(find.textContaining('Offer 501'), findsNothing);
    },
  );

  for (final cleanupFails in [false, true]) {
    testWidgets(
      'partial photo upload is visible; cleanup failure = $cleanupFails',
      (tester) async {
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
        expect(
          find.text(
            l10n.t(
              cleanupFails
                  ? 'treasure_upload_cleanup_failed'
                  : 'treasure_upload_batch_failed',
            ),
          ),
          findsOneWidget,
        );
        expect(backend.creates, 0);
        expect(removed.length, 1);
        expect(find.text(l10n.t('treasureUploadSuccess')), findsNothing);
      },
    );
  }

  for (final failCache in [true, false]) {
    testWidgets(
      'confirmed publish is not presented as failed when ${failCache ? 'cache' : 'draft clear'} fails',
      (tester) async {
        store = TreasureAccountStore(
          persist: (key, value) async {
            final root = jsonDecode(value) as Map<String, dynamic>;
            final accounts = root['accounts'] as Map;
            final data = (accounts.values.first as Map)['data'] as Map;
            if (failCache && data.containsKey(TreasureAccountStore.feedKey)) {
              return false;
            }
            if (!failCache &&
                data.containsKey(TreasureAccountStore.draftKey) &&
                data[TreasureAccountStore.draftKey] == null) {
              return false;
            }
            return (await SharedPreferences.getInstance()).setString(
              key,
              value,
            );
          },
        );
        service.dispose();
        service = TreasureListingService(store: store, backend: backend);
        await photos(tester);
        await tapKey(tester, 'treasurePublishNow');
        expect(backend.creates, 1);
        expect(
          find.text(l10n.t('treasure_published_local_failed')),
          findsWidgets,
        );
        expect(find.text(l10n.t('treasure_publish_uncertain')), findsNothing);
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, l10n.t('treasurePublishNow')),
        );
        expect(button.onPressed, isNull);
        expect(
          removed,
          isEmpty,
          reason: 'Confirmed listing photos must not be deleted',
        );
      },
    );
  }

  testWidgets(
    'uncertain creation warns about uploaded photos and blocks blind duplicate publish',
    (tester) async {
      backend.createConfirmed = false;
      await photos(tester);
      await tapKey(tester, 'treasurePublishNow');
      expect(find.text(l10n.t('treasure_publish_uncertain')), findsWidgets);
      expect(backend.creates, 1);
      expect(
        removed,
        isEmpty,
        reason: 'Timeout might have committed the listing',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.t('treasurePublishNow')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('backend unavailable publishes nothing and uploads no photos', (
    tester,
  ) async {
    backend.enabled = false;
    await photos(tester);
    await tapKey(tester, 'treasurePublishNow');
    expect(find.text(l10n.t('treasure_publish_unavailable')), findsOneWidget);
    expect(uploads, 0);
    expect(backend.creates, 0);
  });

  testWidgets('offline cache uses current coarse position and publication radii', (tester) async {
    backend.enabled = false;
    await tester.runAsync(() async {
      await AuthService.instance.debugSeedSessionForTesting();
      await store.update((data) => data[TreasureAccountStore.feedKey] = [
        _listing().copyWith(id: 'outside', title: 'Outside radius', latitude: 50.02).toMap(),
        _listing().copyWith(id: 'market', title: 'Outside market', latitude: 50.24, shareRadiusKm: 25).toMap(),
        _listing().copyWith(id: 'near', title: 'Near offer').toMap(),
      ], expectedScope: store.scope);
    });
    await mount(tester, TreasureHandoverScreen(listingService: service));
    final near = find.textContaining('Near offer');
    await tester.scrollUntilVisible(near, 350, scrollable: find.byType(Scrollable).first);
    expect(near, findsWidgets);
    expect(find.textContaining('Outside radius'), findsNothing);
    expect(find.textContaining('Outside market'), findsNothing);
    expect(backend.reservations, 0);
  });

  testWidgets('web photo bytes survive actual draft save and screen reopen', (
    tester,
  ) async {
    const codec = TreasureDraftImages(web: true);
    await photos(tester, codec: codec);
    await tapKey(tester, 'treasureSaveDraft');
    expect(find.text(l10n.t('treasureDraftSaved')), findsOneWidget);
    final draft = (await service.loadDraft())!;
    expect(draft.containsKey('imagePaths'), isFalse);
    expect((draft['images'] as List).length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(
      tester,
      TreasureUploadScreen(listingService: service, draftImages: codec),
    );
    expect(find.text(l10n.t('treasureDraftRestored')), findsOneWidget);
    expect((await service.loadDraft())!['images'], draft['images']);
    expect(await codec.decode(draft)!.first.readAsBytes(), [1, 2, 3]);
  });

  testWidgets('failed web draft acknowledgement never displays saved', (
    tester,
  ) async {
    store = TreasureAccountStore(persist: (_, __) async => false);
    service.dispose();
    service = TreasureListingService(store: store, backend: backend);
    await photos(tester, codec: const TreasureDraftImages(web: true));
    await tapKey(tester, 'treasureSaveDraft');
    expect(find.text(l10n.t('treasure_storage_failed')), findsWidgets);
    expect(find.text(l10n.t('treasureDraftSaved')), findsNothing);
    expect(await service.loadDraft(), isNull);
  });

  testWidgets(
    'missing old web photo is visible and does not auto-overwrite the old draft',
    (tester) async {
      await tester.runAsync(
        () => AuthService.instance.debugSeedSessionForTesting(),
      );
      final old = {
        'title': 'Retained draft',
        'imagePaths': ['blob:no-longer-available'],
      };
      await tester.runAsync(() => service.saveDraft(old));
      await mount(
        tester,
        TreasureUploadScreen(
          listingService: service,
          draftImages: const TreasureDraftImages(web: true),
        ),
      );
      expect(
        find.text(l10n.t('treasure_draft_images_missing')),
        findsOneWidget,
      );
      expect(find.text(l10n.t('treasureDraftRestored')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(await service.loadDraft(), old);
    },
  );

  for (final ack in [true, false]) {
    testWidgets(
      'cancel flow mirrors server commit and local marker acknowledgement = $ack',
      (tester) async {
        await tester.runAsync(
          () => AuthService.instance.debugSeedSessionForTesting(),
        );
        await tester.runAsync(
          () => store.update(
            (data) => data[TreasureAccountStore.reservedKey] = ['item'],
            expectedScope: store.scope,
          ),
        );
        if (!ack) {
          store = TreasureAccountStore(persist: (_, __) async => false);
          service.dispose();
          service = TreasureListingService(store: store, backend: backend);
        }
        await mount(
          tester,
          TreasureHandoverScreen(listingService: service, openMyListings: true),
        );
        await tester.tap(find.text(l10n.t('treasureCancelReservation')));
        await settle(tester);
        expect(backend.cancellations, 1);
        expect(await service.loadReservedIds(), ack ? isEmpty : {'item'});
        expect(
          find.text(
            l10n.t(
              ack ? 'treasureHandoverUpdated' : 'treasure_cancel_local_failed',
            ),
          ),
          findsWidgets,
        );
      },
    );
  }

  for (final outcome in [
    'offline',
    'failed local acknowledgement',
    'success',
  ]) {
    testWidgets('reserve flow reflects $outcome', (tester) async {
      final offline = outcome == 'offline';
      final success = outcome == 'success';
      await tester.runAsync(
        () => AuthService.instance.debugSeedSessionForTesting(),
      );
      await tester.runAsync(
        () => store.update(
          (data) => data[TreasureAccountStore.feedKey] = [_listing().toMap()],
          expectedScope: store.scope,
        ),
      );
      if (offline) {
        backend.enabled = false;
      } else if (!success) {
        store = TreasureAccountStore(
          persist: (key, value) async {
            final root = jsonDecode(value) as Map<String, dynamic>;
            final data =
                ((root['accounts'] as Map).values.first as Map)['data'] as Map;
            if ((data[TreasureAccountStore.reservedKey] as List?)?.contains(
                  'item',
                ) ??
                false) {
              return false;
            }
            return (await SharedPreferences.getInstance()).setString(
              key,
              value,
            );
          },
        );
        service.dispose();
        service = TreasureListingService(store: store, backend: backend);
      }
      await mount(tester, TreasureHandoverScreen(listingService: service));
      final title = find.textContaining('Test offer');
      await tester.scrollUntilVisible(
        title,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(title.first);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.t('treasureSelectForHandover')),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(l10n.t('treasureSelectForHandover')));
      await settle(tester);
      await tapKey(tester, 'treasureSlotSunday', delta: -350);
      await tester.tap(find.text(l10n.t('treasureReserveCoffeeMode')));
      await settle(tester);
      if (success) {
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Test offer'),
          ),
          findsOneWidget,
        );
      } else {
        expect(
          find.text(
            l10n.t(
              offline
                  ? 'treasure_reservation_offline'
                  : 'treasure_reserve_local_failed',
            ),
          ),
          findsWidgets,
        );
      }
      expect(await service.loadReservedIds(), success ? {'item'} : isEmpty);
      expect(backend.reservations, offline ? 0 : 1);
    });
  }
}
