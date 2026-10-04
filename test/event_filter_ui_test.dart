import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Agent extends EventDiscoveryAgent {
  _Agent([this.events = const []]);
  final List<DiscoveredEvent> events;
  int calls = 0;
  @override
  Future<List<DiscoveredEvent>> discoverEvents({
    required String city,
    String radiusHint = '20 km Umkreis',
    List<String> childAges = const [],
    double? latitude,
    double? longitude,
  }) async {
    calls++;
    return events;
  }
}

DiscoveredEvent _aiEvent(
  String title, {
  DateTime? eventDate,
  bool isRecurring = false,
  String? recurringNote,
}) =>
    DiscoveredEvent(
      id: title,
      title: title,
      description: 'Beschreibung',
      category: DiscoveredEventCategory.familienzentrum,
      ageLabels: const ['Alle Altersgruppen'],
      location: 'Kreuzberg',
      cityHint: 'Berlin',
      eventDate: eventDate,
      isRecurring: isRecurring,
      recurringNote: recurringNote,
      discoveredAt: DateTime.now(),
    );

MeetupEvent _event(
  String title, {
  double latitude = double.nan,
  double longitude = double.nan,
  double? price,
  int days = 1,
}) =>
    MeetupEvent(
      id: title,
      hosterId: 'host',
      title: title,
      description: '',
      category: EventCategory.other,
      ageGroups: [],
      location: 'Unresolved venue',
      latitude: latitude,
      longitude: longitude,
      price: price,
      eventDate: DateTime.now().add(Duration(days: days)),
      createdAt: DateTime.now(),
      maxParticipants: 5,
      photoUrl: '',
    );

class _Service extends EventService {
  final List<MeetupEvent> events;
  _Service(this.events);
  final origins = <bool>[];
  int loads = 0;
  @override
  Future<List<MeetupEvent>> getFilteredDiscoverableEventsForUser({
    required String viewerUserId,
    required double viewerLatitude,
    required double viewerLongitude,
    List<AgeGroup>? ageGroups,
    double radiusKm = 25,
    bool nearbyOnly = false,
    bool onlyFree = false,
    String timeWindow = 'all',
  }) async {
    loads++;
    origins.add(validCoordinates(viewerLatitude, viewerLongitude));
    return events;
  }

  @override
  Future<List<EventInvitation>> getInvitationsForUser(String userId) async =>
      [];
}

Future<void> _open(
  WidgetTester tester,
  _Service service,
  _Agent agent, {
  PickedLocation? location,
  EventGeocoder? geocoder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: EventsActivitiesScreen(
        agent: agent,
        eventService: service,
        initialLocation: location,
        locationLoader: () async => null,
        viewerUserId: () => 'viewer',
        geocoder: geocoder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.debugSeedSessionForTesting();
    await languageService.setLanguage('en');
  });
  for (final resolved in [true, false]) {
    testWidgets(
      'saved city uses provider coordinates or unknown (resolved=$resolved)',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('events.saved_city', 'Grunewald, Berlin');
        final service = _Service([
          _event('Saved-city event', latitude: 52.4986, longitude: 13.4033),
        ]);
        final geocoder = EventGeocoder(
          client: MockClient((request) async {
            expect(request.url.queryParameters['q'], 'Grunewald, Berlin');
            return http.Response(
              resolved ? '[{"lat":"52.4861","lon":"13.2599"}]' : '[]',
              200,
            );
          }),
        );
        await _open(tester, service, _Agent(), geocoder: geocoder);
        expect(service.origins.first, isFalse);
        expect(service.origins.last, resolved);
        await tester.scrollUntilVisible(
          find.text('Saved-city event'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Saved-city event'), findsOneWidget);
        expect(
          find.textContaining('9.8 km'),
          resolved ? findsOneWidget : findsNothing,
        );
        if (!resolved) expect(find.textContaining(' km · '), findsNothing);
      },
    );
  }
  testWidgets(
    'no permission or location never fabricates origin, distance or nearby count',
    (tester) async {
      final service = _Service([
        _event('Unknown location event'),
        _event('Past event', days: -1),
      ]);
      await _open(tester, service, _Agent());
      expect(service.origins, isNotEmpty);
      expect(service.origins.every((known) => !known), isTrue);
      await tester.scrollUntilVisible(
        find.text('Unknown location event'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Unknown location event'), findsOneWidget);
      expect(find.text('Past event'), findsNothing);
      expect(find.textContaining(' km · '), findsNothing);
      final nearby = find.byWidgetPredicate(
        (widget) =>
            widget is FilterChip &&
            widget.label is Text &&
            ((widget.label as Text).data ?? '').contains('(0)'),
      );
      await tester.ensureVisible(nearby);
      await tester.tap(nearby);
      await tester.pumpAndSettle();
      expect(find.text('Unknown location event'), findsNothing);
    },
  );
  testWidgets(
    'known and unknown distances coexist; only explicit zero is free; AI cache is retained',
    (tester) async {
      final service = _Service([
        _event('Known near', latitude: 52.4986, longitude: 13.4033, price: 0),
        _event('Unknown price'),
        _event('Paid event', price: 12),
        _event('Grunewald', latitude: 52.4861, longitude: 13.2599, price: 0),
      ]);
      final agent = _Agent();
      await _open(
        tester,
        service,
        agent,
        location: const PickedLocation(
          displayName: 'Kreuzberg',
          city: 'Berlin',
          postcode: '',
          lat: 52.4986,
          lon: 13.4033,
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Unknown price'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Unknown price'), findsOneWidget);
      final free = find.byKey(const ValueKey('event-feed-only-free'));
      await tester.scrollUntilVisible(
        free,
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      // Der Chip liegt in einer horizontal scrollbaren Filterleiste; nach dem
      // vertikalen Zurückscrollen zusätzlich sicherstellen, dass er auch
      // horizontal vollständig sichtbar (und damit tappbar) ist. Robust
      // gegenüber unterschiedlich breiten Chip-Labels.
      await tester.ensureVisible(free);
      await tester.pumpAndSettle();
      await tester.tap(free);
      await tester.pumpAndSettle();
      expect(agent.calls, 1);
      expect(service.loads, 2);
      expect(find.text('Unknown price'), findsNothing);
      expect(find.text('Paid event'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Grunewald'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('9.8 km'), findsOneWidget);
    },
  );

  testWidgets(
    'recurring AI offer without a date survives the Today filter; one-off does not',
    (tester) async {
      // Titel bewusst so gewählt, dass das wiederkehrende Angebot ("A…") im
      // Tiebreaker vor dem einmaligen ("Z…") sortiert und damit oben im
      // (lazy gebauten) Feed sichtbar ist.
      final service = _Service([]);
      final agent = _Agent([
        _aiEvent('A Offener Familientreff',
            isRecurring: true, recurringNote: 'jeden Samstag'),
        _aiEvent('Z Einmaliges Angebot ohne Datum'),
      ]);
      await _open(
        tester,
        service,
        agent,
        location: const PickedLocation(
          displayName: 'Kreuzberg',
          city: 'Berlin',
          postcode: '',
          lat: 52.4986,
          lon: 13.4033,
        ),
      );
      // Der KI-Feed lädt progressiv (async); auf das Eintreffen der Treffer
      // warten. Das wiederkehrende Angebot ("A…") steht oben im Feed.
      await tester.pumpAndSettle();
      for (var i = 0;
          i < 20 &&
              find
                  .text('A Offener Familientreff', skipOffstage: false)
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Standardmäßig ("Alle Termine") ist das wiederkehrende Angebot im Feed
      // gebaut (skipOffstage:false, da der lazy ListView-Eintrag außerhalb des
      // Viewports liegen kann).
      expect(
        find.text('A Offener Familientreff', skipOffstage: false),
        findsOneWidget,
      );

      // Auf "Heute" umschalten (ChoiceChip mit Label "Today").
      final today = find.widgetWithText(ChoiceChip, 'Today');
      await tester.scrollUntilVisible(
        today,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(today);
      await tester.pumpAndSettle();
      await tester.tap(today);
      await tester.pumpAndSettle();

      // Nach dem Umschalten auf "Heute": Das wiederkehrende/offene Angebot
      // bleibt im Feed, das einmalige ohne Datum ist komplett heraus.
      expect(
        find.text('A Offener Familientreff', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Z Einmaliges Angebot ohne Datum', skipOffstage: false),
        findsNothing,
      );
    },
  );
}
