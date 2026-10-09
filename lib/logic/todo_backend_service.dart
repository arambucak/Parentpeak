import 'backend_api_client.dart';
import 'contracts/todo_contract.dart';
import 'family_backend_scope.dart';
import 'profile_account_store.dart';

class TodoBackendService {
  TodoBackendService({this.apiClient, ProfileAccountStore? accountStore})
      : _scope = FamilyBackendScope(accountStore: accountStore);

  final BackendApiClient? apiClient;
  final FamilyBackendScope _scope;
  String? lastSyncError;

  Future<List<Map<String, dynamic>>> fetchTodos({ProfileAccountTicket? ticket}) async {
    lastSyncError = null;
    if (apiClient == null) {
      lastSyncError = 'Todo-Backend ist nicht konfiguriert.';
      throw StateError(lastSyncError!);
    }

    try {
      final payload = await _scope.requireClient(apiClient, ticket).getJson(TodoContract.todosPath);
      return TodoContract.parseList(payload, strict: true);
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Server-Sync fehlgeschlagen',
        error: e,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addTodo({
    required String title,
    required String assignee,
    required String category,
    ProfileAccountTicket? ticket,
  }) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Todo-Backend ist nicht konfiguriert.');
    }

    try {
      final requestBody = TodoContract.buildCreatePayload(
        title: title,
        assignee: assignee,
        category: category,
      );
      final payload = await _scope.requireClient(apiClient, ticket).postJsonAny(
        TodoContract.todosPath,
        requestBody,
      );
      final normalized = TodoContract.parseSingleItem(payload);
      if (normalized == null) {
        throw StateError('Ungueltige Todo-Antwort vom Server.');
      }
      return normalized;
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Todo konnte nicht auf Server gespeichert werden',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> updateDone(String id, bool done, {ProfileAccountTicket? ticket}) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Todo-Backend ist nicht konfiguriert.');
    }

    try {
      await _scope.requireClient(apiClient, ticket).putJson(
        TodoContract.todoByIdPath(id),
        TodoContract.buildUpdatePayload(done: done),
      );
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Todo-Status konnte nicht synchronisiert werden',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> deleteTodo(String id, {ProfileAccountTicket? ticket}) async {
    lastSyncError = null;
    if (apiClient == null) {
      throw StateError('Todo-Backend ist nicht konfiguriert.');
    }

    try {
      await _scope.requireClient(apiClient, ticket).delete(TodoContract.todoByIdPath(id));
    } catch (e) {
      lastSyncError = _friendlySyncError(
        action: 'Todo konnte nicht auf Server gelöscht werden',
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
