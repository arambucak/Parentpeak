/// EventFlyerScannerService — füllt das Event-Formular aus Foto oder Text.
///
/// Idee (elternfreundlich): Eltern fotografieren einen Flyer (Kita-Aushang,
/// Plakat, Einladung) oder fügen einen Text ein. Gemini erkennt daraus die
/// wichtigsten Event-Felder und befüllt das Formular — der Nutzer prüft nur noch.
///
/// Sicherheit / Robustheit:
///   - Kein API-Key im Client; alles läuft über den Backend-KI-Proxy.
///   - Immer graceful: Bei Fehlern/leerer Antwort kommt null zurück, nie ein Crash.
///   - Web-kompatibel: nutzt Uint8List statt dart:io File.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/meetup_event.dart';

/// Ergebnis eines Flyer-/Text-Scans. Alle Felder sind optional —
/// nur das wird gesetzt, was die KI zuverlässig erkennen konnte.
class ScannedEventDraft {
  const ScannedEventDraft({
    this.title,
    this.description,
    this.date,
    this.time,
    this.location,
    this.category,
    this.ageGroups = const [],
    this.priceNote,
    this.recurringNote,
  });

  final String? title;
  final String? description;
  final DateTime? date;
  final TimeOfDayLite? time;
  final String? location;
  final EventCategory? category;
  final List<AgeGroup> ageGroups;

  /// Freitext zum Preis (z.B. "kostenlos", "5 €"). Wird im UI als Hinweis genutzt.
  final String? priceNote;
  final String? recurringNote;

  /// True, wenn mindestens ein nützliches Feld erkannt wurde.
  bool get hasContent =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty) ||
      date != null ||
      time != null ||
      (location != null && location!.trim().isNotEmpty) ||
      category != null ||
      ageGroups.isNotEmpty ||
      recurringNote != null;
}

/// Kleiner wertbasierter Zeit-Container, um keine Flutter-Abhängigkeit
/// (TimeOfDay) in die Service-Schicht zu ziehen.
class TimeOfDayLite {
  const TimeOfDayLite(this.hour, this.minute);
  final int hour;
  final int minute;
}

class EventFlyerScannerService {
  EventFlyerScannerService({GeminiAIService? gemini})
      : _gemini = gemini ?? GeminiAIService();

  final GeminiAIService _gemini;

  /// Analysiert ein Flyer-Foto und liefert einen Event-Entwurf.
  Future<ScannedEventDraft?> scanFromImage(
    Uint8List imageBytes, {
    String imageMimeType = 'image/jpeg',
  }) async {
    try {
      final response = await _gemini
          .generate(
            _prompt(hasImage: true),
            imageBytes: imageBytes,
            imageMimeType: imageMimeType,
          )
          .timeout(const Duration(seconds: 35));
      return _parse(response.text);
    } catch (e) {
      debugPrint('EventFlyerScannerService.scanFromImage: $e');
      return null;
    }
  }

  /// Analysiert eingefügten Text (z.B. aus einer WhatsApp-Nachricht).
  Future<ScannedEventDraft?> scanFromText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return null;
    try {
      final response = await _gemini
          .generate('${_prompt(hasImage: false)}\n\nTEXT:\n"""\n$text\n"""')
          .timeout(const Duration(seconds: 35));
      return _parse(response.text);
    } catch (e) {
      debugPrint('EventFlyerScannerService.scanFromText: $e');
      return null;
    }
  }

  // ─── Prompt ────────────────────────────────────────────────────────────────

  String _prompt({required bool hasImage}) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final source = hasImage
        ? 'Analysiere das Foto eines Veranstaltungs-Flyers/Plakats.'
        : 'Analysiere den folgenden Text einer Veranstaltungs-Ankündigung.';

    return '''
$source Extrahiere die Angaben für ein Familien-Event.
Heutiges Datum: $today. Wenn nur "Samstag" o.ä. steht, wähle das nächste passende zukünftige Datum.

Antworte NUR mit einem gültigen JSON-Objekt (kein Markdown, keine Erklärung):
{
  "title": "kurzer Event-Titel oder null",
  "description": "2-3 Sätze, einladend formuliert, oder null",
  "date": "YYYY-MM-DD oder null",
  "time": "HH:MM (24h) oder null",
  "location": "Ort/Adresse oder null",
  "category": "sports|outdoor|education|arts|socialGathering|other oder null",
  "ageGroups": ["infant|toddler|preschool|elementary|teenager|mixed"],
  "price": "kurzer Preishinweis wie 'kostenlos' oder '5 €' oder null",
  "recurringNote": "Wiederholung im Wortlaut des Flyers, z.B. 'jeden Dienstag', oder null"
}

Regeln:
- Erfinde KEINE Fakten. Was nicht erkennbar ist, ist null (bzw. leeres Array).
- recurringNote nur setzen, wenn eine Wiederholung ausdrücklich genannt ist; kein Enddatum erfinden.
- category: sports=Sport/Bewegung, outdoor=Natur/draußen, education=Kurs/Lernen/Vorlesen,
  arts=Basteln/Musik/Theater/Museum, socialGathering=Treffen/Fest/Spielplatz, other=Rest.
- ageGroups: infant=0-1, toddler=1-3, preschool=3-5, elementary=6-12, teenager=13+, mixed=altersgemischt.
  Wenn "für die ganze Familie"/"alle Altersgruppen" → ["mixed"].
''';
  }

  // ─── Parser ──────────────────────────────────────────────────────────────

  ScannedEventDraft? _parse(String raw) {
    final jsonStr = _extractJsonObject(raw);
    if (jsonStr == null) return null;

    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      map = Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('EventFlyerScannerService._parse jsonDecode: $e');
      return null;
    }

    final draft = ScannedEventDraft(
      title: _str(map['title']),
      description: _str(map['description']),
      date: _parseDate(map['date']),
      time: _parseTime(map['time']),
      location: _str(map['location']),
      category: _parseCategory(_str(map['category'])),
      ageGroups: _parseAgeGroups(map['ageGroups']),
      priceNote: _str(map['price']),
      recurringNote: _str(map['recurringNote']),
    );

    return draft.hasContent ? draft : null;
  }

  String? _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  DateTime? _parseDate(dynamic value) {
    final s = _str(value);
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  TimeOfDayLite? _parseTime(dynamic value) {
    final s = _str(value);
    if (s == null) return null;
    final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(s);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDayLite(hour, minute);
  }

  EventCategory? _parseCategory(String? raw) {
    if (raw == null) return null;
    switch (raw.toLowerCase()) {
      case 'sports':
        return EventCategory.sports;
      case 'outdoor':
        return EventCategory.outdoor;
      case 'education':
        return EventCategory.education;
      case 'arts':
        return EventCategory.arts;
      case 'socialgathering':
        return EventCategory.socialGathering;
      case 'other':
        return EventCategory.other;
      default:
        return null;
    }
  }

  List<AgeGroup> _parseAgeGroups(dynamic value) {
    if (value is! List) return const [];
    final result = <AgeGroup>[];
    for (final item in value) {
      final s = item.toString().toLowerCase().trim();
      switch (s) {
        case 'infant':
          result.add(AgeGroup.infant);
          break;
        case 'toddler':
          result.add(AgeGroup.toddler);
          break;
        case 'preschool':
          result.add(AgeGroup.preschool);
          break;
        case 'elementary':
          result.add(AgeGroup.elementary);
          break;
        case 'teenager':
          result.add(AgeGroup.teenager);
          break;
        case 'mixed':
          result.add(AgeGroup.mixed);
          break;
      }
    }
    return result.toSet().toList();
  }
}
