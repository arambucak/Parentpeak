import 'package:parentpeak/data/eltern_wissen_data.dart';
import 'package:parentpeak/models/eltern_wissen_faq.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// Fuzzy-Search Service fuer Eltern-Wissen FAQ.
///
/// Findet passende Eintraege auch bei Tippfehlern und Synonymen.
/// Filtert automatisch nach Alter der Kinder (aus Profil).
class ElternWissenService {
  static final ElternWissenService instance = ElternWissenService._();
  ElternWissenService._();

  int _childAge = 3;

  Future<void> initialize() async {
    final profile = await FamilyMatchProfile.load();
    if (profile != null && profile.children.isNotEmpty) {
      _childAge = (profile.children.first.ageMonths / 12).round().clamp(0, 18);
    }
  }

  /// Sucht nach passenden FAQ-Eintraegen.
  /// Fuzzy: Sucht in Frage, Tags, Kategorie.
  List<ElternWissenEntry> search(String query) {
    if (query.trim().length < 2) return [];
    final normalized = _normalize(query);
    final words = normalized.split(RegExp(r'\s+'));

    final scored = <_ScoredEntry>[];

    for (final entry in elternWissenData) {
      double score = 0;

      // Frage-Match
      final normQuestion = _normalize(entry.question);
      for (final word in words) {
        if (normQuestion.contains(word)) score += 3;
      }

      // Tag-Match (hoeher gewichtet — Synonyme)
      for (final tag in entry.tags) {
        final normTag = _normalize(tag);
        for (final word in words) {
          if (normTag.contains(word) || word.contains(normTag)) score += 4;
          // Fuzzy: Aehnlichkeit pruefen
          if (_isSimilar(word, normTag)) score += 2;
        }
      }

      // Kategorie-Match
      if (words.any((w) => _normalize(entry.category).contains(w))) score += 2;

      // Alters-Bonus (passt zum eigenen Kind)
      if (_childAge >= entry.minAge && _childAge <= entry.maxAge) score += 1;

      if (score > 0) scored.add(_ScoredEntry(entry, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(5).map((s) => s.entry).toList();
  }

  /// Gibt den personalisierten Impuls des Tages.
  /// Basierend auf Kind-Alter + Tag des Jahres.
  ElternWissenEntry? getDailyImpuls() {
    final ageFiltered = elternWissenData
        .where((e) => _childAge >= e.minAge && _childAge <= e.maxAge)
        .toList();
    if (ageFiltered.isEmpty) return null;
    final dayIndex = DateTime.now().difference(DateTime(2025, 1, 1)).inDays;
    return ageFiltered[dayIndex % ageFiltered.length];
  }

  /// Gibt alle Eintraege fuer das aktuelle Kind-Alter.
  List<ElternWissenEntry> getForCurrentAge() {
    return elternWissenData
        .where((e) => _childAge >= e.minAge && _childAge <= e.maxAge)
        .toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[äàá]'), 'a')
        .replaceAll(RegExp(r'[öòó]'), 'o')
        .replaceAll(RegExp(r'[üùú]'), 'u')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }

  /// Prueft ob zwei Woerter aehnlich genug sind (Levenshtein-Light).
  bool _isSimilar(String a, String b) {
    if (a == b) return true;
    if (a.length < 3 || b.length < 3) return false;
    // Praefix-Match (mindestens 3 Zeichen gleich am Anfang)
    final minLen = a.length < b.length ? a.length : b.length;
    int commonPrefix = 0;
    for (int i = 0; i < minLen; i++) {
      if (a[i] == b[i]) {
        commonPrefix++;
      } else {
        break;
      }
    }
    return commonPrefix >= 3;
  }
}

class _ScoredEntry {
  final ElternWissenEntry entry;
  final double score;
  const _ScoredEntry(this.entry, this.score);
}
