import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
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

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
);

class _Picker extends ImagePicker {
  _Picker(this.pick);
  final Future<XFile?> Function() pick;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) =>
      pick();
}

class _UnreadablePhoto extends XFile {
  _UnreadablePhoto() : super('blob:https://app.example/unreadable');

  @override
  Future<Uint8List> readAsBytes() async => throw StateError('read failed');
}

class _Scanner extends EventFlyerScannerService {
  @override
  Future<ScannedEventDraft?> scanFromText(String rawText) async =>
      ScannedEventDraft(
        title: 'Family picnic',
        description: 'Bring a blanket',
        location: 'City park',
        date: DateTime.now().add(const Duration(days: 2)),
        time: const TimeOfDayLite(12, 0),
        ageGroups: const [AgeGroup.mixed],
      );
}

class _Backend extends EventBackendService {
  _Backend(BackendApiClient client) : super(apiClient: client);
  final created = <MeetupEvent>[];

  @override
  Future<MeetupEvent?> createEvent(MeetupEvent event) async {
    created.add(event);
    return event;
  }
}

String _text(String key) => AppStringsManager.getString('en', key);

Future<void> _pick(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('event-photo-picker'));
  await tester.ensureVisible(button);
  await tester.runAsync(() async {
    await tester.tap(button);
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (tester.widget<OutlinedButton>(button).onPressed != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Photo selection did not complete');
  });
  await tester.pumpAndSettle();
}

Future<void> _publish(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(CreateEventScreen)))
      .hideCurrentSnackBar();
  await tester.pumpAndSettle();
  final button = find.text(_text('publish_event'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  final scan = find.text(_text('event_scan_button'));
  await tester.ensureVisible(scan);
  await tester.tap(scan);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_text('event_scan_text')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField)),
    'Family picnic',
  );
  await tester.tap(find.text(_text('event_scan_analyze')));
  await tester.pumpAndSettle();
  for (final key in ['event-date-picker', 'event-time-picker']) {
    final picker = find.byKey(ValueKey(key));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await languageService.setLanguage('en');
    await AuthService.instance.debugSeedSessionForTesting();
  });

  XFile photo(String name) => XFile.fromData(
        _png,
        path: kIsWeb ? null : '/not-a-file/$name',
        name: name,
        mimeType: 'image/png',
      );

  testWidgets(
      'browser-style photo uses memory preview, can be replaced and removed',
      (tester) async {
    var name = 'first.png';
    await tester.pumpWidget(MaterialApp(
        home: CreateEventScreen(
      imagePicker: _Picker(() async => photo(name)),
    )));
    await tester.pumpAndSettle();
    await _pick(tester);
    final preview = find.byKey(const ValueKey('event-photo-preview'));
    expect(tester.widget<Image>(preview).image, isA<MemoryImage>());
    expect((tester.widget<Image>(preview).image as MemoryImage).bytes, _png);
    name = 'second.png';
    await _pick(tester);
    expect(preview, findsOneWidget);
    final remove = find.byKey(const ValueKey('event-photo-remove'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    expect(find.text('Foto auswählen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['cancel', 'read', 'picker', 'empty']) {
    testWidgets('$failure preserves the previous selected photo',
        (tester) async {
      var picked = false;
      final picker = _Picker(() async {
        if (!picked) {
          picked = true;
          return photo('original.png');
        }
        if (failure == 'read') return _UnreadablePhoto();
        if (failure == 'picker') throw StateError('picker failed');
        if (failure == 'empty') return XFile.fromData(Uint8List(0));
        return null;
      });
      await tester.pumpWidget(MaterialApp(
        home: CreateEventScreen(imagePicker: picker),
      ));
      await tester.pumpAndSettle();
      await _pick(tester);
      final original = tester
          .widget<Image>(
            find.byKey(const ValueKey('event-photo-preview')),
          )
          .image;
      await _pick(tester);
      expect(
          tester
              .widget<Image>(
                find.byKey(const ValueKey('event-photo-preview')),
              )
              .image,
          original);
      expect(find.text(_text('request_failed_retry')),
          failure == 'cancel' ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'pending photo selection blocks duplicate picks and survives disposal',
      (tester) async {
    final pending = Completer<XFile?>();
    var selections = 0;
    await tester.pumpWidget(MaterialApp(
      home: CreateEventScreen(imagePicker: _Picker(() {
        selections++;
        return pending.future;
      })),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('event-photo-picker'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(selections, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final firstResponse in [201, 503, 401, 200]) {
    testWidgets(
        'photo multipart upload ($firstResponse) never drops a failed photo',
        (tester) async {
      var uploads = 0;
      final client = MockClient((request) async {
        expect(request.url.path, '/uploads/image');
        expect(request.headers['Authorization'], 'Bearer unit-test-token');
        expect(
            latin1.decode(request.bodyBytes), contains('filename="event.png"'));
        expect(latin1.decode(request.bodyBytes),
            contains('content-type: image/png'));
        expect(request.bodyBytes, containsAllInOrder(_png));
        uploads++;
        final status = uploads == 1 ? firstResponse : 201;
        return http.Response(
          status == 200 ? '{}' : '{"url":"https://images.example/event.png"}',
          status,
        );
      });
      addTearDown(client.close);
      final backend = _Backend(BackendApiClient(
        baseUrl: 'https://backend.example',
        authTokenProvider: () async => 'unit-test-token',
        requireAuthToken: true,
        httpClient: client,
      ));
      await tester.pumpWidget(MaterialApp(
          home: CreateEventScreen(
        imagePicker: _Picker(() async => photo('event.png')),
        flyerScanner: _Scanner(),
        eventBackendService: backend,
        eventService: EventService(backend: backend),
      )));
      await tester.pumpAndSettle();
      await _fill(tester);
      await _pick(tester);
      await _publish(tester);
      if (firstResponse != 201) {
        expect(backend.created, isEmpty);
        expect(find.text(_text('event_action_failed')), findsOneWidget);
        expect(find.byType(CreateEventScreen), findsOneWidget);
        await _publish(tester);
        expect(uploads, 2);
      } else {
        expect(uploads, 1);
      }
      expect(backend.created, hasLength(1));
      expect(
          backend.created.single.photoUrl, 'https://images.example/event.png');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('publishing without an optional photo performs no upload',
      (tester) async {
    final client = MockClient((_) async {
      fail('No upload expected without a photo');
    });
    addTearDown(client.close);
    final backend = _Backend(BackendApiClient(
      baseUrl: 'https://backend.example',
      httpClient: client,
    ));
    await tester.pumpWidget(MaterialApp(
        home: CreateEventScreen(
      flyerScanner: _Scanner(),
      eventService: EventService(backend: backend),
      eventBackendService: backend,
    )));
    await tester.pumpAndSettle();
    await _fill(tester);
    await _publish(tester);
    expect(backend.created.single.photoUrl, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
