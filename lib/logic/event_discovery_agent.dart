/// EventDiscoveryAgent – KI-Agent für standortbasierte Familien-Events.
///
/// Architektur:
///   - Ruft Gemini REST API direkt auf mit Google Search Grounding.
///   - Findet ECHTE Events von berlin.de, Familienzentren, Kinos, Theatern usw.
///   - Standort-präzise: Kreuzberg ≠ Mitte ≠ München.
///   - Saisonal + aktuell (heutiges Datum im Prompt).
///   - Fallback auf Package-Aufruf wenn REST fehlschlägt.
///
/// Sicherheit:
///   - Kein API-Key im Code; lädt via APIConfig aus .env.
///   - Inputs werden vor dem Prompt sanitiert.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:parentpeak/config/api_config.dart';
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
    final apiKey = APIConfig.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('EventDiscoveryAgent: Kein API-Key.');
      return <DiscoveredEvent>[];
    }

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

    // Primär: REST API mit Google Search Grounding (kurzer Prompt für < 20s)
    try {
      final events = await _callWithGrounding(apiKey, groundingPrompt, city);
      if (events.isNotEmpty) return events;
    } catch (e) {
      debugPrint('EventDiscoveryAgent: Grounding-Aufruf fehlgeschlagen: $e');
    }

    // Fallback: Package-Aufruf ohne Grounding (ausführlicher Prompt)
    try {
      return await _callWithPackage(apiKey, prompt, city);
    } catch (e) {
      debugPrint('EventDiscoveryAgent: Fallback-Aufruf fehlgeschlagen: $e');
      return <DiscoveredEvent>[];
    }
  }

  // ─── REST API mit Google Search Grounding ──────────────────────────────────

  /// Events brauchen ein Modell mit zuverlässigem Google Search Grounding.
  /// gemini-3.5-flash ist stabil und günstig für Web-Suche.
  static const String _groundingModel = 'gemini-3.5-flash';

  Future<List<DiscoveredEvent>> _callWithGrounding(
      String apiKey, String prompt, String city) async {
    // Use dedicated grounding model (not the app default which may be too light)
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_groundingModel:generateContent?key=${Uri.encodeComponent(apiKey)}',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ],
          'role': 'user',
        }
      ],
      'tools': [
        {'google_search': {}}
      ],
      'generationConfig': {
        'temperature': 1.0,
        'maxOutputTokens': 6000,
      },
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      debugPrint(
          'EventDiscoveryAgent: Grounding API ${response.statusCode} — ${response.body.substring(0, response.body.length.clamp(0, 300))}');
      throw Exception(
          'Gemini REST ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      debugPrint('EventDiscoveryAgent: Grounding returned no candidates');
      return [];
    }

    final content = (candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return [];

    final rawText = parts
        .map((p) => ((p as Map<String, dynamic>)['text'] as String?) ?? '')
        .join('');

    // Extrahiere Quell-URLs aus Grounding-Metadaten
    final groundingMeta = (candidates.first
        as Map<String, dynamic>)['groundingMetadata'] as Map<String, dynamic>?;
    final groundingUrls = _extractGroundingUrls(groundingMeta);

    return _parseAgentResponse(rawText, city, groundingUrls: groundingUrls);
  }

  List<String> _extractGroundingUrls(Map<String, dynamic>? meta) {
    if (meta == null) return [];
    final chunks = meta['groundingChunks'] as List?;
    if (chunks == null) return [];
    return chunks
        .map((c) => ((c as Map<String, dynamic>)['web']
            as Map<String, dynamic>?)?['uri'] as String?)
        .whereType<String>()
        .toList();
  }

  // ─── Fallback: Package-Aufruf ───────────────────────────────────────────────

  Future<List<DiscoveredEvent>> _callWithPackage(
      String apiKey, String prompt, String city) async {
    final model = GenerativeModel(
      model: _groundingModel, // Use same capable model for realistic results
      apiKey: apiKey,
      generationConfig:
          GenerationConfig(temperature: 0.3, maxOutputTokens: 8192),
    );
    final response = await model.generateContent(
        [Content.text(prompt)]).timeout(const Duration(seconds: 30));
    return _parseAgentResponse(response.text ?? '', city);
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
