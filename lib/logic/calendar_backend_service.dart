import 'package:firebase_auth/firebase_auth.dart';

import 'backend_api_client.dart';
import 'contracts/calendar_contract.dart';

class CalendarBackendService {
  CalendarBackendService({this.apiClient});

  final BackendApiClient? apiClient;
  String? lastSyncError;

  Future<List<Map<String, dynamic>>> fetchEvents() async {
    lastSyncError = null;
    if (apiClient == null) {
      lastSyncError = 'Kalender-Backend ist nicht konfiguriert.';
      return <Map<String, dynamic>>[];
    }

    try {
      // Pass userId so the backend returns only this user's events
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final path = userId.isNotEmpty
          ? '${CalendarContract.eventsPath}?userId=${Uri.encodeComponent(userId)}'
          : CalendarContract.eventsPath;
      final payload = await apiClient!.getJson(path);
      return CalendarContract.parseList(payload);
    } catch (e) {
      lastSyncError = 'Server derzeit nicht erreichbar.';
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> addEvent(Map<String, dynamic> event) async {
    lastSyncError = null;
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
    if (apiClient == null) return;
    try {
      await apiClient!.deleteJson('${CalendarContract.eventsPath}/$id', {});
    } catch (e) {
      lastSyncError = 'Termin konnte nicht gelöscht werden.';
      rethrow;
    }
  }
}
