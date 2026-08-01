/// EventDiscoveryAgent – KI-Agent für standortbasierte Familien-Events.
///
/// Architektur:
///   - Nutzt Gemini als Reasoning-Kern mit strukturiertem JSON-Output.
///   - Sucht nach Events, Theater, Kino, Familienzentren, Festivals etc.
///   - Gibt eine Liste von DiscoveredEvent zurück.
///   - Fallback: kuratierte Beispiel-Events wenn KI nicht verfügbar.
///
/// Sicherheit:
///   - Kein API-Key im Code; lädt via APIConfig aus .env.
///   - Inputs werden vor dem Prompt sanitiert.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/logic/privacy_sanitizer.dart';

class EventDiscoveryAgent {
  static final EventDiscoveryAgent instance = EventDiscoveryAgent._();
  EventDiscoveryAgent._();

  // ─── Haupt-Methode ─────────────────────────────────────────────────────────

  /// Entdeckt Events für Eltern und Kinder anhand von Standort.
  /// [city]       – Stadtname (z.B. "Berlin", "München")
  /// [radiusHint] – Hinweis für den Agent (z.B. "20 km Umkreis")
  /// [childAges]  – Altersangaben der Kinder (z.B. ["3 Jahre", "7 Jahre"])
  Future<List<DiscoveredEvent>> discoverEvents({
    required String city,
    String radiusHint = '20 km Umkreis',
    List<String> childAges = const [],
  }) async {
    final apiKey = APIConfig.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('EventDiscoveryAgent: Kein API-Key, nutze leere Ergebnisliste.');
      return <DiscoveredEvent>[];
    }

    final cleanCity = _sanitize(PrivacySanitizer.sanitizeForAi(city));
    final cleanRadiusHint = _sanitize(PrivacySanitizer.sanitizeForAi(radiusHint));
    final agesText = childAges.isEmpty
        ? 'Kinder verschiedener Altersgruppen (0–16 Jahre)'
      : 'Kinder im Alter von ${childAges.map((age) => _sanitize(PrivacySanitizer.sanitizeForAi(age))).join(', ')}';

    final prompt = '''
Du bist ein Familien-Event-Assistent für die Parentpeak-App in Deutschland.

Aufgabe:
Erstelle eine Liste von 8 konkreten und realistischen Aktivitäten, Events oder
Angeboten für Eltern mit Kindern in und um "$cleanCity" ($cleanRadiusHint).
Zielgruppe: $agesText.

Kategorien die du abdecken sollst:
- Kindertheater / Theater
- Kino (Kinderfilm-Vorstellungen)
- Familienzentren / Eltern-Kind-Treffs
- Sport und Outdoor (Wandern, Schwimmen, Radfahren)
- Museen / Ausstellungen für Kinder
- Bastel-Workshops / Kreativangebote
- Musik / Konzerte für Kinder
- Parks / Spielplätze mit Programm
- Festivals / Märkte (saisonal passend zu ${DateTime.now().month}. Monat)
- Bildungsangebote / Sprachkurse

Regeln:
- Nutze reale Orte, Einrichtungen und Anbieter aus der Region "$cleanCity".
- Wenn du keine genauen aktuellen Daten hast, erstelle plausible, typische Angebote.
- Preise sollen realistisch sein (0–20€ pro Person).
- Altersangaben müssen zu den Kindern passen.
- Verteile Kategorien gleichmäßig.

Antworte NUR mit einem gültigen JSON-Array, kein Markdown, keine Erklärung:

[
  {
    "id": "uuid-ähnlicher-string",
    "title": "Name des Events",
    "description": "Kurzbeschreibung 1-2 Sätze für Eltern",
    "category": "theater|kino|sport|musik|natur|basteln|familienzentrum|museum|festival|spielplatz|sonstiges",
    "ageLabels": ["0–3 Jahre", "4–6 Jahre"],
    "location": "Adresse oder Ort",
    "cityHint": "$cleanCity",
    "eventDate": "2025-06-15T10:00:00" or null,
    "isRecurring": false,
    "recurringNote": null or "Jeden Samstag 10–12 Uhr",
    "price": "kostenlos" or "5 €" or "3–8 €",
    "url": null,
    "organizer": "Name der Institution oder Veranstalter"
  }
]
''';

    try {
      final model = GenerativeModel(
        model: APIConfig.getGeminiModelName(),
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 4096,
        ),
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '';
      return _parseAgentResponse(raw, city);
    } catch (e) {
      debugPrint('EventDiscoveryAgent: Fehler beim API-Call: $e');
      return <DiscoveredEvent>[];
    }
  }

  // ─── Parser ────────────────────────────────────────────────────────────────

  List<DiscoveredEvent> _parseAgentResponse(String raw, String city) {
    try {
      final repairedJson = _extractAndRepairJsonArray(raw);
      if (repairedJson == null || repairedJson.isEmpty) {
        debugPrint('EventDiscoveryAgent: Kein gültiges JSON-Array gefunden.');
        return <DiscoveredEvent>[];
      }

      final list = jsonDecode(repairedJson) as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;

        final categoryStr = (map['category'] as String? ?? 'sonstiges').toLowerCase();
        final category = _parseCategory(categoryStr);

        final ageLabels = (map['ageLabels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['Alle Altersgruppen'];

        DateTime? eventDate;
        if (map['eventDate'] != null) {
          try {
            eventDate = DateTime.parse(map['eventDate'] as String);
          } catch (e) {
            debugPrint(
              'EventDiscoveryAgent._parseAgentResponse(): invalid eventDate ignored: $e',
            );
          }
        }

        return DiscoveredEvent(
          id: map['id']?.toString() ?? _generateId(),
          title: map['title'] as String? ?? 'Event',
          description: map['description'] as String? ?? '',
          category: category,
          ageLabels: ageLabels,
          location: map['location'] as String? ?? city,
          cityHint: map['cityHint'] as String? ?? city,
          eventDate: eventDate,
          isRecurring: map['isRecurring'] as bool? ?? false,
          recurringNote: map['recurringNote'] as String?,
          price: map['price'] as String?,
          url: map['url'] as String?,
          organizer: map['organizer'] as String?,
          source: DiscoveredEventSource.kiAgent,
          discoveredAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('EventDiscoveryAgent: JSON-Parsing fehlgeschlagen: $e');
      return <DiscoveredEvent>[];
    }
  }

  String? _extractAndRepairJsonArray(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    // Entfernt optionale Markdown-Codefences.
    text = text.replaceAll(RegExp(r'^```(?:json)?\s*'), '');
    text = text.replaceAll(RegExp(r'\s*```$'), '');

    final start = text.indexOf('[');
    if (start == -1) return null;

    final end = text.lastIndexOf(']');
    var jsonChunk = end != -1 && end > start
        ? text.substring(start, end + 1)
        : text.substring(start);

    // Repariert abgeschnittene Antworten (fehlende schließende Klammern).
    final openBraces = '{'.allMatches(jsonChunk).length;
    final closeBraces = '}'.allMatches(jsonChunk).length;
    if (openBraces > closeBraces) {
      jsonChunk += '}' * (openBraces - closeBraces);
    }

    final openBrackets = '['.allMatches(jsonChunk).length;
    final closeBrackets = ']'.allMatches(jsonChunk).length;
    if (openBrackets > closeBrackets) {
      jsonChunk += ']' * (openBrackets - closeBrackets);
    }

    return jsonChunk.trim();
  }

  DiscoveredEventCategory _parseCategory(String raw) {
    switch (raw) {
      case 'theater':
        return DiscoveredEventCategory.theater;
      case 'kino':
        return DiscoveredEventCategory.kino;
      case 'sport':
        return DiscoveredEventCategory.sport;
      case 'musik':
        return DiscoveredEventCategory.musik;
      case 'natur':
        return DiscoveredEventCategory.natur;
      case 'basteln':
        return DiscoveredEventCategory.basteln;
      case 'familienzentrum':
        return DiscoveredEventCategory.familienzentrum;
      case 'museum':
        return DiscoveredEventCategory.museum;
      case 'festival':
        return DiscoveredEventCategory.festival;
      case 'spielplatz':
        return DiscoveredEventCategory.spielplatz;
      default:
        return DiscoveredEventCategory.sonstiges;
    }
  }

  // ─── Hilfsmethoden ────────────────────────────────────────────────────────

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[<>{}\[\]\\]'), '').trim();

  String _generateId() =>
      'ev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
}
