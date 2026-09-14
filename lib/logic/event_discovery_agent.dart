/// EventDiscoveryAgent – KI-Agent für standortbasierte Familien-Events.
///
/// Architektur:
///   - Ruft den Parentpeak KI-Proxy mit Google Search Grounding auf.
///   - Findet ECHTE Events von berlin.de, Familienzentren, Kinos, Theatern usw.
///   - Standort-präzise: Kreuzberg ≠ Mitte ≠ München.
///   - Saisonal + aktuell (heutiges Datum im Prompt).
///   - Fallback auf einen Proxy-Aufruf ohne Grounding.
///
/// Sicherheit:
///   - Kein API-Key im Client; das Backend verwaltet den Schlüssel.
///   - Inputs werden vor dem Prompt sanitiert.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/logic/privacy_sanitizer.dart';

class EventDiscoveryAgent {
  static final EventDiscoveryAgent instance = EventDiscoveryAgent();

  EventDiscoveryAgent();

  // ─── Haupt-Methode ─────────────────────────────────────────────────────────

  /// Entdeckt ECHTE Events für Eltern und Kinder anhand von Standort.
  /// [city]       – Stadtname oder Stadtteil (z.B. "Berlin-Kreuzberg", "München")
  /// [radiusHint] – Hinweis für den Agent (z.B. "20 km Umkreis")
  /// [childAges]  – Altersangaben der Kinder (z.B. ["3 Jahre", "7 Jahre"])
  /// [latitude]   – GPS-Breitengrad (optional, für Präzision)
  /// [longitude]  – GPS-Längengrad (optional, für Präzision)
  Future<List<DiscoveredEvent>> discoverEvents({
    required String city,
    String radiusHint = '20 km Umkreis',
    List<String> childAges = const [],
    double? latitude,
    double? longitude,
  }) async {
    final cleanCity = _sanitize(PrivacySanitizer.sanitizeForAi(city));
    final cleanRadius = _sanitize(PrivacySanitizer.sanitizeForAi(radiusHint));

    // When city is raw coordinates (Nominatim failed) or a placeholder, use coords as search location
    final isCoordCity = RegExp(r'^-?\d+\.\d+,-?\d+\.\d+$').hasMatch(cleanCity);
    final locationDesc =
        isCoordCity && latitude != null ? '$latitude,$longitude' : cleanCity;
    final agesText = childAges.isEmpty
        ? 'Kinder verschiedener Altersgruppen (0–16 Jahre)'
        : 'Kinder im Alter von ${childAges.map((a) => _sanitize(PrivacySanitizer.sanitizeForAi(a))).join(', ')}';

    final now = DateTime.now();
    final weekdayNames = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag'
    ];
    final today =
        '${weekdayNames[now.weekday - 1]}, ${now.day}.${now.month}.${now.year}';
    final saison = _getSaison(now.month);

    // GPS-Koordinaten für Distanz-Info
    final gpsHint = (latitude != null && longitude != null)
        ? 'Nutzerstandort: $latitude, $longitude. '
        : '';

    // Kurzer Prompt für schnelle Grounding-Antwort (< 20 s)
    final groundingPrompt = '''
$today. ${gpsHint}Suche 10 aktuelle Familienevents ${isCoordCity ? 'in der Nähe von' : 'in'} "$locationDesc" ($cleanRadius) — $saison. Zielgruppe: $agesText.
Antworte NUR als JSON-Array (kein Markdown). Trage bei "url" die ECHTE URL aus dem Web-Suchergebnis ein:
[{"id":"1","title":"...","description":"...","category":"theater","ageLabels":["alle"],"location":"Adresse, Stadtteil","cityHint":"$locationDesc","eventDate":"${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.day + 2).toString().padLeft(2, '0')}T10:00:00","eventTimeRange":"10:00 – 12:00 Uhr","isRecurring":false,"recurringNote":null,"price":"kostenlos","url":"ECHTE_URL_AUS_WEBSUCHE","organizer":"..."}]
Erstelle genau 10 echte Events. Bei "url" MUSS eine echte Webseite stehen (z.B. berlin.de, eventbrite.de, Veranstalter-Website).
''';

    // Ausführlicher Prompt für Package-Fallback (ohne Web-Suche)
    final prompt = '''
Heute ist $today. $gpsHint

Erstelle 10 typische Familien-Events ${isCoordCity ? 'in der Nähe von' : 'in'} "$locationDesc" ($cleanRadius), $saison.
Zielgruppe: $agesText. Realistische Orte, Preise 0–15€.

Antworte NUR mit einem gültigen JSON-Array:
[{"id":"ev1","title":"...","description":"2-3 Sätze","category":"theater","ageLabels":["3–6 Jahre"],"location":"Adresse, Stadtteil","cityHint":"$locationDesc","eventDate":"${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.day + 2).toString().padLeft(2, '0')}T10:00:00","eventTimeRange":"10:00 – 12:00 Uhr","isRecurring":false,"recurringNote":null,"price":"5 €","url":"https://...","organizer":"Veranstalter"}]
Genau 10 Events, verschiedene Kategorien (theater,kino,sport,musik,natur,basteln,familienzentrum,museum,festival,spielplatz,sonstiges) und Stadtteile.
''';

    // Primär: Backend-Proxy mit Google Search Grounding
    try {
      final events = await _callWithGrounding(groundingPrompt, city);
      if (events.isNotEmpty) return events;
      debugPrint(
          'EventDiscoveryAgent: Grounding leer — versuche ohne Grounding.');
    } catch (e) {
      debugPrint('EventDiscoveryAgent: Grounding-Aufruf fehlgeschlagen: $e');
    }

    // Fallback 1: Proxy-Aufruf ohne Grounding (KI generiert realistische Events)
    try {
      final events = await _callWithoutGrounding(prompt, city);
      if (events.isNotEmpty) return events;
      debugPrint('EventDiscoveryAgent: Auch Fallback leer.');
    } catch (e) {
      debugPrint('EventDiscoveryAgent: Fallback-Aufruf fehlgeschlagen: $e');
    }

    // Fallback 2: Lokale, ehrliche Vorschläge — damit der Nutzer NIE
    // einen komplett leeren Screen sieht (wichtig für Launch-Stabilität).
    return _localSuggestions(locationDesc, latitude, longitude);
  }

  /// Ehrliche lokale Vorschläge als letzte Rettung (klar als KI-Idee markiert).
  /// Verhindert einen leeren "Keine Events"-Screen wenn die KI nicht antwortet.
  List<DiscoveredEvent> _localSuggestions(
      String city, double? lat, double? lon) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final ideas = <Map<String, dynamic>>[
      {
        'title': 'Spielplatz-Treff im Kiez',
        'desc':
            'Trefft euch mit anderen Familien auf einem Spielplatz in eurer Nähe. Kinder spielen, Eltern kommen ins Gespräch.',
        'cat': DiscoveredEventCategory.spielplatz,
        'days': 1,
      },
      {
        'title': 'Bibliotheks-Besuch',
        'desc':
            'Die Stadtbibliothek bietet oft kostenlose Vorlesestunden und eine Kinderecke. Ein ruhiger Ausflug bei jedem Wetter.',
        'cat': DiscoveredEventCategory.museum,
        'days': 2,
      },
      {
        'title': 'Waldspaziergang mit Naturspielen',
        'desc':
            'Ab in den nächsten Park oder Wald: Blätter sammeln, Verstecken, Balancieren. Bewegung und frische Luft für alle.',
        'cat': DiscoveredEventCategory.natur,
        'days': 3,
      },
    ];
    return ideas
        .map((idea) => DiscoveredEvent(
              id: _generateId(),
              title: idea['title'] as String,
              description: idea['desc'] as String,
              category: idea['cat'] as DiscoveredEventCategory,
              ageLabels: const ['Alle Altersgruppen'],
              location: city,
              cityHint: city,
              latitude: lat,
              longitude: lon,
              eventDate:
                  base.add(Duration(days: idea['days'] as int, hours: 10)),
              price: 'kostenlos',
              organizer: 'Parentpeak Idee',
              source: DiscoveredEventSource.kiAgent,
              discoveredAt: now,
            ))
        .toList();
  }

  // ─── Backend-Proxy mit Google Search Grounding ─────────────────────────────

  /// Events brauchen ein Modell mit zuverlässigem Google Search Grounding.
  /// gemini-3.5-flash ist stabil und günstig für Web-Suche.
  static const String _groundingModel = 'gemini-3.5-flash';

  Future<List<DiscoveredEvent>> _callWithGrounding(
      String prompt, String city) async {
    final response = await GeminiAIService(modelName: _groundingModel)
        .generate(prompt, useGoogleSearch: true)
        .timeout(const Duration(seconds: 35));
    return _parseAgentResponse(
      response.text,
      city,
      groundingUrls: response.groundingUrls,
    );
  }

  // ─── Fallback: Proxy-Aufruf ohne Grounding ─────────────────────────────────

  Future<List<DiscoveredEvent>> _callWithoutGrounding(
      String prompt, String city) async {
    final text = await GeminiAIService(modelName: _groundingModel)
        .generateText(prompt)
        .timeout(const Duration(seconds: 35));
    return _parseAgentResponse(text, city);
  }

  // ─── Parser ────────────────────────────────────────────────────────────────

  List<DiscoveredEvent> _parseAgentResponse(String raw, String city,
      {List<String> groundingUrls = const []}) {
    try {
      final repairedJson = _extractAndRepairJsonArray(raw);
      if (repairedJson == null || repairedJson.isEmpty) {
        debugPrint('EventDiscoveryAgent: Kein gültiges JSON-Array gefunden.');
        return <DiscoveredEvent>[];
      }

      final list = jsonDecode(repairedJson) as List<dynamic>;
      final results = <DiscoveredEvent>[];

      for (var i = 0; i < list.length; i++) {
        final map = list[i] as Map<String, dynamic>;
        final categoryStr =
            (map['category'] as String? ?? 'sonstiges').toLowerCase();
        final ageLabels = (map['ageLabels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['Alle Altersgruppen'];

        DateTime? eventDate;
        final rawDate = map['eventDate'];
        if (rawDate != null &&
            rawDate.toString().isNotEmpty &&
            rawDate.toString() != 'null') {
          try {
            eventDate = DateTime.parse(rawDate.toString());
          } catch (_) {}
        }

        // Take URL from event JSON; fall back to any available grounding URL pool entry
        String? url = _validateUrl(map['url'] as String?);
        if (url == null) {
          // Try index-matched URL first, then scan pool for any valid URL
          for (var j = i; j < i + groundingUrls.length; j++) {
            final candidate =
                _validateUrl(groundingUrls[j % groundingUrls.length]);
            if (candidate != null) {
              url = candidate;
              break;
            }
          }
        }

        results.add(DiscoveredEvent(
          id: map['id']?.toString() ?? _generateId(),
          title: map['title'] as String? ?? 'Event',
          description: map['description'] as String? ?? '',
          category: _parseCategory(categoryStr),
          ageLabels: ageLabels,
          location: map['location'] as String? ?? city,
          cityHint: map['cityHint'] as String? ?? city,
          eventDate: eventDate,
          isRecurring: map['isRecurring'] as bool? ?? false,
          recurringNote: map['recurringNote'] as String?,
          eventTimeRange: map['eventTimeRange'] as String?,
          price: map['price'] as String?,
          url: url?.isNotEmpty == true ? url : null,
          organizer: map['organizer'] as String?,
          source: DiscoveredEventSource.kiAgent,
          discoveredAt: DateTime.now(),
        ));
      }

      debugPrint('EventDiscoveryAgent: ${results.length} Events gefunden, '
          '${results.where((e) => e.url != null).length} mit Quell-URL.');
      return results;
    } catch (e) {
      debugPrint('EventDiscoveryAgent: JSON-Parsing fehlgeschlagen: $e');
      return <DiscoveredEvent>[];
    }
  }

  String? _extractAndRepairJsonArray(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    text = text.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');

    final start = text.indexOf('[');
    if (start == -1) return null;

    final end = text.lastIndexOf(']');
    var jsonChunk = end != -1 && end > start
        ? text.substring(start, end + 1)
        : text.substring(start);

    final openBraces = '{'.allMatches(jsonChunk).length;
    final closeBraces = '}'.allMatches(jsonChunk).length;
    if (openBraces > closeBraces) jsonChunk += '}' * (openBraces - closeBraces);

    final openBrackets = '['.allMatches(jsonChunk).length;
    final closeBrackets = ']'.allMatches(jsonChunk).length;
    if (openBrackets > closeBrackets)
      jsonChunk += ']' * (openBrackets - closeBrackets);

    return jsonChunk.trim();
  }

  /// Gibt null zurück für Platzhalter-URLs wie "https://..." oder ungültige URIs.
  String? _validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))
      return null;
    // Platzhalter ablehnen
    if (trimmed == 'https://...' ||
        trimmed == 'http://...' ||
        trimmed.endsWith('/...')) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    return trimmed;
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

  String _getSaison(int month) {
    if (month >= 3 && month <= 5)
      return 'Frühling (Ostermärkte, Stadtfeste, Fahrrad-Touren)';
    if (month >= 6 && month <= 8)
      return 'Sommer (Freibäder, Freilichtbühnen, Stadtfeste, Ferienprogramme)';
    if (month >= 9 && month <= 11)
      return 'Herbst (Erntedank, Halloween-Specials, Indoor-Angebote)';
    return 'Winter (Weihnachtsmärkte, Eislaufen, Winterferienprogramme)';
  }

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[<>{}\[\]\\]'), '').trim();

  String _generateId() =>
      'ev_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 9000}';
}
