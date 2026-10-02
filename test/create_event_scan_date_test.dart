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
  _Backend(BackendApiClient client) : super(apiClient: client);
  int uploads = 0;

  @override
  Future<String?> uploadImage(File file) async {
    uploads++;
    return 'https://example.test/photo.jpg';
  }
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
          of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Theater Bis14.01.2027 10:00');
  await tester.tap(find.text(text('event_scan_analyze')));
  await tester.pumpAndSettle();
}

Future<void> publish(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(CreateEventScreen)))
      .hideCurrentSnackBar();
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
    final backend = _Backend(BackendApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        return http.Response(jsonEncode({'event': body}), 201);
      }),
    ));
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(MaterialApp(
        home: CreateEventScreen(
      flyerScanner: _Scanner([
        const ScannedEventDraft(
            title: 'Theater',
            description: 'For families',
            time: TimeOfDayLite(10, 0),
            ageGroups: [AgeGroup.mixed])
      ]),
      eventService: EventService(backend: backend),
      eventBackendService: backend,
    )));
    await tester.pumpAndSettle();
    await scan(tester);
    expect(find.text(text('event_scan_choose_date')), findsOneWidget);
    expect(find.byKey(const ValueKey('event-scan-date-error')), findsOneWidget);
    await publish(tester);
    expect(requests, isEmpty);
    expect(backend.uploads, 0);
    await confirmDate(tester);
    await publish(tester);
    expect(requests, isEmpty);
    await confirmTime(tester);
    await publish(tester);
    expect(requests, hasLength(1));
    final chosen = DateTime(today.year, today.month, today.day + 1, 10);
    expect(requests.single['startDate'], chosen.toUtc().toIso8601String());
    expect(DateTime.parse(requests.single['startDate'] as String).toLocal(),
        chosen);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      're-scan requires confirmation again and keeps manual day and time; old scan opens picker safely',
      (tester) async {
    final scanner = _Scanner([
      ScannedEventDraft(
          title: 'Theater',
          date: DateTime(2020, 1, 1),
          time: const TimeOfDayLite(10, 0)),
      ScannedEventDraft(
          title: 'Other flyer',
          date: DateTime(2030, 1, 14),
          time: const TimeOfDayLite(12, 0)),
    ]);
    await tester.pumpWidget(
        MaterialApp(home: CreateEventScreen(flyerScanner: scanner)));
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
    expect(find.text(text('event_scan_date_required')), findsOneWidget);
    expect(find.text(text('event_scan_time_required')), findsOneWidget);
    await publish(tester);
    expect(find.text(text('event_scan_datetime_required')), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
