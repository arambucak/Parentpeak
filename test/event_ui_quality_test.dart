import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/participation_service.dart';
import 'package:parentpeak/models/event_participation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:parentpeak/ui/event_edit_sheet.dart';
import 'package:parentpeak/ui/widgets/event_photo.dart';
import 'package:parentpeak/ui/widgets/event_host_identity.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/ui/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UiParticipation extends ParticipationService {
  ParticipationStatus? status;
  bool readFails = false;
  bool joinFails = false;
  bool withdrawFails = false;
  int reads = 0;
  Completer<EventParticipation>? pendingJoin;

  EventParticipation participation(ParticipationStatus value) =>
      EventParticipation(
        id: 'participation',
        eventId: 'event',
        userId: 'debug_demo_user',
        requestedAt: DateTime.now(),
        status: value,
      );

  @override
  Future<EventParticipation?> getParticipationByUserAndEvent({
    required String userId,
    required String eventId,
  }) async {
    reads++;
    if (readFails) throw StateError('private-user-id');
    return status == null ? null : participation(status!);
  }

  @override
  Future<EventParticipation> requestParticipation({
    required String eventId,
    required String userId,
  }) async {
    if (joinFails) throw StateError('private-user-id');
    if (pendingJoin != null) return pendingJoin!.future;
    return participation(status ?? ParticipationStatus.approved);
  }

  @override
  Future<void> withdrawParticipation({
    required String eventId,
    required String userId,
  }) async {
    if (withdrawFails) throw StateError('private-user-id');
    status = null;
  }
}

class _UiBackend extends EventBackendService {
  bool followFails = false;

  @override
  Future<MeetupEvent?> fetchEventById(String id) async => null;

  @override
  Future<bool?> isFollowingSeries({
    required String seriesId,
    required String userId,
  }) async => false;

  @override
  Future<bool> followSeries({
    required String seriesId,
    required String userId,
  }) async {
    if (followFails) throw StateError('private-user-id');
    return true;
  }
}

MeetupEvent _event({
  ParticipationMode mode = ParticipationMode.direct,
  bool series = false,
}) => MeetupEvent(
  id: 'event',
  hosterId: 'real-parent',
  title: 'Family picnic',
  description: 'An afternoon outdoors',
  category: EventCategory.socialGathering,
  ageGroups: AgeGroup.values,
  location: 'City park',
  latitude: 52,
  longitude: 13,
  eventDate: DateTime.now().add(const Duration(days: 2)),
  createdAt: DateTime.now(),
  maxParticipants: 8,
  currentParticipants: 3,
  photoUrl: '',
  participationMode: mode,
  externalUrl: mode == ParticipationMode.interest
      ? 'https://example.org/offer'
      : null,
  seriesId: series ? 'picnic-series' : null,
);

Widget _app(Widget child, {String locale = 'en', double textScale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppLanguages.materialLocalizationsDelegate,
        AppLanguages.widgetsLocalizationsDelegate,
        AppLanguages.cupertinoLocalizationsDelegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    );

Future<void> _openDetail(
  WidgetTester tester,
  _UiParticipation participation, {
  ParticipationMode mode = ParticipationMode.direct,
  _UiBackend? backend,
  bool series = false,
  String locale = 'en',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _app(
      EventDetailScreen(
        event: _event(mode: mode, series: series),
        backendService: backend ?? _UiBackend(),
        participationService: participation,
      ),
      locale: locale,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final originalFactory = AuthService.backendApiClientFactory;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.backendApiClientFactory = () => null;
    await AuthService.instance.debugSeedSessionForTesting();
  });
  tearDown(() {
    AuthService.backendApiClientFactory = originalFactory;
  });

  testWidgets('direct RSVP is confirmed only after the server response', (
    tester,
  ) async {
    final service = _UiParticipation()
      ..pendingJoin = Completer<EventParticipation>();
    await _openDetail(tester, service);
    final join = find.byKey(const Key('event-join'));
    await tester.ensureVisible(join);
    await tester.tap(join);
    await tester.pump();
    expect(find.text('You are registered!'), findsNothing);
    expect(find.byKey(const Key('event-withdraw')), findsNothing);
    service.pendingJoin!.complete(
      service.participation(ParticipationStatus.approved),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-withdraw')), findsOneWidget);
    expect(find.text('Open chat'), findsOneWidget);
  });

  testWidgets('join failure reveals no private error and stays unconfirmed', (
    tester,
  ) async {
    final service = _UiParticipation()..joinFails = true;
    await _openDetail(tester, service);
    await tester.ensureVisible(find.byKey(const Key('event-join')));
    await tester.tap(find.byKey(const Key('event-join')));
    await tester.pumpAndSettle();
    expect(find.text('Not saved. Please try again.'), findsOneWidget);
    expect(find.textContaining('private-user-id'), findsNothing);
    expect(find.text('You are registered!'), findsNothing);
    expect(find.byKey(const Key('event-withdraw')), findsNothing);
  });

  testWidgets('failed status read offers retry rather than a join button', (
    tester,
  ) async {
    final service = _UiParticipation()..readFails = true;
    await _openDetail(tester, service);
    expect(find.byKey(const Key('event-join')), findsNothing);
    service.readFails = false;
    await tester.ensureVisible(find.byKey(const Key('event-status-retry')));
    await tester.tap(find.byKey(const Key('event-status-retry')));
    await tester.pumpAndSettle();
    expect(service.reads, 2);
    expect(find.byKey(const Key('event-join')), findsOneWidget);
  });

  testWidgets('failed withdrawal retains confirmed participation', (
    tester,
  ) async {
    final service = _UiParticipation()
      ..status = ParticipationStatus.approved
      ..withdrawFails = true;
    await _openDetail(tester, service);
    await tester.ensureVisible(find.byKey(const Key('event-withdraw')));
    await tester.tap(find.byKey(const Key('event-withdraw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-withdraw')), findsOneWidget);
    expect(find.byKey(const Key('event-join')), findsNothing);
    expect(find.text('Not saved. Please try again.'), findsOneWidget);
    service.withdrawFails = false;
    ScaffoldMessenger.of(
      tester.element(find.byKey(const Key('event-withdraw'))),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('event-withdraw')));
    await tester.tap(find.byKey(const Key('event-withdraw')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-join')), findsOneWidget);
    expect(find.byKey(const Key('event-withdraw')), findsNothing);
  });

  testWidgets('interest never implies a confirmed place or chat access', (
    tester,
  ) async {
    await _openDetail(
      tester,
      _UiParticipation()..status = ParticipationStatus.interested,
      mode: ParticipationMode.interest,
    );
    expect(find.text('You are registered!'), findsNothing);
    expect(find.text('Places'), findsNothing);
    expect(find.text('Open chat'), findsNothing);
    expect(find.text('You are interested. No place reserved.'), findsOneWidget);
    expect(find.byKey(const Key('event-organizer-link')), findsOneWidget);
  });

  testWidgets('legacy pending does not show a confirmed registration', (
    tester,
  ) async {
    await _openDetail(
      tester,
      _UiParticipation()..status = ParticipationStatus.pending,
      mode: ParticipationMode.legacyApproval,
    );
    expect(find.text('You are registered!'), findsNothing);
    expect(find.text('Open chat'), findsNothing);
    expect(
      find.text('Awaiting host confirmation. No place confirmed yet.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed series follow has visible feedback and remains retryable',
    (tester) async {
      await _openDetail(
        tester,
        _UiParticipation(),
        series: true,
        backend: _UiBackend()..followFails = true,
      );
      await tester.ensureVisible(find.text('Follow offer'));
      await tester.tap(find.text('Follow offer'));
      await tester.pumpAndSettle();
      expect(find.text('Not saved. Please try again.'), findsOneWidget);
      expect(find.text('You now follow this offer.'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Follow offer'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('own actor uses the actual auth name and resolved avatar', (
    tester,
  ) async {
    final own = AuthService.instance.currentUser!;
    String? requestedUserId;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EventHostIdentity(
            userId: own.uid,
            loadProfile: (uid) async {
              requestedUserId = uid;
              return const EventHostProfile(
                name: 'Never substitute this name',
                photoUrl: '/uploads/avatar.jpg',
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(requestedUserId, own.uid);
    expect(find.text(own.displayName), findsOneWidget);
    expect(find.text('Never substitute this name'), findsNothing);
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
    expect(avatar.name, own.displayName);
    expect(avatar.photoUrl, '/uploads/avatar.jpg');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching host clears the previous name and avatar immediately',
    (tester) async {
      final pendingOwn = Completer<EventHostProfile>();
      final own = AuthService.instance.currentUser!;
      final requestedIds = <String>[];
      Future<EventHostProfile> lookup(String uid) {
        requestedIds.add(uid);
        if (uid == own.uid) return pendingOwn.future;
        return Future.value(
          const EventHostProfile(
            name: 'Previous Parent',
            photoUrl: '/uploads/previous.jpg',
          ),
        );
      }

      Widget host(String uid) => _app(
        Scaffold(
          body: EventHostIdentity(userId: uid, loadProfile: lookup),
        ),
      );
      await tester.pumpWidget(host('remote-parent'));
      await tester.pump();
      expect(find.text('Previous Parent'), findsOneWidget);
      await tester.pumpWidget(host(own.uid));
      expect(find.text('Previous Parent'), findsNothing);
      expect(find.text(own.displayName), findsOneWidget);
      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).photoUrl,
        isNull,
      );
      pendingOwn.complete(const EventHostProfile(photoUrl: '/uploads/own.jpg'));
      await tester.pump();
      expect(requestedIds, ['remote-parent', own.uid]);
      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).photoUrl,
        '/uploads/own.jpg',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late previous host response cannot replace the own avatar', (
    tester,
  ) async {
    final pendingRemote = Completer<EventHostProfile>();
    final own = AuthService.instance.currentUser!;
    Future<EventHostProfile> lookup(String uid) => uid == own.uid
        ? Future.value(const EventHostProfile(photoUrl: '/uploads/own.jpg'))
        : pendingRemote.future;
    Widget host(String uid) => _app(
      Scaffold(
        body: EventHostIdentity(userId: uid, loadProfile: lookup),
      ),
    );
    await tester.pumpWidget(host('remote-parent'));
    await tester.pumpWidget(host(own.uid));
    await tester.pump();
    pendingRemote.complete(
      const EventHostProfile(
        name: 'Stale private parent',
        photoUrl: '/uploads/stale.jpg',
      ),
    );
    await tester.pumpAndSettle();
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
    expect(avatar.name, own.displayName);
    expect(avatar.photoUrl, '/uploads/own.jpg');
    expect(find.text('Stale private parent'), findsNothing);
    expect(find.text('remote-parent'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late host lookup after logout is discarded with no new anonymous request',
    (tester) async {
      final pending = Completer<EventHostProfile>();
      var reads = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: EventHostIdentity(
              userId: 'remote-parent',
              loadProfile: (_) {
                reads++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await AuthService.instance.logout();
      pending.complete(const EventHostProfile(name: 'Private remote parent'));
      await tester.pump();
      expect(reads, 1);
      expect(find.text('Private remote parent'), findsNothing);
      expect(
        tester.widget<UserAvatar>(find.byType(UserAvatar)).photoUrl,
        isNull,
      );
    },
  );

  for (final locale in AppLanguages.supported) {
    testWidgets(
      '${locale.code}: detail and edit fit a narrow viewport at large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _openDetail(
          tester,
          _UiParticipation()..status = ParticipationStatus.pending,
          mode: ParticipationMode.legacyApproval,
          locale: locale.code,
          textScale: 1.8,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getRect(find.byIcon(Icons.celebration_outlined))
              .overlaps(
                tester.getRect(
                  find.text(
                    AppStringsManager.allStrings[locale
                        .code]!['event_category_social']!,
                  ),
                ),
              ),
          isFalse,
          reason:
              'The compact photo fallback must not collide with the category label',
        );
        expect(
          find.text(AppStringsManager.allStrings[locale.code]!['event_host']!),
          findsOneWidget,
        );
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: EventEditSheet(
                event: _event(mode: ParticipationMode.legacyApproval),
                onSave: (_) async => throw StateError('offline'),
              ),
            ),
            locale: locale.code,
            textScale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('event-edit-save')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('host lookup is bounded across rebuilds and never renders uid', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.debugSeedSessionForTesting();
    var reads = 0;
    Future<EventHostProfile> lookup(String uid) async {
      reads++;
      return const EventHostProfile(name: 'Actual Parent');
    }

    Widget host() => MaterialApp(
      home: Scaffold(
        body: EventHostIdentity(
          userId: 'external-parent-id',
          loadProfile: lookup,
        ),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pumpWidget(host());
    expect(reads, 1);
    expect(find.text('Actual Parent'), findsOneWidget);
    expect(find.text('external-parent-id'), findsNothing);
    expect(find.byType(UserAvatar), findsOneWidget);
  });

  testWidgets('unknown host and failed lookup do not fabricate a name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventHostIdentity(
            userId: 'private-user-id',
            loadProfile: (_) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('private-user-id'), findsNothing);
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).name, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing event photo uses a compact bounded fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventPhoto(photoUrl: '')),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('event-photo-fallback'))).height,
      80,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('invalid event photo cannot start a network request', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventPhoto(photoUrl: 'file:///private/photo.jpg')),
      ),
    );
    expect(find.byKey(const Key('event-photo-fallback')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('network photo shows loading then compact error fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventPhoto(photoUrl: 'https://example.invalid/event.jpg'),
        ),
      ),
    );
    expect(find.byKey(const Key('event-photo-loading')), findsOneWidget);
    final loadingSize = tester.getSize(
      find.byKey(const Key('event-photo-loading')),
    );
    expect(loadingSize.height, 80);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-photo-fallback')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('event-photo-fallback'))),
      loadingSize,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded network photo keeps the same compact dimensions', (
    tester,
  ) async {
    const url = 'https://example.invalid/loaded-event.jpg';
    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 4),
    );
    final cache = PaintingBinding.instance.imageCache;
    cache.putIfAbsent(
      const NetworkImage(url),
      () =>
          OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
    );
    addTearDown(() {
      cache.clear();
      cache.clearLiveImages();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventPhoto(photoUrl: url)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-photo-loading')), findsNothing);
    expect(find.byKey(const Key('event-photo-fallback')), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.getSize(find.byType(Image)).height, 80);
    expect(tester.takeException(), isNull);
  });
}
