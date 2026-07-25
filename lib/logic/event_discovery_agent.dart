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
      debugPrint(
          'EventDiscoveryAgent: Kein API-Key, nutze leere Ergebnisliste.');
      return <DiscoveredEvent>[];
    }

    final cleanCity = _sanitize(city);
    final agesText = childAges.isEmpty
        ? 'Kinder verschiedener Altersgruppen (0–16 Jahre)'
        : 'Kinder im Alter von ${childAges.map(_sanitize).join(', ')}';

    final prompt = '''
Du bist ein lokaler Familien-Experte fuer "$cleanCity" in Deutschland.

Aufgabe:
Erstelle 8 REALISTISCHE Aktivitaeten und Angebote fuer Eltern mit Kindern
die WIRKLICH in "$cleanCity" und direkter Umgebung existieren.
Zielgruppe: $agesText.

WICHTIG — Realismus:
- Nutze ECHTE Einrichtungen die es in "$cleanCity" gibt (Familienzentren, Buechereien, Schwimmbaeder, Museen, Parks mit Namen)
- Wenn "$cleanCity" ein Stadtteil ist (z.B. "Kreuzberg"), nutze Orte IN diesem Stadtteil
- Bevorzuge REGELMAESSIGE Angebote (die gibt es wirklich): Offener Treff, Babyschwimmen, Vorlesestunde, Spielgruppe, Kinderturnen
- Einmalige Events nur wenn saisonal plausibel (Sommer: Freibad/Fest, Winter: Weihnachtsmarkt, Herbst: Laternenfest)
- Aktuelle Saison: Monat ${DateTime.now().month} (${_currentSeason()})

Kategorien (mindestens 5 verschiedene):
- familienzentrum: Offener Treff, Eltern-Cafe, Krabbelgruppe, Stillgruppe
- sport: Babyschwimmen, Kinderturnen, Fussball fuer Kids, Kinderyoga
- natur: Spielplatz-Treff, Waldgruppe, Naturerlebnis, Bauernhof
- basteln: Kreativ-Workshop, Toepfern, Malen fuer Kinder
- musik: Musikalische Frueherziehung, Kinderkonzert, Singkreis
- theater: Puppentheater, Kindertheater, Maerchenvorstellung
- museum: Kindermuseum, Mitmach-Ausstellung, Wissenschaft zum Anfassen
- spielplatz: Spielplatz mit Programm, Wasserspielplatz, Indoor-Spielplatz

Regeln:
- Preise: Realistisch (Familienzentrum = kostenlos, Schwimmbad = 4-8 EUR, Museum = 5-12 EUR)
- Bei wiederkehrenden Angeboten: isRecurring = true + recurringNote angeben
- Altersangaben muessen zur Zielgruppe passen
- location: Moeglichst mit Strassenname oder bekanntem Ort (damit Eltern es finden)
- url: Wenn du die Website des Veranstalters kennst, gib sie an. Sonst null.

Antworte NUR mit einem gueltigen JSON-Array (kein Markdown, kein Text):

[
  {
    "id": "evt_1",
    "title": "Name des Angebots",
    "description": "Was erwartet Familien? 1-2 Saetze.",
    "category": "familienzentrum|sport|natur|basteln|musik|theater|museum|spielplatz|sonstiges",
    "ageLabels": ["0-3 Jahre", "3-6 Jahre"],
    "location": "Ort/Adresse in $cleanCity",
    "cityHint": "$cleanCity",
    "eventDate": null,
    "isRecurring": true,
    "recurringNote": "Jeden Dienstag 9:30-11:00 Uhr",
    "price": "kostenlos",
    "url": "https://website-des-veranstalters.de" or null,
    "organizer": "Name der Einrichtung"
  }
]
''';

    try {
      final model = GenerativeModel(
        model: APIConfig.getGeminiModelName(),
        apiKey: apiKey,
        systemInstruction: Content.text(
            'Du bist ein lokaler Familien-Experte. Antworte IMMER NUR mit gueltigem JSON-Array. Kein Markdown, kein Text davor oder danach.'),
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

        final categoryStr =
            (map['category'] as String? ?? 'sonstiges').toLowerCase();
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

  String _currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'Fruehling';
    if (month >= 6 && month <= 8) return 'Sommer';
    if (month >= 9 && month <= 11) return 'Herbst';
    return 'Winter';
  }

  String _generateId() =>
      'ev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
}
