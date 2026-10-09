import 'backend_api_client.dart';
import 'contracts/shopping_contract.dart';
import 'family_backend_scope.dart';
import 'profile_account_store.dart';

class ShoppingBackendService {
  ShoppingBackendService({this.apiClient, ProfileAccountStore? accountStore})
    : _scope = FamilyBackendScope(accountStore: accountStore);

  final BackendApiClient? apiClient;
  final FamilyBackendScope _scope;
  String? lastSyncError;

  Future<List<Map<String, dynamic>>> fetchItems({
    ProfileAccountTicket? ticket,
  }) async {
    lastSyncError = null;
    if (apiClient == null) {
      lastSyncError = 'Shopping-Backend ist nicht konfiguriert.';
      throw StateError(lastSyncError!);
    }

    try {
      final payload = await _scope
          .requireClient(apiClient, ticket)
          .getJson(ShoppingContract.shoppingPath);
      return ShoppingContract.parseList(payload, strict: true);
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Server-Sync fehlgeschlagen',
        error: e,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addItem({
    required String name,
    required String category,
    ProfileAccountTicket? ticket,
  }) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Shopping-Backend ist nicht konfiguriert.');
    }

    try {
      final requestBody = ShoppingContract.buildCreatePayload(
        name: name,
        category: category,
      );
      final payload = await _scope
          .requireClient(apiClient, ticket)
          .postJsonAny(ShoppingContract.shoppingPath, requestBody);
      final normalized = ShoppingContract.parseSingleItem(payload);
      if (normalized == null) {
        throw StateError('Ungueltige Shopping-Antwort vom Server.');
      }
      return normalized;
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Shopping-Item konnte nicht auf Server gespeichert werden',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> updateChecked(
    String id,
    bool checked, {
    ProfileAccountTicket? ticket,
  }) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Shopping-Backend ist nicht konfiguriert.');
    }

    try {
      await _scope
          .requireClient(apiClient, ticket)
          .putJson(
            ShoppingContract.itemByIdPath(id),
            ShoppingContract.buildUpdatePayload(checked: checked),
          );
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Shopping-Status konnte nicht synchronisiert werden',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> deleteItem(String id, {ProfileAccountTicket? ticket}) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Shopping-Backend ist nicht konfiguriert.');
    }

    try {
      await _scope
          .requireClient(apiClient, ticket)
          .delete(ShoppingContract.itemByIdPath(id));
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Shopping-Item konnte nicht auf Server gelöscht werden',
        error: e,
      );
      rethrow;
    }
  }

  String _friendlySyncError({required String action, required Object error}) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('handshakeexception') ||
        raw.contains('tls') ||
        raw.contains('ssl') ||
        raw.contains('certificate')) {
      return 'Server-Verbindung aktuell nicht sicher verfuegbar.';
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
}
