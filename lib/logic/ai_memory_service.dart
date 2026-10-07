import 'dart:convert';

import 'package:parentpeak/logic/chat_memory_consent.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/models/ai_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryLocalNameWriteException implements Exception {
  const MemoryLocalNameWriteException([this.cause]);
  final Object? cause;

  @override
  String toString() =>
      'Neutral Memory profile saved; local display name not acknowledged.';
}

/// Client für das KI-Gedächtnis (Settings, Kinderprofile, Memory-Items).
/// Alle Endpunkte verlangen serverseitig einen gültigen Firebase-Token.
class AiMemoryService {
  AiMemoryService({
    BackendApiClient? apiClient,
    ChatAccountStore? accountStore,
    ChatMemoryConsent? consent,
    Future<bool> Function(String key, String value)? persistName,
  }) : _apiClient = apiClient ?? BackendServiceFactory.createApiClient(),
       accountStore = accountStore ?? ChatAccountStore.instance,
       consent = consent ?? ChatMemoryConsent.instance,
       _persistName = persistName;
  final BackendApiClient? _apiClient;
  final ChatAccountStore accountStore;
  final ChatMemoryConsent consent;
  final Future<bool> Function(String key, String value)? _persistName;

  Future<T> _request<T>(Future<T> Function(BackendApiClient) operation) async {
    final ticket = accountStore.ticket;
    final client = _requireClient().withRequestGuard(
      () => accountStore.require(ticket),
    );
    final result = await operation(client);
    accountStore.require(ticket);
    return result;
  }

  bool get isEnabled => _apiClient != null;

  Future<AiMemorySettings> getSettings() async {
    final ticket = accountStore.ticket;
    final response = await _request((client) => client.getJson('/ai/settings'));
    final settings = AiMemorySettings.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    final allowed = await consent.hasConsent();
    accountStore.require(ticket);
    return AiMemorySettings(enabled: settings.enabled && allowed);
  }

  Future<AiMemorySettings> setEnabled(bool enabled) async {
    final ticket = accountStore.ticket;
    if (!enabled) consent.block(ticket.scope);
    if (enabled) await consent.require(ticket.scope);
    accountStore.require(ticket);
    final revision = consent.revision(ticket.scope);
    final response = await _request(
      (client) => client
          .withRequestGuard(() {
            if (enabled) consent.requireRevision(ticket.scope, revision);
          })
          .putJson('/ai/settings', {
            'enabled': enabled,
            if (enabled) 'memoryConsentVersion': ChatMemoryConsent.version,
          }),
    );
    accountStore.require(ticket);
    if (enabled) await consent.require(ticket.scope);
    final settings = AiMemorySettings.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    if (settings.enabled != enabled) {
      throw StateError('Memory activation was not acknowledged.');
    }
    if (!enabled) await consent.revoke(ticket.scope);
    accountStore.require(ticket);
    return settings;
  }

  Future<T> _write<T>(Future<T> Function(BackendApiClient) operation) async {
    final ticket = accountStore.ticket;
    await consent.require(ticket.scope);
    accountStore.require(ticket);
    final revision = consent.revision(ticket.scope);
    final result = await _request(
      (client) => operation(
        client.withRequestGuard(() {
          accountStore.require(ticket);
          consent.requireRevision(ticket.scope, revision);
        }),
      ),
    );
    await consent.require(ticket.scope);
    consent.requireRevision(ticket.scope, revision);
    accountStore.require(ticket);
    return result;
  }

  String _nameKey(ChatAccountTicket ticket, String id) =>
      'chat.memory_names.v1.${ticket.scope}.${Uri.encodeComponent(id)}';

  Future<void> _saveLocalName(
    ChatAccountTicket ticket,
    String id,
    String name,
  ) async {
    accountStore.require(ticket);
    await consent.require(ticket.scope);
    accountStore.require(ticket);
    final revision = consent.revision(ticket.scope);
    final prefs = await SharedPreferences.getInstance();
    accountStore.require(ticket);
    consent.requireRevision(ticket.scope, revision);
    final key = _nameKey(ticket, id);
    final value = jsonEncode(name.trim());
    final persist = _persistName;
    bool written;
    try {
      written = persist == null
          ? await prefs.setString(key, value)
          : await persist(key, value);
    } catch (error) {
      await prefs.reload();
      throw MemoryLocalNameWriteException(error);
    }
    if (!written) {
      await prefs.reload();
      throw const MemoryLocalNameWriteException();
    }
    accountStore.require(ticket);
    await consent.require(ticket.scope);
    consent.requireRevision(ticket.scope, revision);
    accountStore.require(ticket);
  }

  Future<AiChildProfile> _localChild(
    ChatAccountTicket ticket,
    AiChildProfile child,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    accountStore.require(ticket);
    final raw = prefs.getString(_nameKey(ticket, child.id));
    final name = raw == null ? child.name : jsonDecode(raw);
    if (name is! String) {
      throw const FormatException('Invalid local Memory name.');
    }
    return AiChildProfile(
      id: child.id,
      userId: child.userId,
      name: name,
      birthDate: child.birthDate,
      gender: child.gender,
      memoryItems: child.memoryItems,
    );
  }

  Future<List<AiChildProfile>> getChildren() async {
    final ticket = accountStore.ticket;
    final response = await _request((client) => client.getJson('/ai/children'));
    final children = _parseItems(response, 'items', AiChildProfile.fromJson);
    if (children.any((child) => child.id.trim().isEmpty) ||
        children.map((child) => child.id).toSet().length != children.length) {
      throw const FormatException('Invalid Memory child identifiers.');
    }
    return Future.wait(children.map((child) => _localChild(ticket, child)));
  }

  Future<AiChildProfile> createChild({
    required String name,
    DateTime? birthDate,
    String? gender,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 100) {
      throw ArgumentError.value(
        name.length,
        'name length',
        'Expected 1 to 100 characters.',
      );
    }
    final ticket = accountStore.ticket;
    final response = await _write(
      (client) => client.postJson('/ai/children', {
        'name': '[CHILD_1]',
        'memoryConsentVersion': ChatMemoryConsent.version,
        if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
        if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
      }),
    );
    final child = AiChildProfile.fromJson(
      Map<String, dynamic>.from(response['item'] as Map),
    );
    if (child.id.trim().isEmpty) {
      throw const FormatException('Missing Memory child id.');
    }
    await _saveLocalName(ticket, child.id, name);
    return _localChild(ticket, child);
  }

  Future<AiChildProfile> updateChild(
    String childId, {
    String? name,
    DateTime? birthDate,
    String? gender,
  }) async {
    if (name != null && (name.trim().isEmpty || name.trim().length > 100)) {
      throw ArgumentError.value(
        name.length,
        'name length',
        'Expected 1 to 100 characters.',
      );
    }
    final ticket = accountStore.ticket;
    final response = await _write(
      (client) => client.putJson('/ai/children/$childId', {
        'memoryConsentVersion': ChatMemoryConsent.version,
        if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
        if (gender != null) 'gender': gender.trim(),
      }),
    );
    final child = AiChildProfile.fromJson(
      Map<String, dynamic>.from(response['item'] as Map),
    );
    if (child.id != childId) {
      throw const FormatException('Unexpected Memory child id.');
    }
    if (name != null) await _saveLocalName(ticket, child.id, name);
    return _localChild(ticket, child);
  }

  Future<void> deleteChild(String childId) async {
    final ticket = accountStore.ticket;
    await _request((client) => client.delete('/ai/children/$childId'));
    accountStore.require(ticket);
    final prefs = await SharedPreferences.getInstance();
    accountStore.require(ticket);
    if (!await prefs.remove(_nameKey(ticket, childId))) {
      await prefs.reload();
      throw StateError(
        'The server profile was deleted, but the local display name could not be removed.',
      );
    }
    accountStore.require(ticket);
  }

  Future<List<AiMemoryItem>> getMemory(String childId) async {
    final response = await _request(
      (client) => client.getJson('/ai/children/$childId/memory'),
    );
    return _parseItems(response, 'items', AiMemoryItem.fromJson);
  }

  Future<AiMemoryItem> saveMemory(
    String childId, {
    required String category,
    required String key,
    required String value,
    String status = 'confirmed',
  }) async {
    final ticket = accountStore.ticket;
    await consent.require(ticket.scope);
    accountStore.require(ticket);
    final children = await getChildren();
    accountStore.require(ticket);
    children.sort((a, b) => b.name.length.compareTo(a.name.length));
    String minimize(String text) {
      for (final child in children) {
        if (child.name.isNotEmpty && !child.name.startsWith('[CHILD')) {
          text = text.replaceAll(
            RegExp(
              '(?<![\\p{L}\\p{N}])${RegExp.escape(child.name)}(?![\\p{L}\\p{N}])',
              caseSensitive: false,
              unicode: true,
            ),
            child.id == childId ? '[THIS_CHILD]' : '[OTHER_CHILD]',
          );
        }
      }
      return text;
    }

    final response = await _write(
      (client) => client.postJson('/ai/children/$childId/memory', {
        'category': minimize(category),
        'key': minimize(key),
        'value': minimize(value),
        'status': status,
        'memoryConsentVersion': ChatMemoryConsent.version,
      }),
    );
    return AiMemoryItem.fromJson(
      Map<String, dynamic>.from(response['item'] as Map),
    );
  }

  Future<void> deleteMemory(String childId, String itemId) {
    return _request(
      (client) => client.delete('/ai/children/$childId/memory/$itemId'),
    );
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
    if (rawItems is! List || rawItems.any((item) => item is! Map)) {
      throw const FormatException('Invalid Memory response items.');
    }
    return rawItems
        .map((item) => parser(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
