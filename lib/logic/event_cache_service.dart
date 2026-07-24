import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/models/discovered_event.dart';

/// Caching-Layer fuer KI-entdeckte Events.
///
/// Funktionsweise:
///   - Speichert KI-Events 24h lokal (SharedPreferences)
///   - Bei erneutem Aufruf: Cache zurueckgeben statt neuer API-Call
///   - Qualitaets-Validierung: nur Events mit Datum + Ort + Zukunft
///   - Auto-Refresh nach 24h oder bei Stadt-Wechsel
///   - Konvertiert DiscoveredEvent -> CommunityEvent (einheitliches Model)
class EventCacheService {
  static final EventCacheService instance = EventCacheService._();
  EventCacheService._();

  static const _cacheKey = 'events.ai_cache';
  static const _cacheTimestampKey = 'events.ai_cache_timestamp';
  static const _cacheCityKey = 'events.ai_cache_city';
  static const Duration _cacheDuration = Duration(hours: 24);

  List<CommunityEvent>? _memoryCache;
  String? _memoryCacheCity;

  /// Holt Events aus Cache oder generiert neue via KI-Agent.
  /// Gibt sofort gecachte Events zurueck wenn vorhanden (0ms Ladezeit).
  Future<List<CommunityEvent>> getEvents({
    required String city,
    List<String> childAges = const [],
    bool forceRefresh = false,
  }) async {
    final normalizedCity = city.trim().toLowerCase();

    // 1. Memory-Cache (schnellster Zugriff)
    if (!forceRefresh &&
        _memoryCache != null &&
        _memoryCacheCity == normalizedCity) {
      return _filterVisible(_memoryCache!);
    }

    // 2. Disk-Cache pruefen
    if (!forceRefresh) {
      final cached = await _loadFromDisk(normalizedCity);
      if (cached != null) {
        _memoryCache = cached;
        _memoryCacheCity = normalizedCity;
        return _filterVisible(cached);
      }
    }

    // 3. Frischer KI-Call
    final events = await _fetchAndCache(city, childAges);
    return _filterVisible(events);
  }

  /// Prueft ob der Cache aktuell ist.
  Future<bool> isCacheValid(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCity = prefs.getString(_cacheCityKey);
    final timestamp = prefs.getInt(_cacheTimestampKey);

    if (cachedCity == null || timestamp == null) return false;
    if (cachedCity != city.trim().toLowerCase()) return false;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) < _cacheDuration;
  }

  /// Loescht den Cache manuell (z.B. bei Stadt-Wechsel).
  Future<void> clearCache() async {
    _memoryCache = null;
    _memoryCacheCity = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
    await prefs.remove(_cacheCityKey);
  }

  // ─── Private Methoden ──────────────────────────────────────────────────────

  Future<List<CommunityEvent>?> _loadFromDisk(String normalizedCity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCity = prefs.getString(_cacheCityKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);
      final raw = prefs.getString(_cacheKey);

      if (cachedCity != normalizedCity || timestamp == null || raw == null) {
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) >= _cacheDuration) {
        return null; // Abgelaufen
      }

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CommunityEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('EventCacheService: Disk-Cache Lesefehler: $e');
      return null;
    }
  }

  Future<List<CommunityEvent>> _fetchAndCache(
      String city, List<String> childAges) async {
    try {
      final agent = EventDiscoveryAgent.instance;
      final discovered = await agent.discoverEvents(
        city: city,
        childAges: childAges,
      );

      // Konvertiere und validiere
      final events = discovered
          .map(_convertToUnifiedModel)
          .where(_validateQuality)
          .toList();

      // In Cache schreiben
      await _saveToDisk(events, city);

      _memoryCache = events;
      _memoryCacheCity = city.trim().toLowerCase();

      return events;
    } catch (e) {
      debugPrint('EventCacheService: Fetch fehlgeschlagen: $e');
      return _memoryCache ?? [];
    }
  }

  Future<void> _saveToDisk(List<CommunityEvent> events, String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(events.map((e) => e.toJson()).toList());
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_cacheCityKey, city.trim().toLowerCase());
    } catch (e) {
      debugPrint('EventCacheService: Disk-Cache Schreibfehler: $e');
    }
  }

  /// Konvertiert ein DiscoveredEvent in das einheitliche CommunityEvent.
  CommunityEvent _convertToUnifiedModel(DiscoveredEvent d) {
    return CommunityEvent(
      id: d.id,
      title: d.title,
      description: d.description,
      category: _mapCategory(d.category),
      ageGroups: _mapAgeLabels(d.ageLabels),
      venue: _guessVenue(d.category),
      location: d.location,
      city: d.cityHint,
      lat: d.latitude,
      lon: d.longitude,
      eventDate: d.eventDate ?? _nextWeekend(),
      isRecurring: d.isRecurring,
      recurringNote: d.recurringNote,
      price: d.price ?? 'kostenlos',
      isFree: d.price == null ||
          d.price!.toLowerCase().contains('kostenlos') ||
          d.price == '0',
      url: d.url,
      organizer: d.organizer ?? 'Lokal',
      creatorType: CreatorType.institution,
      source: EventSource.kiAgent,
      isVerified: false,
      creatorId: 'ki_agent',
      createdAt: d.discoveredAt,
      interestCount: d.interestCount,
    );
  }

  /// Qualitaets-Check: Nur Events die minimal-Anforderungen erfuellen.
  bool _validateQuality(CommunityEvent event) {
    // Muss einen Titel haben
    if (event.title.trim().length < 3) return false;

    // Muss einen Ort haben
    if (event.location.trim().isEmpty && event.city.trim().isEmpty) {
      return false;
    }

    // Datum muss in der Zukunft liegen (ausser recurring)
    if (!event.isRecurring && event.eventDate.isBefore(DateTime.now())) {
      return false;
    }

    // Beschreibung darf nicht leer sein
    if (event.description.trim().length < 5) return false;

    return true;
  }

  /// Filtert nur sichtbare Events (nicht expired, nicht hidden).
  List<CommunityEvent> _filterVisible(List<CommunityEvent> events) {
    return events.where((e) => e.isVisible).toList();
  }

  // ─── Mapping Helpers ──────────────────────────────────────────────────────

  EventCategory _mapCategory(DiscoveredEventCategory cat) {
    switch (cat) {
      case DiscoveredEventCategory.theater:
        return EventCategory.theater;
      case DiscoveredEventCategory.kino:
        return EventCategory.kino;
      case DiscoveredEventCategory.sport:
        return EventCategory.sport;
      case DiscoveredEventCategory.musik:
        return EventCategory.musik;
      case DiscoveredEventCategory.natur:
        return EventCategory.natur;
      case DiscoveredEventCategory.basteln:
        return EventCategory.basteln;
      case DiscoveredEventCategory.familienzentrum:
        return EventCategory.familienzentrum;
      case DiscoveredEventCategory.museum:
        return EventCategory.museum;
      case DiscoveredEventCategory.festival:
        return EventCategory.festival;
      case DiscoveredEventCategory.spielplatz:
        return EventCategory.spielplatz;
      case DiscoveredEventCategory.sonstiges:
        return EventCategory.sonstiges;
    }
  }

  List<EventAgeGroup> _mapAgeLabels(List<String> labels) {
    final groups = <EventAgeGroup>{};
    for (final label in labels) {
      final lower = label.toLowerCase();
      if (lower.contains('0') || lower.contains('baby') || lower.contains('1')) {
        groups.add(EventAgeGroup.baby);
      }
      if (lower.contains('2') || lower.contains('3') || lower.contains('kleinkind')) {
        groups.add(EventAgeGroup.kleinkind);
      }
      if (lower.contains('4') || lower.contains('5') || lower.contains('6') || lower.contains('kita') || lower.contains('vorschul')) {
        groups.add(EventAgeGroup.kita);
      }
      if (lower.contains('7') || lower.contains('8') || lower.contains('9') || lower.contains('10') || lower.contains('grundschul')) {
        groups.add(EventAgeGroup.grundschule);
      }
      if (lower.contains('11') || lower.contains('12') || lower.contains('teen') || lower.contains('14') || lower.contains('16')) {
        groups.add(EventAgeGroup.teenie);
      }
      if (lower.contains('alle') || lower.contains('all') || lower.contains('famili')) {
        groups.add(EventAgeGroup.alle);
      }
    }
    return groups.isEmpty ? [EventAgeGroup.alle] : groups.toList();
  }

  EventVenue _guessVenue(DiscoveredEventCategory cat) {
    switch (cat) {
      case DiscoveredEventCategory.natur:
      case DiscoveredEventCategory.spielplatz:
      case DiscoveredEventCategory.festival:
        return EventVenue.outdoor;
      case DiscoveredEventCategory.kino:
      case DiscoveredEventCategory.theater:
      case DiscoveredEventCategory.museum:
        return EventVenue.indoor;
      default:
        return EventVenue.beides;
    }
  }

  DateTime _nextWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = (6 - now.weekday) % 7;
    final saturday = now.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
    return DateTime(saturday.year, saturday.month, saturday.day, 10, 0);
  }
}
