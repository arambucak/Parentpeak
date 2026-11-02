import 'package:parentpeak/config/api_config.dart';

import 'backend_api_client.dart';

class PhotoBackendService {
  PhotoBackendService({this.apiClient});

  final BackendApiClient? apiClient;
  String? lastSyncError;

  Future<List<Map<String, dynamic>>> fetchAlbums() async {
    lastSyncError = null;

    if (apiClient == null) {
      lastSyncError = 'Foto-Backend ist nicht konfiguriert.';
      return <Map<String, dynamic>>[];
    }

    try {
      final payload = await apiClient!.getJson(APIConfig.getBackendPhotosPath());
      return _parseAlbumList(payload);
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Server-Sync fehlgeschlagen',
        error: e,
      );
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> addAlbum({required String title}) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Foto-Backend ist nicht konfiguriert.');
    }

    try {
      final payload = await apiClient!.postJsonAny(
        APIConfig.getBackendPhotosPath(),
        {
          'familyId': APIConfig.getBackendFamilyId(),
          'title': title,
          'photoCount': 0,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'schemaVersion': APIConfig.getBackendApiVersion(),
        },
      );

      final normalized = _parseSingleAlbum(payload);
      if (normalized == null) {
        throw StateError('Ungültige Album-Antwort vom Server.');
      }
      return normalized;
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Foto-Album konnte nicht auf dem Server gespeichert werden',
        error: e,
      );
      rethrow;
    }
  }

  String _friendlySyncError({
    required String action,
    required Object error,
  }) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('handshakeexception') ||
        raw.contains('tls') ||
        raw.contains('ssl') ||
        raw.contains('certificate')) {
      return 'Server-Verbindung aktuell nicht sicher verfügbar.';
    }

    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection refused') ||
        raw.contains('timed out') ||
        raw.contains('timeout')) {
      return 'Keine Verbindung zum Server.';
    }

    return '$action: $error';
  }

  List<Map<String, dynamic>> _parseAlbumList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map>().map((e) => _normalizeAlbum(Map<String, dynamic>.from(e))).toList();
    }

    if (payload is Map) {
      final mapPayload = Map<String, dynamic>.from(payload);
      for (final key in const ['items', 'albums', 'photos', 'data', 'results']) {
        final value = mapPayload[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => _normalizeAlbum(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    }

    return [];
  }

  Map<String, dynamic>? _parseSingleAlbum(dynamic payload) {
    if (payload is Map) {
      final mapPayload = Map<String, dynamic>.from(payload);
      final direct = mapPayload['album'] ?? mapPayload['item'] ?? mapPayload['data'];
      if (direct is Map) {
        return _normalizeAlbum(Map<String, dynamic>.from(direct));
      }
      return _normalizeAlbum(mapPayload);
    }
    return null;
  }

  Map<String, dynamic> _normalizeAlbum(Map<String, dynamic> raw) {
    final id = (raw['id'] ?? raw['_id'] ?? raw['uuid'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString();
    final title = (raw['title'] ?? raw['name'] ?? 'Album').toString();
    final countRaw = raw['count'] ?? raw['photoCount'] ?? raw['items'] ?? 0;
    final count = countRaw is num ? countRaw.toInt() : int.tryParse(countRaw.toString()) ?? 0;
    final date = (raw['date'] ?? raw['createdAt'] ?? raw['updatedAt'] ?? DateTime.now().toIso8601String()).toString();

    return {
      'id': id,
      'title': title,
      'count': count,
      'date': date,
    };
  }

}
