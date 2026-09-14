import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ein einzelner "Tischmoment" — ein liebevoll festgehaltenes Abend-Gefühl.
///
/// WICHTIG: Diese Daten sind hochsensibel (Gefühle von Kindern) und bleiben
/// deshalb AUSSCHLIESSLICH lokal auf dem Gerät. Kein Backend, kein Teilen.
class TischmomentEntry {
  final String id;
  final DateTime createdAt;

  /// Optionaler Name des Kindes (aus dem Profil), zu dem der Moment gehört.
  final String childName;

  /// Die Frage des Tages, zu der geantwortet wurde.
  final String question;

  /// Schlüssel des gewählten Herz-Symbols (siehe [Tischmoment.feelings]).
  final String feelingKey;

  /// Optionaler kurzer Satz der Familie zum Moment.
  final String note;

  const TischmomentEntry({
    required this.id,
    required this.createdAt,
    this.childName = '',
    required this.question,
    required this.feelingKey,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'childName': childName,
        'question': question,
        'feelingKey': feelingKey,
        'note': note,
      };

  factory TischmomentEntry.fromJson(Map<String, dynamic> j) => TischmomentEntry(
        id: j['id'] as String? ?? '',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        childName: j['childName'] as String? ?? '',
        question: j['question'] as String? ?? '',
        feelingKey: j['feelingKey'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

/// Ein Herz-Symbol (Gefühl), das ein Kind auswählen kann.
class TischmomentFeeling {
  final String key;
  final String emoji;
  final String label;

  const TischmomentFeeling(this.key, this.emoji, this.label);
}

/// Statische Inhalte + Helfer für das Tischmoment-Ritual.
class Tischmoment {
  /// Die fünf liebevollen Gefühls-Symbole.
  static const List<TischmomentFeeling> feelings = [
    TischmomentFeeling('herz', '❤️', 'Hat mein Herz erfreut'),
    TischmomentFeeling('lecker', '😋', 'Hat lecker geschmeckt'),
    TischmomentFeeling('trost', '🫂', 'Hat mich getröstet'),
    TischmomentFeeling('abenteuer', '✨', 'War ein Abenteuer'),
    TischmomentFeeling('stolz', '🌟', 'Hat mich stolz gemacht'),
  ];

  /// Findet ein Gefühl anhand seines Schlüssels (Fallback: erstes Symbol).
  static TischmomentFeeling feelingByKey(String key) {
    return feelings.firstWhere(
      (f) => f.key == key,
      orElse: () => feelings.first,
    );
  }

  /// Die rotierenden Fragen. Eine pro Tag, für alle Kinder gleich, damit ein
  /// gemeinsames Thema am Abendtisch entsteht.
  static const List<String> questions = [
    'Was war heute dein schönster Moment?',
    'Wofür bist du heute dankbar?',
    'Was hat dich heute zum Lachen gebracht?',
    'Was hat dir heute gutgetan?',
    'Was hast du heute Neues entdeckt?',
    'Wer hat dir heute eine Freude gemacht?',
    'Worauf bist du heute besonders stolz?',
  ];

  /// Die Frage des Tages — stabil über den Tag, wechselt täglich.
  static String questionOfTheDay([DateTime? now]) {
    final date = now ?? DateTime.now();
    // Tage seit einem festen Referenzdatum -> deterministischer Index.
    final dayNumber =
        DateTime(date.year, date.month, date.day).difference(DateTime(2020, 1, 1)).inDays;
    final index = dayNumber % questions.length;
    return questions[index.abs()];
  }
}

/// Rein lokaler Speicher für die Tischmoment-Schatzkiste.
///
/// Kein Backend, kein Teilen — spiegelt bewusst das Muster von
/// WeeklyReflectionService (versionierter Key, JSON-Liste, try/catch).
class TischmomentService {
  static const _key = 'tischmoment.entries.v1';
  static const _maxEntries = 365;

  /// Alle Momente laden (neueste zuerst).
  static Future<List<TischmomentEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => TischmomentEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Einen neuen Moment speichern.
  static Future<void> add(TischmomentEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.insert(0, entry);
    // Ältere Einträge kappen (Datenschutz + Speicher).
    final capped = all.length > _maxEntries ? all.sublist(0, _maxEntries) : all;
    await prefs.setString(
        _key, jsonEncode(capped.map((e) => e.toJson()).toList()));
  }

  /// Einen Moment löschen (Datenhoheit der Familie).
  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await prefs.setString(
        _key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// Alle Momente unwiderruflich löschen.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Zeitreise: Momente, die ziemlich genau vor einem Monat bzw. einem Jahr
  /// festgehalten wurden (±2 Tage Toleranz) — für die schöne Erinnerung.
  static List<TischmomentEntry> timeTravel(List<TischmomentEntry> all,
      [DateTime? now]) {
    final today = now ?? DateTime.now();
    bool near(DateTime a, DateTime b) => a.difference(b).abs().inDays <= 2;
    final oneMonthAgo = DateTime(today.year, today.month - 1, today.day);
    final oneYearAgo = DateTime(today.year - 1, today.month, today.day);
    return all
        .where((e) => near(e.createdAt, oneMonthAgo) || near(e.createdAt, oneYearAgo))
        .toList();
  }
}
