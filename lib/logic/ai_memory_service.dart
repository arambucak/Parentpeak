import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/models/ai_memory.dart';

/// Client für das KI-Gedächtnis (Settings, Kinderprofile, Memory-Items).
/// Alle Endpunkte verlangen serverseitig einen gültigen Firebase-Token.
class AiMemoryService {
  AiMemoryService({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendServiceFactory.createApiClient();
  final BackendApiClient? _apiClient;

  bool get isEnabled => _apiClient != null;

  Future<AiMemorySettings> getSettings() async {
    final response = await _requireClient().getJson('/ai/settings');
    return AiMemorySettings.fromJson(
        Map<String, dynamic>.from(response as Map));
  }

  Future<AiMemorySettings> setEnabled(bool enabled) async {
    final response = await _requireClient().putJson('/ai/settings', {
      'enabled': enabled,
    });
    return AiMemorySettings.fromJson(
        Map<String, dynamic>.from(response as Map));
  }

  Future<List<AiChildProfile>> getChildren() async {
    final response = await _requireClient().getJson('/ai/children');
    return _parseItems(response, 'items', AiChildProfile.fromJson);
  }

  Future<AiChildProfile> createChild({
    required String name,
    DateTime? birthDate,
    String? gender,
  }) async {
    final response = await _requireClient().postJson('/ai/children', {
      'name': name.trim(),
      if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
      if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
    });
    return AiChildProfile.fromJson(
        Map<String, dynamic>.from(response['item'] as Map));
  }

  Future<AiChildProfile> updateChild(
    String childId, {
    String? name,
    DateTime? birthDate,
    String? gender,
  }) async {
    final response = await _requireClient().putJson('/ai/children/$childId', {
      if (name != null) 'name': name.trim(),
      if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
      if (gender != null) 'gender': gender.trim(),
    });
    return AiChildProfile.fromJson(
        Map<String, dynamic>.from(response['item'] as Map));
  }

  Future<void> deleteChild(String childId) {
    return _requireClient().delete('/ai/children/$childId');
  }

  Future<List<AiMemoryItem>> getMemory(String childId) async {
    final response =
        await _requireClient().getJson('/ai/children/$childId/memory');
    return _parseItems(response, 'items', AiMemoryItem.fromJson);
  }

  Future<AiMemoryItem> saveMemory(
    String childId, {
    required String category,
    required String key,
    required String value,
    String status = 'confirmed',
  }) async {
    final response = await _requireClient().postJson(
      '/ai/children/$childId/memory',
      {
        'category': category,
        'key': key,
        'value': value,
        'status': status,
      },
    );
    return AiMemoryItem.fromJson(
        Map<String, dynamic>.from(response['item'] as Map));
  }

  Future<void> deleteMemory(String childId, String itemId) {
    return _requireClient().delete('/ai/children/$childId/memory/$itemId');
  }

  /// Wählt das aktive Kind-Profil für den Chat: null, wenn das Gedächtnis AUS
  /// ist oder keine Kinder existieren; sonst das zuletzt aktualisierte (die
  /// Liste kommt bereits updatedAt-absteigend vom Server, also das erste).
  /// Reine, seiteneffektfreie Auswahl-Logik — getrennt testbar.
  static String? resolveActiveChildId({
    required bool memoryEnabled,
    required List<AiChildProfile> children,
  }) {
    if (!memoryEnabled || children.isEmpty) return null;
    final firstWithId = children.where((child) => child.id.trim().isNotEmpty);
    return firstWithId.isEmpty ? null : firstWithId.first.id;
  }

  BackendApiClient _requireClient() {
    final client = _apiClient;
    if (client == null) {
      throw StateError('Backend-URL nicht konfiguriert.');
    }
    return client;
  }

  List<T> _parseItems<T>(
    dynamic response,
    String key,
    T Function(Map<String, dynamic>) parser,
  ) {
    final rawItems = response is Map ? response[key] : null;
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => parser(Map<String, dynamic>.from(item)))
        .toList();
  }
}
