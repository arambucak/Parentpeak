import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/calendar_backend_service.dart';

/// Datenschutz: Der Kalender-Sync lässt sich abschalten. Ist er aus, verlässt
/// kein Termin das Gerät — fetchEvents/addEvent/deleteEvent machen keinen
/// Backend-Call (apiClient ist hier null, sodass jeder echte Call auffiele).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarBackendService Sync-Präferenz', () {
    test('Default ist an (Sync aktiv)', () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.loadSyncPreference();
      expect(CalendarBackendService.syncEnabled, isTrue);
    });

    test('setSyncEnabled(false) wird persistiert und geladen', () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(false);
      expect(CalendarBackendService.syncEnabled, isFalse);
      // Simuliert App-Neustart: Flag bleibt aus.
      await CalendarBackendService.loadSyncPreference();
      expect(CalendarBackendService.syncEnabled, isFalse);
    });

    test('Sync aus: fetchEvents liefert leer ohne Backend-Call', () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(false);
      // apiClient null + sync aus: kein lastSyncError (kein Call versucht).
      final service = CalendarBackendService();
      final events = await service.fetchEvents();
      expect(events, isEmpty);
      expect(service.lastSyncError, isNull);
    });

    test('Sync aus: addEvent wirft nicht und sendet nichts', () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(false);
      final service = CalendarBackendService();
      // Ohne Sync kein StateError (anders als bei sync an + fehlendem Backend).
      await service.addEvent({'title': 'Test'});
      expect(service.lastSyncError, isNull);
    });

    test(
      'Sync an ohne Backend: fetchEvents meldet Konfigurationsfehler',
      () async {
        SharedPreferences.setMockInitialValues({});
        await CalendarBackendService.setSyncEnabled(true);
        final service = CalendarBackendService();
        final events = await service.fetchEvents();
        expect(events, isEmpty);
        expect(service.lastSyncError, isNotNull);
      },
    );

    test('enabled sync sends Firebase token without an owner claim', () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(true);
      final requests = <http.Request>[];
      var tokenCalls = 0;
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer firebase-a');
        expect(request.url.queryParameters.containsKey('userId'), isFalse);
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('userId'), isFalse);
          expect(body['title'], 'Test');
          return http.Response('{"item":{"id":"a"}}', 201);
        }
        return http.Response(
          request.method == 'GET' ? '{"items":[]}' : '{"deleted":"a"}',
          200,
        );
      });
      addTearDown(client.close);
      final service = CalendarBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          authToken: 'shared-backend-token',
          authTokenProvider: () async {
            tokenCalls++;
            return 'firebase-a';
          },
          httpClient: client,
        ),
      );
      await service.fetchEvents();
      await service.addEvent({'title': 'Test'});
      await service.deleteEvent('a');
      expect(requests.map((request) => request.method), [
        'GET',
        'POST',
        'DELETE',
      ]);
      expect(tokenCalls, 3);
      expect(service.lastSyncError, isNull);
    });

    test('disabled sync makes no HTTP calls or token requests', () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(false);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final service = CalendarBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          authTokenProvider: () async {
            calls++;
            return 'firebase-a';
          },
          httpClient: client,
        ),
      );
      expect(await service.fetchEvents(), isEmpty);
      await service.addEvent({'title': 'Local only'});
      await service.deleteEvent('a');
      expect(calls, 0);
      expect(service.lastSyncError, isNull);
    });

    // Flag zurücksetzen, damit andere Tests den Default sehen.
    tearDownAll(() async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(true);
    });
  });
}
