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
    r'\b[\p{L}][\p{L}\s.-]{1,40}(?:straße|straße|weg|allee|platz|gasse|ufer|ring|chaussee)\s+\d+[a-zA-Z]?\b',
    unicode: true,
    caseSensitive: false,
  );

  static final RegExp _postalCodePattern = RegExp(r'\b\d{5}\b');

  // Relation labels are case-insensitive; name capitalization is checked
  // separately so ordinary verbs after a relation are not treated as names.
  static final RegExp _childNamePattern = RegExp(
    r'(?<![\p{L}\p{N}])'
    r'(?:kind|sohn|tochter|child|son|daughter|çocuk|çocuğum|çocuğumuz|oğlum|oğlumuz|kızım|kızımız|zarok|zarokê|kurê|keça)'
    r'(?:\s+(?:heißt|heisst|named|called|adlı|isimli|min|me))?'
    r'(?:\s*[:\-]\s*|\s+)'
    r"([\p{L}][\p{L}\p{M}]*(?:[-’'][\p{L}][\p{L}\p{M}]*)*)"
    r'(?![\p{L}\p{N}])',
    unicode: true,
    caseSensitive: false,
  );

  static final RegExp _capitalizedName = RegExp(r'^\p{Lu}', unicode: true);
  static const _notNames = {
    'ich', 'wir', 'er', 'sie', 'es', 'du', 'das', 'die', 'der', 'mein', 'meine',
    'unser', 'unsere', 'alter', 'morgen', 'heute', 'i', 'we', 'he', 'she',
    'they', 'the', 'my', 'our', 'age', 'biz', 'bu', 'yaş', 'yaşı',
    'ez', 'em', 'ew', 'temen',
  };

  static Set<String> _childNames(Iterable<String> texts) => {
    for (final text in texts)
      for (final match in _childNamePattern.allMatches(text))
        if (_capitalizedName.hasMatch(match.group(1)!) &&
            !_notNames.contains(match.group(1)!.toLowerCase()))
          match.group(1)!,
  };

  static String _replaceNames(String text, Set<String> names) {
    final ordered = names.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in ordered) {
      text = text.replaceAll(
        RegExp('(?<![\\p{L}\\p{N}\\[])${RegExp.escape(name)}(?![\\p{L}\\p{N}\\]])',
          unicode: true, caseSensitive: false),
        '[KINDNAME]',
      );
    }
    return text;
  }

  static String sanitizeForAi(String input) {
    return _sanitize(input, _childNames([input]));
  }

  static String _sanitize(String input, Set<String> names) {
    var text = input.trim();
    if (text.isEmpty) return text;

    text = _replaceNames(text, names);
    text = text.replaceAll(_emailPattern, '[EMAIL]');
    text = text.replaceAll(_coordinatePattern, '[KOORDINATEN]');
    text = text.replaceAll(_streetPattern, '[ADRESSE]');
    text = text.replaceAll(_postalCodePattern, '[PLZ]');
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
    final names = _childNames(history.map((item) => item['content'] ?? ''));
    return history
        .map(
          (item) => {
            'role': item['role'] ?? 'user',
            'content': _sanitize(item['content'] ?? '', names),
          },
        )
        .toList(growable: false);
  }
}
