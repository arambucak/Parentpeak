import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixture {
  _Fixture({ParticipationMode mode = ParticipationMode.direct,
      String? url, EventStatus eventStatus = EventStatus.active, int count = 0}) {
    event = MeetupEvent(id: 'mode-event', hosterId: 'another-parent',
      title: 'Playground afternoon', description: 'Meet at the playground',
      category: EventCategory.outdoor, ageGroups: const [], location: 'City park',
      latitude: 52, longitude: 13, eventDate: DateTime(2099, 1, 1, 10),
      createdAt: DateTime(2026), maxParticipants: 3, currentParticipants: count,
      photoUrl: '', participationMode: mode, externalUrl: url, status: eventStatus);
    confirmed = count;
    backend = EventBackendService(apiClient: BackendApiClient(
      baseUrl: 'http://localhost:3000', authToken: 'test-only',
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/events/participations') {
          if (loadFailure) return http.Response('{}', 503);
          return http.Response(jsonEncode({'items': status == null ? [] : [participation()]}), 200);
        }
        if (request.method == 'POST') {
          writes++;
          if (writeFailure) return http.Response('{"error":"full"}', 409);
          if (pendingWrite != null) return pendingWrite!.future;
          return joinResponse();
        }
        if (request.method == 'PUT') {
          withdrawals++;
          if (withdrawFailure) return http.Response('{}', 503);
          if (status == 'approved') confirmed--;
          status = null;
          return http.Response('{"success":true,"item":null}', 200);
        }
        return http.Response(jsonEncode({'event': {...event.toJson(), 'currentParticipants': confirmed}}), 200);
      }),
    ));
  }
  late final MeetupEvent event;
  late final EventBackendService backend;
  String? status;
  int confirmed = 0;
  int writes = 0;
  int withdrawals = 0;
  bool loadFailure = false;
  bool writeFailure = false;
  bool withdrawFailure = false;
  Completer<http.Response>? pendingWrite;
  final opened = <Uri>[];

  Map<String, dynamic> participation() => {
    'id': 'participation', 'eventId': event.id, 'userId': 'debug_demo_user',
    'requestedAt': '2026-10-02T12:00:00Z', 'status': status,
  };
  http.Response joinResponse() {
    status ??= switch (event.participationMode) {
      ParticipationMode.direct => 'approved',
      ParticipationMode.interest => 'interested',
      ParticipationMode.legacyApproval => 'pending',
    };
    if (status == 'approved') confirmed = 1;
    return http.Response(jsonEncode({'item': participation()}), 201);
  }
}

Future<void> _open(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: EventDetailScreen(event: fixture.event, backendService: fixture.backend,
      openOrganizerUrl: (uri) async { fixture.opened.add(uri); return true; }),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    ScaffoldMessenger.of(tester.element(find.byType(SnackBar).first)).clearSnackBars();
    await tester.pumpAndSettle();
  }
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (settle) { await tester.pumpAndSettle(); } else { await tester.pump(); }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.debugSeedSessionForTesting();
  });

  testWidgets('explicit create choice switches URL and hides capacity for shared offers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-create-mode')), findsOneWidget);
    expect(find.byKey(const Key('event-create-url')), findsNothing);
    final segmented = tester.widget<SegmentedButton<ParticipationMode>>(find.byKey(const Key('event-create-mode')));
    expect(segmented.selected, {ParticipationMode.direct});
    segmented.onSelectionChanged!({ParticipationMode.interest});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-create-url')), findsOneWidget);
    expect(find.text('Maximale Teilnehmerzahl'), findsNothing);
    await tester.enterText(find.byKey(const Key('event-create-url')), 'javascript:alert(1)');
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();
    expect(find.textContaining('http'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct RSVP uses server status and refreshed confirmed count; withdraw frees place', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _tap(tester, 'event-join');
    expect(fixture.status, 'approved');
    expect(fixture.writes, 1);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byKey(const Key('event-withdraw')), findsOneWidget);
    await _tap(tester, 'event-withdraw');
    expect(fixture.withdrawals, 1);
    expect(find.byKey(const Key('event-join')), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
  });

  testWidgets('shared offer is interest not booking, hides places and opens validated organizer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture(mode: ParticipationMode.interest, url: 'https://organizer.example/events/one');
    await _open(tester, fixture);
    expect(find.text('0/3'), findsNothing);
    await _tap(tester, 'event-organizer-link');
    expect(fixture.opened.single.toString(), 'https://organizer.example/events/one');
    await _tap(tester, 'event-join');
    expect(fixture.status, 'interested');
    expect(fixture.confirmed, 0);
    expect(find.text('You are interested. No place reserved.'), findsWidgets);
    expect(find.text('Open chat'), findsNothing);
    await _tap(tester, 'event-withdraw');
    expect(fixture.status, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed stored URL is not an actionable organizer button', (tester) async {
    await _open(tester, _Fixture(mode: ParticipationMode.interest, url: 'javascript:alert(1)'));
    expect(find.byKey(const Key('event-organizer-link')), findsNothing);
  });

  testWidgets('legacy pending remains honest even after host chooses direct mode', (tester) async {
    final fixture = _Fixture()..status = 'pending';
    await _open(tester, fixture);
    expect(find.text('Awaiting host confirmation. No place confirmed yet.'), findsOneWidget);
    expect(find.text('You are registered!'), findsNothing);
    expect(find.byKey(const Key('event-join')), findsNothing);
    expect(fixture.writes, 0);
    expect(find.byKey(const Key('event-withdraw')), findsOneWidget);
  });

  testWidgets('legacy new requests stay pending, never show registered', (tester) async {
    final fixture = _Fixture(mode: ParticipationMode.legacyApproval);
    await _open(tester, fixture);
    await _tap(tester, 'event-join');
    expect(fixture.status, 'pending');
    expect(find.text('You are registered!'), findsNothing);
    expect(find.text('0/3'), findsOneWidget);
  });

  testWidgets('status failure blocks join and exposes retry', (tester) async {
    final fixture = _Fixture()..loadFailure = true;
    await _open(tester, fixture);
    expect(find.byKey(const Key('event-join')), findsNothing);
    fixture.loadFailure = false;
    await _tap(tester, 'event-status-retry');
    expect(find.byKey(const Key('event-join')), findsOneWidget);
    expect(fixture.writes, 0);
  });

  testWidgets('join failure is retryable; no fabricated attendance', (tester) async {
    final fixture = _Fixture()..writeFailure = true;
    await _open(tester, fixture);
    await _tap(tester, 'event-join');
    expect(find.byKey(const Key('event-withdraw')), findsNothing);
    expect(find.text('0/3'), findsOneWidget);
    fixture.writeFailure = false;
    await _tap(tester, 'event-join');
    expect(fixture.status, 'approved');
    expect(fixture.writes, 2);
  });

  testWidgets('loading disables duplicate RSVP until server acknowledgment', (tester) async {
    final fixture = _Fixture()..pendingWrite = Completer<http.Response>();
    await _open(tester, fixture);
    await _tap(tester, 'event-join', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<FilledButton>(find.byKey(const Key('event-join'))).onPressed, isNull);
    expect(fixture.writes, 1);
    fixture.pendingWrite!.complete(fixture.joinResponse());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-withdraw')), findsOneWidget);
  });

  testWidgets('failed withdrawal preserves acknowledged registration for retry', (tester) async {
    final fixture = _Fixture()..status = 'approved'..confirmed = 1..withdrawFailure = true;
    await _open(tester, fixture);
    await _tap(tester, 'event-withdraw');
    expect(fixture.status, 'approved');
    expect(find.byKey(const Key('event-withdraw')), findsOneWidget);
    fixture.withdrawFailure = false;
    await _tap(tester, 'event-withdraw');
    expect(find.byKey(const Key('event-join')), findsOneWidget);
  });

  testWidgets('full and cancelled meetups disable RSVP', (tester) async {
    for (final fixture in [_Fixture(count: 3), _Fixture(eventStatus: EventStatus.cancelled)]) {
      await _open(tester, fixture);
      expect(tester.widget<FilledButton>(find.byKey(const Key('event-join'))).onPressed, isNull);
      expect(fixture.writes, 0);
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('all new event mode keys exist in each supported launch language', () {
    final keys = AppStringsManager.allStrings['en']!.keys.where((key) => key.startsWith('event_mode_') || {
      'event_direct_confirmation', 'event_interest_not_booking', 'event_organizer_url', 'event_invalid_url',
      'event_open_organizer', 'event_join_direct', 'event_show_interest', 'event_interest_saved',
      'event_interest_withdraw', 'event_withdraw', 'event_legacy_pending', 'event_pending_preserved',
      'event_shared_by_you', 'event_status_failed', 'event_action_failed', 'event_retry', 'event_closed',
      'event_confirmed_count',
    }.contains(key));
    for (final language in ['de', 'en', 'tr', 'ku']) {
      for (final key in keys) {
        expect(AppStringsManager.allStrings[language]![key], isNotEmpty, reason: '$language: $key');
      }
    }
  });
}