import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_flyer_scanner_service.dart';
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Scanner extends EventFlyerScannerService {
  _Scanner(this.drafts);
  final List<ScannedEventDraft> drafts;

  @override
  Future<ScannedEventDraft?> scanFromText(String rawText) async =>
      drafts.removeAt(0);
}

class _Backend extends EventBackendService {
  _Backend(BackendApiClient client)
    : super(
        apiClient: client,
        geocoder: EventGeocoder(
          client: MockClient(
            (request) async =>
                http.Response('[{"lat":"53.55","lon":"10.0"}]', 200),
          ),
          minimumInterval: Duration.zero,
        ),
      );
  int uploads = 0;

  @override
  Future<String?> uploadImage(File file) async {
    uploads++;
    return 'https://example.test/photo.jpg';
  }
}

class _CapturingBackend extends EventBackendService {
  final events = <MeetupEvent>[];
  Completer<MeetupEvent?>? pending;

  @override
  bool get isEnabled => true;

  @override
  Future<MeetupEvent?> createEvent(MeetupEvent event) async {
    events.add(event);
    return pending == null ? event : await pending!.future;
  }
}

class _PendingScanner extends EventFlyerScannerService {
  final result = Completer<ScannedEventDraft?>();

  @override
  Future<ScannedEventDraft?> scanFromText(String rawText) => result.future;
}

String text(String key) => AppStringsManager.getString('en', key);

Future<void> scan(WidgetTester tester) async {
  await tester.ensureVisible(find.text(text('event_scan_button')));
  await tester.tap(find.text(text('event_scan_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text('event_scan_text')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    'Theater Bis14.01.2027 10:00',
  );
  await tester.tap(find.text(text('event_scan_analyze')));
  await tester.pumpAndSettle();
}

Future<void> publish(WidgetTester tester) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(CreateEventScreen)),
  ).hideCurrentSnackBar();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text('publish_event')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text('publish_event')));
  await tester.pumpAndSettle();
}

Future<void> confirmDate(WidgetTester tester) async {
  final picker = find.byKey(const ValueKey('event-date-picker'));
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> confirmTime(WidgetTester tester) async {
  final picker = find.byKey(const ValueKey('event-time-picker'));
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await languageService.setLanguage('en');
    await AuthService.instance.debugSeedSessionForTesting();
  });

  testWidgets(
    'unknown scan day blocks publish until both real pickers confirm; sends local time as UTC',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      final backend = _Backend(
        BackendApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            requests.add(body);
            return http.Response(
              jsonEncode({
                'event': {...body, 'id': 'saved-id'},
              }),
              201,
            );
          }),
        ),
      );
      final today = DateUtils.dateOnly(DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: CreateEventScreen(
            flyerScanner: _Scanner([
              const ScannedEventDraft(
                title: 'Theater',
                description: 'For families',
                location: 'Theater, Hamburg',
                time: TimeOfDayLite(10, 0),
                ageGroups: [AgeGroup.mixed],
              ),
            ]),
            eventService: EventService(backend: backend),
            eventBackendService: backend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scan(tester);
      expect(find.text(text('event_scan_choose_date')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-scan-date-error')), findsNothing);
      await publish(tester);
      expect(
        find.byKey(const ValueKey('event-scan-date-error')),
        findsOneWidget,
      );
      expect(requests, isEmpty);
      expect(backend.uploads, 0);
      await confirmDate(tester);
      await publish(tester);
      expect(requests, isEmpty);
      await confirmTime(tester);
      expect(find.byKey(const ValueKey('event-scan-date-error')), findsNothing);
      await publish(tester);
      expect(requests, hasLength(1));
      final chosen = DateTime(today.year, today.month, today.day + 1, 10);
      expect(requests.single['startDate'], chosen.toUtc().toIso8601String());
      expect(requests.single['latitude'], 53.55);
      expect(requests.single['longitude'], 10.0);
      expect(
        DateTime.parse(requests.single['startDate'] as String).toLocal(),
        chosen,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual submit error appears only on submit and clears after both pickers',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-scan-date-error')), findsNothing);
      final location = find.widgetWithText(TextFormField, 'Treffpunkt');
      expect(
        (tester.widget<TextFormField>(location)).controller!.text,
        isEmpty,
      );
      await publish(tester);
      expect(
        find.byKey(const ValueKey('event-scan-date-error')),
        findsOneWidget,
      );
      await confirmDate(tester);
      expect(
        find.byKey(const ValueKey('event-scan-date-error')),
        findsOneWidget,
      );
      await confirmTime(tester);
      expect(find.byKey(const ValueKey('event-scan-date-error')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final value in ['9,40 €', 'kostenlos', 'unknown', 'unconfirmed']) {
    testWidgets(
      'scan price $value remains editable and needs explicit confirmation',
      (tester) async {
        final backend = _CapturingBackend();
        await tester.pumpWidget(
          MaterialApp(
            home: CreateEventScreen(
              flyerScanner: _Scanner([
                ScannedEventDraft(
                  title: 'Family theater',
                  description: 'A family show',
                  location: 'Hamburg theater',
                  date: DateTime.now().add(const Duration(days: 2)),
                  time: const TimeOfDayLite(10, 0),
                  ageGroups: const [AgeGroup.mixed],
                  priceNote: value == 'unconfirmed' ? '9,40 €' : value,
                ),
              ]),
              eventService: EventService(backend: backend),
              eventBackendService: backend,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (value == 'unknown') {
          await tester.tap(find.text(text('event_mode_interest')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('event-create-url')),
            'https://organizer.example/theater',
          );
        }
        await scan(tester);
        final amount = ScannedEventDraft.parsePriceAmount(
          value == 'unconfirmed' ? '9,40 €' : value,
        );
        final field = find.byKey(const ValueKey('event-price-input'));
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          amount?.toStringAsFixed(2) ?? '',
        );
        final checkbox = find.byKey(const ValueKey('event-price-confirm'));
        expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
        if (amount != null && value != 'unconfirmed') {
          await tester.ensureVisible(checkbox);
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
        }
        await confirmDate(tester);
        await confirmTime(tester);
        await publish(tester);
        expect(
          backend.events.single.price,
          value == 'unconfirmed' ? isNull : amount,
        );
        expect(
          backend.events.single.participationMode,
          value == 'unknown'
              ? ParticipationMode.interest
              : ParticipationMode.direct,
        );
        if (value == 'unknown') {
          expect(
            backend.events.single.externalUrl,
            'https://organizer.example/theater',
          );
          expect(backend.events.single.maxParticipants, 0);
          expect(
            backend.events.single.visibility,
            EventVisibility.publicNearby,
          );
        }
        expect(backend.events.single.paymentDate, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'save awaits backend ack, failure stays open, dispose during retry is safe',
    (tester) async {
      final backend = _CapturingBackend()..pending = Completer<MeetupEvent?>();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateEventScreen(
            flyerScanner: _Scanner([
              ScannedEventDraft(
                title: 'Family theater',
                description: 'A show',
                location: 'Hamburg',
                date: DateTime.now().add(const Duration(days: 2)),
                time: const TimeOfDayLite(10, 0),
                ageGroups: const [AgeGroup.mixed],
              ),
            ]),
            eventService: EventService(backend: backend),
            eventBackendService: backend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scan(tester);
      await confirmDate(tester);
      await confirmTime(tester);
      ScaffoldMessenger.of(
        tester.element(find.byType(CreateEventScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(text('publish_event')));
      await tester.tap(find.text(text('publish_event')));
      await tester.pump();
      expect(backend.events, hasLength(1));
      expect(find.text(text('event_is_live')), findsNothing);
      backend.pending!.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(CreateEventScreen), findsOneWidget);
      expect(find.textContaining('Konnte nicht speichern'), findsOneWidget);
      backend.pending = Completer<MeetupEvent?>();
      ScaffoldMessenger.of(
        tester.element(find.byType(CreateEventScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text(text('publish_event')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      backend.pending!.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposing during a text scan does not update disposed controllers',
    (tester) async {
      final scanner = _PendingScanner();
      await tester.pumpWidget(
        MaterialApp(home: CreateEventScreen(flyerScanner: scanner)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(text('event_scan_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text('event_scan_text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Flyer',
      );
      await tester.tap(find.text(text('event_scan_analyze')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      scanner.result.complete(
        const ScannedEventDraft(title: 'Late result', priceNote: '9,40 €'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date and time controls remain nonblank at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const CreateEventScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('event-date-picker'));
      final time = find.byKey(const ValueKey('event-time-picker'));
      await tester.ensureVisible(date);
      expect(tester.getSize(date).width, 288);
      expect(tester.getSize(date).height, greaterThanOrEqualTo(152));
      expect(
        tester.getRect(date).bottom,
        lessThanOrEqualTo(tester.getRect(time).top),
      );
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    're-scan requires confirmation again and keeps manual day and time; old scan opens picker safely',
    (tester) async {
      final scanner = _Scanner([
        ScannedEventDraft(
          title: 'Theater',
          date: DateTime(2020, 1, 1),
          time: const TimeOfDayLite(10, 0),
        ),
        ScannedEventDraft(
          title: 'Other flyer',
          date: DateTime(2030, 1, 14),
          time: const TimeOfDayLite(12, 0),
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(home: CreateEventScreen(flyerScanner: scanner)),
      );
      await tester.pumpAndSettle();
      await scan(tester);
      await confirmDate(tester);
      await confirmTime(tester);
      final today = DateTime.now();
      final dateLabel = '${today.day}.${today.month}.${today.year}';
      expect(find.text(dateLabel), findsOneWidget);
      await scan(tester);
      expect(find.text(dateLabel), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text(text('event_scan_date_required')), findsNothing);
      expect(find.text(text('event_scan_time_required')), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      await publish(tester);
      expect(find.text(text('event_scan_datetime_required')), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
