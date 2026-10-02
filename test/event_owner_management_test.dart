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
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/participation_service.dart';
import 'package:parentpeak/models/event_participation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/event_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Participation extends ParticipationService {
  int reads = 0;
  @override
  Future<EventParticipation?> getParticipationByUserAndEvent({
    required String userId,
    required String eventId,
  }) async {
    reads++;
    return null;
  }
}

int _sequence = 0;

class _Fixture {
  _Fixture({bool owner = true, bool past = false}) {
    event = MeetupEvent(
      id: 'owner-test-${_sequence++}',
      hosterId: owner ? 'debug_demo_user' : 'another-parent',
      title: 'Family picnic',
      description: 'An afternoon together',
      category: EventCategory.outdoor,
      ageGroups: const [AgeGroup.mixed],
      location: 'City park',
      latitude: 52,
      longitude: 13,
      eventDate: DateTime.now().add(Duration(days: past ? -2 : 2)),
      createdAt: DateTime.now(),
      maxParticipants: 8,
      currentParticipants: 3,
      photoUrl: '',
      seriesId: 'picnic-series',
    );
    backend = EventBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'http://localhost:3000',
        authToken: 'test-only',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'PUT') {
            if (pendingUpdate != null) return pendingUpdate!.future;
            if (updateStatus != 200) return http.Response('{}', updateStatus);
            return updateResponse(request);
          }
          if (request.method == 'DELETE') {
            if (pendingDelete != null) return pendingDelete!.future;
            return http.Response(
              jsonEncode({'success': deleteStatus == 200}),
              deleteStatus,
            );
          }
          if (request.url.path.endsWith('/follow')) {
            return http.Response('{"following":false}', 200);
          }
          return http.Response('{}', 503);
        }),
      ),
    );
    service = EventService(backend: backend);
  }
  late final MeetupEvent event;
  late final EventBackendService backend;
  late final EventService service;
  final participation = _Participation();
  final requests = <http.Request>[];
  int updateStatus = 200;
  int deleteStatus = 200;
  Completer<http.Response>? pendingUpdate;
  Completer<http.Response>? pendingDelete;
  String? serverTitle;

  http.Response updateResponse(http.Request request) {
    final fields = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'event': {
          ...event.toJson(),
          ...fields,
          'title': serverTitle ?? fields['title'],
          'eventDate': fields['startDate'] ?? event.eventDate.toIso8601String(),
        },
      }),
      200,
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Fixture fixture, {
  String locale = 'en',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('de'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          alwaysUse24HourFormat: true,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => EventDetailScreen(
                  event: fixture.event,
                  eventService: fixture.service,
                  backendService: fixture.backend,
                  participationService: fixture.participation,
                ),
              ),
            ),
            child: const Text('Open event'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open event'));
  await tester.pumpAndSettle();
}

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('event-owner-edit')));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const Key('event-edit-save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pump();
}

Future<void> _delete(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('event-owner-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.debugSeedSessionForTesting();
  });

  testWidgets(
    'owner has visible tools, no participation or own series subscription',
    (tester) async {
      final fixture = _Fixture();
      await _open(tester, fixture);
      expect(find.text('Your event'), findsOneWidget);
      expect(find.byKey(const Key('event-owner-edit')), findsOneWidget);
      expect(find.byKey(const Key('event-owner-menu')), findsOneWidget);
      expect(find.text('Request to participate'), findsNothing);
      expect(find.text('Follow offer'), findsNothing);
      expect(fixture.participation.reads, 0);
      expect(fixture.requests, isEmpty);
    },
  );

  testWidgets('non-owner has no management tools', (tester) async {
    final fixture = _Fixture(owner: false);
    await _open(tester, fixture);
    expect(find.byKey(const Key('event-owner-edit')), findsNothing);
    expect(find.byKey(const Key('event-owner-menu')), findsNothing);
    expect(fixture.participation.reads, 1);
    await tester.scrollUntilVisible(find.text('Request to participate'), 250);
    expect(find.text('Follow offer'), findsOneWidget);
    expect(find.text('Request to participate'), findsOneWidget);
  });

  testWidgets(
    'save sends edited fields and shows only acknowledged server values',
    (tester) async {
      final fixture = _Fixture()..serverTitle = 'Confirmed picnic';
      fixture.pendingUpdate = Completer<http.Response>();
      await _open(tester, fixture);
      await _edit(tester);
      await tester.enterText(
        find.byKey(const Key('event-edit-title')),
        ' New picnic ',
      );
      await tester.enterText(
        find.byKey(const Key('event-edit-description')),
        'Bring a blanket',
      );
      await tester.enterText(
        find.byKey(const Key('event-edit-location')),
        'Lake park',
      );
      await tester.enterText(find.byKey(const Key('event-edit-capacity')), '5');
      await _save(tester);
      await tester.pump(const Duration(milliseconds: 50));
      final request = fixture.requests.singleWhere(
        (request) => request.method == 'PUT',
      );
      expect(jsonDecode(request.body), {
        'title': 'New picnic',
        'description': 'Bring a blanket',
        'location': 'Lake park',
        'startDate': fixture.event.eventDate.toUtc().toIso8601String(),
        'maxParticipants': 5,
        'hosterId': 'debug_demo_user',
      });
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('event-edit-save')))
            .onPressed,
        isNull,
      );
      expect(find.text('Confirmed picnic'), findsNothing);
      fixture.pendingUpdate!.complete(fixture.updateResponse(request));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-edit-save')), findsNothing);
      expect(find.text('Confirmed picnic'), findsOneWidget);
      expect(find.text('Lake park'), findsOneWidget);
    },
  );

  testWidgets('save failure keeps form and draft, then permits retry', (
    tester,
  ) async {
    final fixture = _Fixture()..updateStatus = 403;
    await _open(tester, fixture);
    await _edit(tester);
    await tester.enterText(
      find.byKey(const Key('event-edit-title')),
      'Draft picnic',
    );
    await _save(tester);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not save. Your changes are still here. Please try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('event-edit-title')))
          .controller!
          .text,
      'Draft picnic',
    );
    fixture.updateStatus = 200;
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Draft picnic'), findsOneWidget);
  });

  testWidgets('capacity cannot be lower than existing participants', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _edit(tester);
    await tester.enterText(find.byKey(const Key('event-edit-capacity')), '2');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('At least 3 participants.'), findsOneWidget);
    expect(fixture.requests, isEmpty);
  });

  testWidgets('required title and location block requests', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _edit(tester);
    await tester.enterText(find.byKey(const Key('event-edit-title')), ' ');
    await tester.enterText(find.byKey(const Key('event-edit-location')), ' ');
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Please fill in this field.'), findsNWidgets(2));
    expect(fixture.requests, isEmpty);
  });

  testWidgets('date and time pickers send the selected UTC startDate', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _edit(tester);
    await tester.ensureVisible(find.byKey(const Key('event-edit-date')));
    await tester.tap(find.byKey(const Key('event-edit-date')));
    await tester.pumpAndSettle();
    final chosen = fixture.event.eventDate.add(const Duration(days: 3));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(chosen);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-edit-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    final timeFields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(timeFields.at(0), '09');
    await tester.enterText(timeFields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _save(tester);
    await tester.pumpAndSettle();
    final request = fixture.requests.singleWhere(
      (request) => request.method == 'PUT',
    );
    expect(
      jsonDecode(request.body)['startDate'],
      DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        9,
        30,
      ).toUtc().toIso8601String(),
    );
  });

  testWidgets('HTTP success without an updated event keeps the draft', (
    tester,
  ) async {
    final fixture = _Fixture()..pendingUpdate = Completer<http.Response>();
    await _open(tester, fixture);
    await _edit(tester);
    await _save(tester);
    fixture.pendingUpdate!.complete(http.Response('{"success":true}', 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event-edit-save')), findsOneWidget);
    expect(
      find.text(
        'Could not save. Your changes are still here. Please try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('past date cannot be saved', (tester) async {
    final fixture = _Fixture(past: true);
    await _open(tester, fixture);
    await _edit(tester);
    await _save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Please choose a future date and time.'), findsOneWidget);
    expect(fixture.requests, isEmpty);
  });

  testWidgets('delete cancel names event and sends no request', (tester) async {
    final fixture = _Fixture();
    await _open(tester, fixture);
    await _delete(tester);
    expect(
      find.text(
        '"Family picnic" will be permanently deleted. This cannot be undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(fixture.requests, isEmpty);
  });

  testWidgets(
    'delete failure stays open, retry closes only after acknowledgement',
    (tester) async {
      final fixture = _Fixture()..deleteStatus = 403;
      await _open(tester, fixture);
      await _delete(tester);
      await tester.tap(find.byKey(const Key('event-delete-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not delete. Your event is still available. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(EventDetailScreen), findsOneWidget);
      fixture.pendingDelete = Completer<http.Response>();
      await tester.tap(find.byKey(const Key('event-delete-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('event-delete-confirm')))
            .onPressed,
        isNull,
      );
      expect(find.byType(EventDetailScreen), findsOneWidget);
      final request = fixture.requests.last;
      expect(request.url.queryParameters['hosterId'], 'debug_demo_user');
      fixture.pendingDelete!.complete(http.Response('{"success":true}', 200));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.text('Open event'), findsOneWidget);
    },
  );

  testWidgets('German owner labels fit narrow screen and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture();
    await _open(tester, fixture, locale: 'de', textScale: 1.4);
    expect(find.text('Bearbeiten'), findsOneWidget);
    await _edit(tester);
    expect(find.text('Event bearbeiten'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('event-edit-save')));
    expect(find.text('Änderungen speichern'), findsOneWidget);
  });

  test('new labels fall back to English for other supported locales', () {
    for (final key in AppStringsManager.allStrings['en']!.keys.where(
      (key) => key.startsWith('event_owner_'),
    )) {
      expect(AppStringsManager.getString('de', key), isNot(key));
      expect(
        AppStringsManager.getString('fr', key),
        AppStringsManager.getString('en', key),
      );
    }
  });

  test(
    'owner service caches acknowledged update, preserves it on failure and removes after delete',
    () async {
      final fixture = _Fixture();
      final fields = {'title': 'Cached picnic'};
      final saved = await fixture.service.updateEvent(
        fixture.event.id,
        fields,
        requestingUserId: 'debug_demo_user',
      );
      expect(
        (await fixture.service.getEventById(fixture.event.id))?.title,
        saved.title,
      );
      fixture.updateStatus = 500;
      await expectLater(
        fixture.service.updateEvent(fixture.event.id, {
          'title': 'Failed',
        }, requestingUserId: 'debug_demo_user'),
        throwsStateError,
      );
      expect(
        (await fixture.service.getEventById(fixture.event.id))?.title,
        saved.title,
      );
      fixture.deleteStatus = 403;
      await expectLater(
        fixture.service.deleteEvent(
          fixture.event.id,
          requestingUserId: 'debug_demo_user',
        ),
        throwsStateError,
      );
      expect(await fixture.service.getEventById(fixture.event.id), isNotNull);
      fixture.deleteStatus = 200;
      await fixture.service.deleteEvent(
        fixture.event.id,
        requestingUserId: 'debug_demo_user',
      );
      expect(await fixture.service.getEventById(fixture.event.id), isNull);
    },
  );
}
