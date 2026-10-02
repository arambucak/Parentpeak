/// EventDiscoveryAgent – KI-Agent für standortbasierte Familien-Events.
///
/// Architektur:
///   - Ruft den Parentpeak KI-Proxy mit Google Search Grounding auf.
///   - Findet ECHTE Events von berlin.de, Familienzentren, Kinos, Theatern usw.
///   - Standort-präzise: Kreuzberg ≠ Mitte ≠ München.
///   - Saisonal + aktuell (heutiges Datum im Prompt).
///   - Fehler bleiben Fehler; keine synthetischen Ersatz-Events.
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

  EventDiscoveryAgent({GeminiAIService? aiService})
      : _aiService = aiService ?? GeminiAIService(modelName: _groundingModel);

  final GeminiAIService _aiService;

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

    final groundingPrompt = '''
  $today. ${gpsHint}Finde bis zu 5 belegte Familienevents ${isCoordCity ? 'in der Nähe von' : 'in'} "$locationDesc" ($cleanRadius), $saison. Zielgruppe: $agesText.
  Nutze Google Search. Bevorzuge konkrete Veranstalterseiten mit bestätigtem künftigem Termin. Weniger Treffer sind erlaubt; nichts erfinden oder zum Auffüllen ergänzen.
  Antworte nur als kompaktes JSON-Array. Pro Treffer: title, description (höchstens ein kurzer Satz), category, ageLabels, location, eventDate (ISO-8601 oder null), price (belegter Preis oder null), url (zugehörige echte Quell-URL), organizer.
  category: theater,kino,sport,musik,natur,basteln,familienzentrum,museum,festival,spielplatz,sonstiges.
  Keinen Termin aus einem Angebots-Enddatum ableiten. Bei unbestätigtem Tag/Uhrzeit eventDate=null. Nur belegte Angebote ausgeben; ohne Treffer [].
''';

    return _callWithGrounding(groundingPrompt, city);
  }

  // ─── Backend-Proxy mit Google Search Grounding ─────────────────────────────

  /// Events brauchen ein Modell mit zuverlässigem Google Search Grounding.
  /// gemini-3.5-flash ist stabil und günstig für Web-Suche.
  static const String _groundingModel = 'gemini-3.5-flash';

  Future<List<DiscoveredEvent>> _callWithGrounding(
      String prompt, String city) async {
    final response = await _aiService
        .generate(prompt, useGoogleSearch: true)
        .timeout(const Duration(seconds: 35));
    return _parseAgentResponse(
      response.text,
      city,
      groundingUrls: response.groundingUrls,
    );
  }

  // ─── Parser ────────────────────────────────────────────────────────────────

  List<DiscoveredEvent> _parseAgentResponse(String raw, String city,
      {List<String> groundingUrls = const []}) {
    try {
      final repairedJson = _extractAndRepairJsonArray(raw);
      if (repairedJson == null || repairedJson.isEmpty) {
        throw const FormatException('No event JSON array in AI response');
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
      rethrow;
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
    if (openBrackets > closeBrackets) {
      jsonChunk += ']' * (openBrackets - closeBrackets);
    }

    return jsonChunk.trim();
  }

  /// Gibt null zurück für Platzhalter-URLs wie "https://..." oder ungültige URIs.
  String? _validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    // Platzhalter ablehnen
    if (trimmed == 'https://...' ||
        trimmed == 'http://...' ||
        trimmed.endsWith('/...')) {
      return null;
    }
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
    if (month >= 3 && month <= 5) {
      return 'Frühling (Ostermärkte, Stadtfeste, Fahrrad-Touren)';
    }
    if (month >= 6 && month <= 8) {
      return 'Sommer (Freibäder, Freilichtbühnen, Stadtfeste, Ferienprogramme)';
    }
    if (month >= 9 && month <= 11) {
      return 'Herbst (Erntedank, Halloween-Specials, Indoor-Angebote)';
    }
    return 'Winter (Weihnachtsmärkte, Eislaufen, Winterferienprogramme)';
  }

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[<>{}\[\]\\]'), '').trim();

  String _generateId() =>
      'ev_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 9000}';
}
