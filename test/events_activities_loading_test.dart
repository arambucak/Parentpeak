import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _berlin = PickedLocation(
    displayName: 'Berlin',
    city: 'Berlin',
    postcode: '',
    lat: 52.52,
    lon: 13.405);
const _hamburg = PickedLocation(
    displayName: 'Hamburg',
    city: 'Hamburg',
    postcode: '',
    lat: 53.5511,
    lon: 9.9937);

class _Agent extends EventDiscoveryAgent {
  final calls = <String>[];
  Future<List<DiscoveredEvent>> Function(String city)? loader;

  @override
  Future<List<DiscoveredEvent>> discoverEvents(
      {required String city,
      String radiusHint = '20 km Umkreis',
      List<String> childAges = const [],
      double? latitude,
      double? longitude}) {
    calls.add('$city/$radiusHint/${childAges.join(',')}');
    return loader?.call(city) ?? Future.value([]);
  }
}

MeetupEvent _event(String title, {PickedLocation location = _berlin}) =>
    MeetupEvent(
        id: title,
        hosterId: 'debug_demo_user',
        title: title,
        description: 'A real community event',
        category: EventCategory.outdoor,
        ageGroups: const [AgeGroup.mixed],
        location: location.city,
        latitude: location.lat,
        longitude: location.lon,
        eventDate: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
        maxParticipants: 8,
        photoUrl: '');

class _Service extends EventService {
  final users = <String>[];
  int invitations = 0;
  List<MeetupEvent> events = [_event('Community picnic')];
  Future<List<MeetupEvent>> Function(double latitude)? loader;

  @override
  Future<List<MeetupEvent>> getDiscoverableEventsForUser(
      {required String viewerUserId,
      required double viewerLatitude,
      required double viewerLongitude,
      List<AgeGroup>? ageGroups}) {
    users.add(viewerUserId);
    return loader?.call(viewerLatitude) ?? Future.value(events.toList());
  }

  @override
  Future<List<EventInvitation>> getInvitationsForUser(String userId) async {
    invitations++;
    return [];
  }

  @override
  Future<bool> deleteEvent(String eventId, {String? requestingUserId}) async {
    events.removeWhere((event) => event.id == eventId);
    return true;
  }

  @override
  Future<MeetupEvent> updateEvent(String eventId, Map<String, dynamic> fields,
      {required String requestingUserId}) async {
    final updated =
        MeetupEvent.fromJson({...events.single.toJson(), ...fields});
    events = [updated];
    return updated;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Agent agent,
  _Service service, {
  PickedLocation? location = _berlin,
  Future<PickedLocation?> Function()? gps,
  String user = 'debug_demo_user',
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: EventsActivitiesScreen(
        agent: agent,
        eventService: service,
        initialLocation: location,
        locationLoader: gps ?? () async => null,
        viewerUserId: () => user),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _showFeed(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(find.text(title), 300,
      scrollable: find.byType(Scrollable).last);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.debugSeedSessionForTesting();
    await languageService.setLanguage('en');
  });

  testWidgets('community renders before slow AI; reopen deduplicates AI',
      (tester) async {
    final ai = Completer<List<DiscoveredEvent>>();
    final agent = _Agent()..loader = (_) => ai.future;
    final service = _Service();
    await _open(tester, agent, service);
    expect(service.users, hasLength(1));
    expect(service.invitations, 1);
    await _showFeed(tester, 'Community picnic');
    expect(find.text('Community picnic'), findsOneWidget);
    // Community ist sofort da; die langsame KI läuft noch und wird durch den
    // sprechenden Such-Hinweis angezeigt (statt eines kontextlosen Spinners).
    expect(find.textContaining('AI is searching'), findsOneWidget);
    await _close(tester);
    await _open(tester, agent, service);
    await _showFeed(tester, 'Community picnic');
    expect(agent.calls, hasLength(1));
    expect(service.users, hasLength(1));
    ai.complete([]);
    await tester.pumpAndSettle();
    // KI fertig -> Such-Hinweis verschwindet.
    expect(find.textContaining('AI is searching'), findsNothing);
    await _close(tester);
    await _open(tester, agent, service);
    await _showFeed(tester, 'Community picnic');
    expect(agent.calls, hasLength(1));
  });

  testWidgets('UTC community occurrence renders local time and Berlin date',
      (tester) async {
    final utc = DateTime.utc(2026, 10, 14, 8);
    final local = utc.toLocal();
    final event = MeetupEvent.fromJson({
      ..._event('UTC picnic').toJson(),
      'eventDate': utc.toIso8601String(),
    });
    final service = _Service()..events = [event];
    await _open(tester, _Agent(), service);
    await tester.pumpAndSettle();
    await _showFeed(tester, 'UTC picnic');

    final date = '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(find.text('$date  $time'), findsOneWidget);
    if (Platform.environment['TZ'] == 'Europe/Berlin') {
      expect(local.timeZoneOffset, const Duration(hours: 2));
      expect(find.text('14.10.2026  10:00'), findsOneWidget);
      expect(find.text('14.10.2026  08:00'), findsNothing);
    }
    expect(event.eventDate.isUtc, isTrue);
    expect(event.eventDate, utc);
    await _close(tester);
  });

  testWidgets('equivalent GPS update does not duplicate pending query',
      (tester) async {
    final gps = Completer<PickedLocation?>();
    final ai = Completer<List<DiscoveredEvent>>();
    final agent = _Agent()..loader = (_) => ai.future;
    final service = _Service();
    await _open(tester, agent, service, gps: () => gps.future);
    gps.complete(const PickedLocation(
        displayName: 'Berlin GPS',
        city: 'Berlin',
        postcode: '',
        lat: 52.520001,
        lon: 13.405001));
    await tester.pump();
    expect(agent.calls, hasLength(1));
    expect(service.users, hasLength(1));
    ai.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('account and location queries never share displayed data',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await _close(tester);
    final other = Completer<List<MeetupEvent>>();
    service.loader = (_) => other.future;
    await _open(tester, agent, service, user: 'another-account');
    expect(service.users, ['debug_demo_user', 'another-account']);
    expect(find.text('Community picnic'), findsNothing);
    other.complete([]);
    await tester.pumpAndSettle();
    await _close(tester);
    service.loader =
        (_) async => [_event('Hamburg picnic', location: _hamburg)];
    await _open(tester, agent, service, location: _hamburg);
    await _showFeed(tester, 'Hamburg picnic');
    expect(find.text('Community picnic'), findsNothing);
    expect(agent.calls, hasLength(3));
  });

  testWidgets('stale location result cannot overwrite newer GPS query',
      (tester) async {
    final old = Completer<List<MeetupEvent>>();
    final gps = Completer<PickedLocation?>();
    final agent = _Agent();
    final service = _Service()
      ..loader = (latitude) => latitude == _berlin.lat
          ? old.future
          : Future.value([_event('Hamburg picnic', location: _hamburg)]);
    await _open(tester, agent, service, gps: () => gps.future);
    gps.complete(_hamburg);
    await tester.pumpAndSettle();
    await _showFeed(tester, 'Hamburg picnic');
    old.complete([_event('Old Berlin picnic')]);
    await tester.pumpAndSettle();
    expect(find.text('Old Berlin picnic'), findsNothing);
    expect(find.text('Hamburg picnic'), findsOneWidget);
  });

  testWidgets('explicit reload forces AI and community; failure retains data',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await tester.pumpAndSettle();
    await _showFeed(tester, 'Community picnic');
    await tester.ensureVisible(find.byKey(const Key('event-feed-last-sync')));
    final before =
        tester.widget<Text>(find.byKey(const Key('event-feed-last-sync'))).data;
    expect(before, startsWith('Events updated:'));
    agent.loader = (_) async => throw StateError('AI offline');
    service.loader = (_) async => throw StateError('community offline');
    await tester.tap(find.byKey(const Key('event-feed-refresh')));
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(2));
    expect(service.users, hasLength(2));
    expect(find.text('Community picnic'), findsOneWidget);
    final after =
        tester.widget<Text>(find.byKey(const Key('event-feed-last-sync'))).data;
    expect(after, before);
  });

  testWidgets('owner deletion refreshes community, not AI, and stays deleted',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await tester.pumpAndSettle();
    await _showFeed(tester, 'Community picnic');
    await tester.tap(find.text('Community picnic'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-owner-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(find.text('Community picnic'), findsNothing);
    expect(service.users, hasLength(2));
    expect(agent.calls, hasLength(1));
    await _close(tester);
    await _open(tester, agent, service);
    expect(service.users, hasLength(2));
    expect(find.text('Community picnic'), findsNothing);
  });

  testWidgets('owner edit returns acknowledged title without rerunning AI',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await tester.pumpAndSettle();
    await _showFeed(tester, 'Community picnic');
    await tester.tap(find.text('Community picnic'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-owner-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('event-edit-title')), 'Edited picnic');
    await tester.ensureVisible(find.byKey(const Key('event-edit-save')));
    await tester.tap(find.byKey(const Key('event-edit-save')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _showFeed(tester, 'Edited picnic');
    expect(find.text('Community picnic'), findsNothing);
    expect(service.users, hasLength(2));
    expect(agent.calls, hasLength(1));
    await _close(tester);
    await _open(tester, agent, service);
    await _showFeed(tester, 'Edited picnic');
    expect(service.users, hasLength(2));
  });

  testWidgets('pre-delete response cannot resurrect an event after return',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await tester.pumpAndSettle();
    final old = Completer<List<MeetupEvent>>();
    service.loader = (_) => old.future;
    await tester.tap(find.byKey(const Key('event-feed-refresh')));
    await tester.pump();
    await _showFeed(tester, 'Community picnic');
    await tester.ensureVisible(find.text('Community picnic'));
    await tester.pump();
    await tester.tap(find.text('Community picnic'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('event-owner-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    service.loader = (_) async => [];
    await tester.tap(find.byKey(const Key('event-delete-confirm')));
    await tester.pumpAndSettle();
    old.complete([_event('Community picnic')]);
    await tester.pumpAndSettle();
    expect(find.text('Community picnic'), findsNothing);
    expect(service.users, hasLength(3));
    expect(agent.calls, hasLength(2));
    await _close(tester);
    await _open(tester, agent, service);
    expect(service.users, hasLength(3));
    expect(find.text('Community picnic'), findsNothing);
  });

  testWidgets('manual location beats delayed GPS and remains locked on reopen',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    final gps = Completer<PickedLocation?>();
    await _open(tester, agent, service, gps: () => gps.future);
    tester
        .widget<LocationPickerWidget>(find.byType(LocationPickerWidget))
        .onLocationPicked(_hamburg);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(agent.calls.last, startsWith('Hamburg/'));
    expect(agent.calls, hasLength(2));
    gps.complete(_berlin);
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(2));
    await _close(tester);
    await _open(tester, agent, service,
        location: null, gps: () async => _berlin);
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(2));
    expect(service.users, hasLength(2));
  });

  testWidgets('invitation screen return does not reload AI or community',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Invitations'));
    await tester.tap(find.text('Invitations'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(1));
    expect(service.users, hasLength(1));
    expect(service.invitations, 2);
  });

  testWidgets('radius, ages and language get separate query caches',
      (tester) async {
    final agent = _Agent();
    final service = _Service();
    await _open(tester, agent, service);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('10 km'));
    await tester.tap(find.text('10 km'));
    await tester.pumpAndSettle();
    expect(agent.calls.last, contains('10 km Umkreis'));
    expect(agent.calls, hasLength(2));
    await tester.tap(find.text('20 km'));
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(2));
    final ageChip = find.byKey(const ValueKey('event-feed-age-mixed'));
    await tester.ensureVisible(ageChip);
    await tester.tap(ageChip);
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(3));
    await tester.tap(ageChip);
    await tester.pumpAndSettle();
    expect(agent.calls, hasLength(3));
    await _close(tester);
    await languageService.setLanguage('de');
    await _open(tester, agent, service);
    expect(agent.calls, hasLength(4));
    expect(service.users, hasLength(4));
  });

  testWidgets('closing with GPS and feed pending never updates disposed state',
      (tester) async {
    final gps = Completer<PickedLocation?>();
    final ai = Completer<List<DiscoveredEvent>>();
    final community = Completer<List<MeetupEvent>>();
    final agent = _Agent()..loader = (_) => ai.future;
    final service = _Service()..loader = (_) => community.future;
    await _open(tester, agent, service, gps: () => gps.future);
    await _close(tester);
    gps.complete(_hamburg);
    ai.complete([]);
    community.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
