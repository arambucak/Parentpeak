import 'package:parentpeak/config/api_config.dart';

import 'backend_contract_utils.dart';

class ShoppingContract {
  static String get shoppingPath => APIConfig.getBackendShoppingPath();

  static String itemByIdPath(String id) {
    final base = shoppingPath.endsWith('/')
        ? shoppingPath.substring(0, shoppingPath.length - 1)
        : shoppingPath;
    return '$base/$id';
  }

  static List<Map<String, dynamic>> parseList(dynamic payload, {bool strict = false}) {
    final raw = extractListFromPayload(
        payload, const ['items', 'shopping', 'data', 'results'], strict: strict);
    return raw.map(normalize).toList();
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> raw) {
    final nowId = DateTime.now().microsecondsSinceEpoch.toString();
    return {
      'id': pickString(raw, const ['id', '_id', 'uuid'], nowId),
      'name': pickString(raw, const ['name', 'title', 'label'], ''),
      'checked': pickBool(raw, const ['checked', 'done', 'purchased'], false),
      'category':
          pickString(raw, const ['category', 'group', 'type'], 'Allgemein'),
    };
  }

  static Map<String, dynamic>? parseSingleItem(dynamic payload) {
    final item = extractItemFromPayload(
        payload, const ['item', 'shopping', 'data', 'result']);
    if (item == null) return null;
    return normalize(item);
  }

  static Map<String, dynamic> buildCreatePayload({
    required String name,
    required String category,
  }) {
    return {
      'name': name,
      'quantity': 1,
      'unit': 'Stueck',
      'category': category,
      'checked': false,
      'preferredStore': '',
      'notes': '',
      'schemaVersion': APIConfig.getBackendApiVersion(),
    };
  }

  static Map<String, dynamic> buildUpdatePayload({
    required bool checked,
  }) {
    return {
      'checked': checked,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': APIConfig.getBackendApiVersion(),
    };
  }
}
