import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/ui/treasure_handover_screen.dart';
import 'package:parentpeak/ui/treasure_upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Offline extends TreasureBackendService {
  @override
  bool get isEnabled => false;
  @override
  Future<TreasureMineOverview?> fetchMine({required String userId}) async =>
      const TreasureMineOverview(offers: [], reservedByMe: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TreasureAccountStore store;
  late TreasureListingService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = TreasureAccountStore();
    service = TreasureListingService(store: store, backend: _Offline());
  });
  tearDown(() async {
    service.dispose();
    await AuthService.instance.logout();
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.runAsync(
      () => AuthService.instance.debugSeedSessionForTesting(),
    );
  }

  Future<void> open(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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
    await tester.pumpAndSettle();
  }

  testWidgets(
    'upload refuses claim, explicitly adopts draft, and tears down on logout',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        TreasureAccountStore.draftKey: jsonEncode({
          'title': 'Private legacy title',
        }),
      });
      await signIn(tester);
      await open(tester, TreasureUploadScreen(listingService: service));
      expect(find.text('Private legacy title'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      await tester.tap(find.text('Confirm ownership'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs.containsKey(TreasureAccountStore.storageKey), isFalse);
      await tester.tap(find.text('Confirm ownership'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm ownership').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Private legacy title'), findsOneWidget);
      expect(find.text('Confirm ownership'), findsNothing);
      final scope = store.scope;
      final privateControllers = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!)
          .toList();
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.text('Private legacy title'), findsNothing);
      final currentControllers = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!)
          .toList();
      expect(currentControllers.any(privateControllers.contains), isFalse);
      expect(await store.read(expectedScope: store.scope), isEmpty);
      expect(
        jsonDecode(
          prefs.getString(TreasureAccountStore.storageKey)!,
        )['accounts'][scope]['data'][TreasureAccountStore.draftKey]['title'],
        'Private legacy title',
      );
      expect(
        prefs.getString(TreasureAccountStore.draftKey),
        jsonEncode({'title': 'Private legacy title'}),
      );
    },
  );

  testWidgets('logout closes ownership gate without claim', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      TreasureAccountStore.draftKey: jsonEncode({'title': 'Unclaimed'}),
    });
    await signIn(tester);
    await open(tester, TreasureUploadScreen(listingService: service));
    await tester.tap(find.text('Confirm ownership'));
    await tester.pump();
    await tester.runAsync(() => AuthService.instance.logout());
    await tester.pumpAndSettle();
    expect(find.text('Pending private edit'), findsNothing);
    expect(
      find
          .text('Confirm ownership')
          .evaluate()
          .where((element) => element.widget is FilledButton),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(await store.read(expectedScope: store.scope), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(TreasureAccountStore.storageKey);
    if (raw != null) expect(jsonDecode(raw)['legacyOwner'], isNull);
  });

  testWidgets('failed claim is visible and never restores draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      TreasureAccountStore.draftKey: jsonEncode({'title': 'Unclaimed private'}),
    });
    await signIn(tester);
    final failed = TreasureAccountStore(persist: (_, __) async => false);
    final failedService = TreasureListingService(
      store: failed,
      backend: _Offline(),
    );
    addTearDown(failedService.dispose);
    await open(tester, TreasureUploadScreen(listingService: failedService));
    await tester.tap(find.text('Confirm ownership'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm ownership').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(
      find.text('Market data could not be loaded or saved. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Unclaimed private'), findsNothing);
    expect(
      await failed.hasUnassignedLegacy(expectedScope: failed.scope),
      isTrue,
    );
  });

  testWidgets(
    'handover feed, reservations, flags and detail vanish on logout',
    (tester) async {
      await signIn(tester);
      final listing = TreasureListing(
        id: 'private',
        title: 'Account A private offer',
        category: 'Vehicles',
        sizeAge: '',
        conditionKey: 'good',
        distanceMeters: 120,
        colorLabel: '',
        note: 'Account A private note',
        createdAt: DateTime(2026),
      );
      await tester.runAsync(() => store.update(
        (data) => data.addAll({
          TreasureAccountStore.feedKey: [listing.toMap()],
          TreasureAccountStore.reservedKey: ['private'],
          TreasureAccountStore.blockedKey: ['blocked'],
          TreasureAccountStore.reportedKey: ['reported'],
        }),
        expectedScope: store.scope,
      ));
      await open(tester, TreasureHandoverScreen(listingService: service));
      final title = find.textContaining('Account A private offer');
      await tester.scrollUntilVisible(title, 350,
        scrollable: find.byType(Scrollable).first);
      await tester.tap(title.first);
      await tester.pumpAndSettle();
      expect(find.text('Account A private offer'), findsWidgets);
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.text('Account A private offer'), findsNothing);
      expect(find.text('Account A private note'), findsNothing);
      expect(await service.loadListings(), isEmpty);
      expect(await service.loadReservedIds(), isEmpty);
      expect(await store.read(expectedScope: store.scope), isEmpty);
    },
  );

  testWidgets(
    'handover explicitly claims safety markers without publishing global cache',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        TreasureAccountStore.reservedKey: ['reserved'],
        TreasureAccountStore.blockedKey: ['blocked'],
        TreasureAccountStore.reportedKey: ['reported'],
        TreasureAccountStore.feedKey: '[{"id":"not-owned"}]',
      });
      await signIn(tester);
      await open(tester, TreasureHandoverScreen(listingService: service));
      await tester.tap(find.text('Confirm ownership'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm ownership').last);
      await tester.pumpAndSettle();
      final data = await store.read(expectedScope: store.scope);
      expect(data[TreasureAccountStore.reservedKey], ['reserved']);
      expect(data[TreasureAccountStore.blockedKey], ['blocked']);
      expect(data[TreasureAccountStore.reportedKey], ['reported']);
      expect(data.containsKey(TreasureAccountStore.feedKey), isFalse);
      expect(await service.loadListings(), isEmpty);
    },
  );

  testWidgets('broken storage is visible even with an empty feed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      TreasureAccountStore.storageKey: '{',
    });
    await open(tester, TreasureHandoverScreen(listingService: service));
    expect(
      find.text('Market data could not be loaded or saved. Please try again.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout cancels pending draft autosave instead of writing into guest', (tester) async {
    await signIn(tester);
    final owner = store.scope;
    await open(tester, TreasureUploadScreen(listingService: service));
    final title = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.controller?.text == 'Red balance bike');
    await tester.scrollUntilVisible(title, 250,
      scrollable: find.byType(Scrollable).first);
    await tester.enterText(title, 'Pending account-only edit');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => AuthService.instance.logout());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Pending account-only edit'), findsNothing);
    expect(await store.read(expectedScope: store.scope), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(TreasureAccountStore.storageKey);
    if (raw != null) {
      expect((jsonDecode(raw)['accounts'] as Map)[owner], isNull);
    }
  });
}
