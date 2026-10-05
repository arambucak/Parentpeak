import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    test('Sync an ohne Backend: fetchEvents meldet Konfigurationsfehler',
        () async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(true);
      final service = CalendarBackendService();
      final events = await service.fetchEvents();
      expect(events, isEmpty);
      expect(service.lastSyncError, isNotNull);
    });

    // Flag zurücksetzen, damit andere Tests den Default sehen.
    tearDownAll(() async {
      SharedPreferences.setMockInitialValues({});
      await CalendarBackendService.setSyncEnabled(true);
    });
  });
}
