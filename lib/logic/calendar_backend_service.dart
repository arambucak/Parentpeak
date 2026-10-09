import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_client.dart';
import 'contracts/calendar_contract.dart';

class CalendarBackendService {
  CalendarBackendService({this.apiClient});

  final BackendApiClient? apiClient;
  String? lastSyncError;

  /// Datenschutz: Steuert, ob Termine zum Geräte-Sync ans Backend gehen.
  /// Standard: an (Sync-Nutzen), aber von den Eltern abschaltbar — dann
  /// bleiben alle Termine ausschließlich lokal auf dem Gerät.
  static const _syncEnabledKey = 'calendar.sync_enabled';
  static bool _syncEnabled = true;

  static bool get syncEnabled => _syncEnabled;

  /// Lädt die Sync-Präferenz (einmalig beim Start/Screen-Init).
  static Future<void> loadSyncPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _syncEnabled = prefs.getBool(_syncEnabledKey) ?? true;
  }

  /// Setzt die Sync-Präferenz und merkt sie dauerhaft.
  static Future<void> setSyncEnabled(bool enabled) async {
    _syncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);
  }

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    lastSyncError = null;
    // Sync aus → nicht vom Server laden, nur lokale Termine nutzen.
    if (!_syncEnabled) return <Map<String, dynamic>>[];
    if (apiClient == null) {
      lastSyncError = 'Kalender-Backend ist nicht konfiguriert.';
      return <Map<String, dynamic>>[];
    }

    try {
      final payload = await apiClient!.getJson(CalendarContract.eventsPath);
      return CalendarContract.parseList(payload);
    } catch (e) {
      lastSyncError = 'Server derzeit nicht erreichbar.';
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> addEvent(Map<String, dynamic> event) async {
    lastSyncError = null;
    // Sync aus → Termin verlässt das Gerät nicht (nur lokale Persistenz).
    if (!_syncEnabled) return;
    if (apiClient == null) {
      lastSyncError = 'Backend nicht konfiguriert (BACKEND_BASE_URL fehlt).';
      throw StateError(lastSyncError!);
    }

    try {
      await apiClient!.postJsonAny(
        CalendarContract.eventsPath,
        CalendarContract.buildCreatePayload(event),
      );
    } catch (e) {
      lastSyncError = e.toString();
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    lastSyncError = null;
    if (!_syncEnabled) return;
    if (apiClient == null) return;
    try {
      await apiClient!.deleteJson('${CalendarContract.eventsPath}/$id', {});
    } catch (e) {
      lastSyncError = 'Termin konnte nicht gelöscht werden.';
      rethrow;
    }
  }
}
