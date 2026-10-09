Map<String, dynamic>? extractFirstMapByKeys(
  Map<String, dynamic> source,
  List<String> keys,
) {
  for (final key in keys) {
    final value = source[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }
  return null;
}

List<Map<String, dynamic>> extractListFromPayload(
  dynamic payload,
  List<String> candidateKeys, {
  bool strict = false,
}) {
  if (payload is List) {
    if (strict && payload.any((item) => item is! Map)) {
      throw const FormatException('Invalid backend list entries');
    }
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  if (payload is Map) {
    final mapPayload = Map<String, dynamic>.from(payload);

    for (final key in candidateKeys) {
      final value = mapPayload[key];
      if (value is List) {
        if (strict && value.any((item) => item is! Map)) {
          throw const FormatException('Invalid backend list entries');
        }
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    final nested = extractFirstMapByKeys(mapPayload, const ['data', 'result']);
    if (nested != null) {
      for (final key in candidateKeys) {
        final value = nested[key];
        if (value is List) {
          if (strict && value.any((item) => item is! Map)) {
            throw const FormatException('Invalid backend list entries');
          }
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }
  }

  if (strict) {
    throw const FormatException('Invalid backend list response');
  }
  return [];
}

Map<String, dynamic>? extractItemFromPayload(
  dynamic payload,
  List<String> candidateKeys,
) {
  if (payload is Map) {
    final mapPayload = Map<String, dynamic>.from(payload);

    for (final key in candidateKeys) {
      final value = mapPayload[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    final nested = extractFirstMapByKeys(mapPayload, const ['data', 'result']);
    if (nested != null) {
      for (final key in candidateKeys) {
        final value = nested[key];
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
    }
  }

  return null;
}

String pickString(
    Map<String, dynamic> source, List<String> keys, String fallback) {
  for (final key in keys) {
    final value = source[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return fallback;
}

bool pickBool(Map<String, dynamic> source, List<String> keys, bool fallback) {
  for (final key in keys) {
    final value = source[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
  }
  return fallback;
}
