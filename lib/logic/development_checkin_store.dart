import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistenz für den Entwicklungs-Check.
///
/// WICHTIG (Eltern-Vertrauen): Antworten, Scores und der Verlauf werden pro
/// Altersgruppe (`ageGroupId`) GETRENNT gespeichert. Ein Kind, das über eine
/// Altersgrenze wächst, bekommt neue Fragen — die alten Antworten dürfen diesen
/// neuen Fragen NICHT zugeordnet werden (sonst entstünden falsche
/// Entwicklungsberichte). Jede Altersgruppe hat deshalb ihren eigenen
/// Antworten-Satz und ihren eigenen Score-Verlauf.
///
/// Alle Daten bleiben lokal (SharedPreferences) — keine sensiblen Kinderdaten
/// zum Backend.
class DevelopmentCheckinStore {
  DevelopmentCheckinStore({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  final SharedPreferences? _injectedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  // Antworten pro Altersgruppe. Legacy-Key 'dev.answers.v3' war global (ohne
  // Altersgruppe) und wird NICHT mehr gelesen — er konnte Antworten einer
  // Altersgruppe fälschlich auf die Fragen einer anderen abbilden.
  static String _answersKey(String ageGroupId) => 'dev.answers.v4.$ageGroupId';

  // Verlauf (vorheriger Score-Snapshot) pro Altersgruppe.
  static String _historyKey(String ageGroupId) =>
      'dev.score_history.v1.$ageGroupId';

  /// Lädt die gespeicherten Antworten für genau diese Altersgruppe.
  /// Rückgabe: Map von Frage-Key ("domainId_index") -> Antwortwert (0/1/2).
  Future<Map<String, int>> loadAnswers(String ageGroupId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_answersKey(ageGroupId));
    final result = <String, int>{};
    if (raw == null || raw.trim().isEmpty) return result;
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length == 2) {
        final value = int.tryParse(kv[1]);
        if (value != null) result[kv[0]] = value;
      }
    }
    return result;
  }

  /// Speichert die Antworten für genau diese Altersgruppe.
  Future<void> saveAnswers(String ageGroupId, Map<String, int> answers) async {
    final prefs = await _prefs;
    final encoded = answers.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_answersKey(ageGroupId), encoded);
  }

  /// Löscht die Antworten einer Altersgruppe (z.B. "nochmal starten").
  Future<void> clearAnswers(String ageGroupId) async {
    final prefs = await _prefs;
    await prefs.remove(_answersKey(ageGroupId));
  }

  /// Liefert den zuletzt gespeicherten Score-Snapshot für diese Altersgruppe
  /// (für den Vorher-Nachher-Vergleich) — oder null, wenn es noch keinen gibt.
  Future<DevelopmentScoreSnapshot?> loadPreviousSnapshot(
      String ageGroupId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_historyKey(ageGroupId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DevelopmentScoreSnapshot.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('DevelopmentCheckinStore.loadPreviousSnapshot(): $e');
    }
    return null;
  }

  /// Speichert einen neuen Score-Snapshot als "zuletzt abgeschlossen" für diese
  /// Altersgruppe. Wird beim Erstellen eines Berichts aufgerufen, DAMIT der
  /// NÄCHSTE Check einen echten Vergleich zeigen kann.
  Future<void> saveSnapshot(
      String ageGroupId, DevelopmentScoreSnapshot snapshot) async {
    final prefs = await _prefs;
    await prefs.setString(
        _historyKey(ageGroupId), jsonEncode(snapshot.toJson()));
  }
}

/// Ein gespeicherter Score-Stand eines abgeschlossenen Checks.
@immutable
class DevelopmentScoreSnapshot {
  const DevelopmentScoreSnapshot({required this.scores, required this.date});

  /// Score je Entwicklungsbereich (domainId -> 0.0..1.0).
  final Map<String, double> scores;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'scores': scores,
      };

  factory DevelopmentScoreSnapshot.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'];
    final scores = <String, double>{};
    if (rawScores is Map) {
      rawScores.forEach((key, value) {
        final numValue = value is num ? value.toDouble() : null;
        if (numValue != null) scores[key.toString()] = numValue;
      });
    }
    return DevelopmentScoreSnapshot(
      scores: scores,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
