import 'package:parentpeak/config/api_config.dart';

import 'backend_contract_utils.dart';

class TodoContract {
  static String get todosPath => APIConfig.getBackendTodosPath();

  static String todoByIdPath(String id) {
    final base = todosPath.endsWith('/')
        ? todosPath.substring(0, todosPath.length - 1)
        : todosPath;
    return '$base/$id';
  }

  static List<Map<String, dynamic>> parseList(dynamic payload, {bool strict = false}) {
    final raw = extractListFromPayload(
        payload, const ['items', 'todos', 'data', 'results'], strict: strict);
    return raw.map(normalize).toList();
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final nowId = DateTime.now().microsecondsSinceEpoch.toString();
    return {
      'id': pickString(raw, const ['id', '_id', 'uuid'], nowId),
      'title': pickString(raw, const ['title', 'name', 'text'], ''),
      'done': pickBool(raw, const ['done', 'completed', 'isDone'], false),
      'assignee': pickString(raw,
          const ['assignee', 'assigneeName', 'owner', 'person'], 'Familie'),
      'category':
          pickString(raw, const ['category', 'type', 'group'], 'Allgemein'),
    };
  }

  static Map<String, dynamic>? parseSingleItem(dynamic payload) {
    final item = extractItemFromPayload(
        payload, const ['item', 'todo', 'data', 'result']);
    if (item == null) return null;
    return normalize(item);
  }

  static Map<String, dynamic> buildCreatePayload({
    required String title,
    required String assignee,
    required String category,
  }) {
    return {
      'title': title,
      'notes': '',
      'assigneeName': assignee,
      'assigneeRole': assignee.toLowerCase() == 'familie' ? 'family' : 'parent',
      'category': category,
      'priority': 'medium',
      'completed': false,
      'schemaVersion': APIConfig.getBackendApiVersion(),
    };
  }

  static Map<String, dynamic> buildUpdatePayload({
    required bool done,
  }) {
    return {
      'completed': done,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': APIConfig.getBackendApiVersion(),
    };
  }
}
