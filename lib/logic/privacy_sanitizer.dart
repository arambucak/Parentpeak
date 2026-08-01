class PrivacySanitizer {
  const PrivacySanitizer._();

  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  static final RegExp _phonePattern = RegExp(
    r'(?:(?:\+|00)\d{1,3}[\s/-]?)?(?:\(?\d{2,5}\)?[\s/-]?)?\d{3,4}[\s/-]?\d{3,5}\b',
    caseSensitive: false,
  );

  static final RegExp _coordinatePattern = RegExp(
    r'\b-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}\b',
  );

  static final RegExp _streetPattern = RegExp(
    r'\b[\p{L}][\p{L}\s.-]{1,40}(?:strasse|straße|weg|allee|platz|gasse|ufer|ring|chaussee)\s+\d+[a-zA-Z]?\b',
    unicode: true,
    caseSensitive: false,
  );

  static final RegExp _postalCodePattern = RegExp(r'\b\d{5}\b');

  static final RegExp _childNamePattern = RegExp(
    r'\b(?:mein(?:e|er|em)?\s+)?(?:kind|sohn|tochter)\s+([A-ZÄÖÜ][a-zäöüß]{1,20})\b',
    unicode: true,
  );

  static String sanitizeForAi(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    text = text.replaceAll(_emailPattern, '[EMAIL]');
    text = text.replaceAll(_coordinatePattern, '[KOORDINATEN]');
    text = text.replaceAll(_streetPattern, '[ADRESSE]');
    text = text.replaceAll(_postalCodePattern, '[PLZ]');
    text = text.replaceAllMapped(_childNamePattern, (m) {
      final prefix = m.group(0) ?? '';
      final name = m.group(1) ?? '';
      return prefix.replaceFirst(name, '[KINDNAME]');
    });

    // Phone replacement intentionally last to avoid partial replacements
    // in already redacted placeholders.
    text = text.replaceAllMapped(_phonePattern, (m) {
      final value = m.group(0) ?? '';
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7) return value;
      return '[TELEFON]';
    });

    return text;
  }

  static List<Map<String, String>> sanitizeHistoryForAi(
    List<Map<String, String>> history,
  ) {
    return history
        .map(
          (item) => {
            'role': item['role'] ?? 'user',
            'content': sanitizeForAi(item['content'] ?? ''),
          },
        )
        .toList(growable: false);
  }
}