import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_cache_service.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/models/event_attendee.dart';
import 'package:parentpeak/logic/parent_friends_service.dart';

/// Service für Community-Events — verbindet App mit Backend.
///
/// Endpoints:
///   POST   /api/community-events              — Event erstellen
///   GET    /api/community-events?city=X       — Events in einer Stadt laden
///   POST   /api/community-events/:id/flag     — Event melden
///   POST   /api/community-events/:id/interest — Interesse zeigen
///   GET    /api/community-events/:id/attendees — Teilnehmer-Liste
///   DELETE /api/community-events/:id          — Eigenes Event loeschen
///
/// Rate-Limiting: Max 3 Events pro Tag pro User (Server-seitig geprueft).
class CommunityEventService extends ChangeNotifier {
  static final CommunityEventService instance = CommunityEventService._();
  CommunityEventService._();

  BackendApiClient? _api;
  List<CommunityEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  static const int maxEventsPerDay = 3;
  int _todayCreatedCount = 0;
  DateTime? _todayDate;

  List<CommunityEvent> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get canCreateMore => _todayCreatedCount < maxEventsPerDay;
  int get remainingToday => maxEventsPerDay - _todayCreatedCount;

  void _ensureApi() {
    _api ??= BackendServiceFactory.createApiClient();
  }

  /// Laedt alle Events für eine Stadt (Community + KI gemischt).
  Future<List<CommunityEvent>> loadEvents({
    required String city,
    List<String> childAges = const [],
    bool includeAiEvents = true,
  }) async {
    _ensureApi();
    _isLoading = true;
    _error = null;
    notifyListeners();

    final allEvents = <CommunityEvent>[];

    // 1. Community-Events vom Backend
    try {
      if (_api != null) {
        final response = await _api!.getJson(
          '/api/community-events?city=${Uri.encodeComponent(city)}&limit=20',
        );
        if (response is List) {
          final communityEvents = response
              .map((e) => CommunityEvent.fromJson(e as Map<String, dynamic>))
              .where((e) => e.isVisible)
              .toList();
          allEvents.addAll(communityEvents);
        }
      }
    } catch (e) {
      debugPrint('CommunityEventService.loadEvents: Backend-Fehler: $e');
    }

    // 2. KI-Events aus Cache (oder frisch generieren)
    if (includeAiEvents) {
      try {
        final aiEvents = await EventCacheService.instance.getEvents(
          city: city,
          childAges: childAges,
        );
        allEvents.addAll(aiEvents);
      } catch (e) {
        debugPrint('CommunityEventService.loadEvents: KI-Cache-Fehler: $e');
      }
    }

    // Sortieren: Community zuerst, dann KI, jeweils nach Datum
    allEvents.sort((a, b) {
      // Verifizierte Partner zuerst
      if (a.isVerified && !b.isVerified) return -1;
      if (!a.isVerified && b.isVerified) return 1;
      // Community vor KI
      if (a.source != EventSource.kiAgent && b.source == EventSource.kiAgent) {
        return -1;
      }
      if (a.source == EventSource.kiAgent && b.source != EventSource.kiAgent) {
        return 1;
      }
      // Dann nach Datum
      return a.eventDate.compareTo(b.eventDate);
    });

    _events = allEvents;
    _isLoading = false;
    notifyListeners();
    return allEvents;
  }

  /// Erstellt ein neues Community-Event.
  /// Gibt true zurück bei Erfolg, false bei Fehler.
  Future<bool> createEvent(CommunityEvent event) async {
    _ensureApi();

    // Rate-Limit Check
    _updateDayCounter();
    if (!canCreateMore) {
      _error =
          'Du hast heute schon $maxEventsPerDay Events erstellt. Morgen kannst du weitere hinzufuegen.';
      notifyListeners();
      return false;
    }

    try {
      if (_api == null) {
        _error = 'Backend nicht erreichbar';
        notifyListeners();
        return false;
      }

      await _api!.postJson('/api/community-events', event.toJson());
      _todayCreatedCount++;
      _error = null;

      // Lokal hinzufuegen
      _events.insert(0, event);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CommunityEventService.createEvent: $e');
      _error = 'Event konnte nicht gespeichert werden: $e';
      notifyListeners();
      return false;
    }
  }

  /// Meldet ein Event (Community-Flagging).
  /// Nach 3 Meldungen wird das Event automatisch versteckt.
  Future<bool> flagEvent(String eventId, String reason) async {
    _ensureApi();
    try {
      if (_api == null) return false;

      final uid = AuthService.instance.currentUser?.uid ?? 'guest';
      await _api!.postJson('/api/community-events/$eventId/flag', {
        'userId': uid,
        'reason': reason,
      });

      // Lokal Flag-Count erhoehen
      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx != -1) {
        final old = _events[idx];
        _events[idx] = CommunityEvent.fromJson({
          ...old.toJson(),
          'flagCount': old.flagCount + 1,
          'isHidden': old.flagCount + 1 >= 3,
        });
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('CommunityEventService.flagEvent: $e');
      return false;
    }
  }

  /// Zeigt Interesse an einem Event (mit Name + optionaler Nachricht).
  Future<bool> showInterest(String eventId, {String? message}) async {
    _ensureApi();
    try {
      final uid = AuthService.instance.currentUser?.uid ?? 'guest';
      final name =
          AuthService.instance.currentUser?.displayName ?? 'Familien-Kontakt';

      if (_api != null) {
        await _api!.postJson('/api/community-events/$eventId/interest', {
          'userId': uid,
          'displayName': name,
          'message': message,
        });
      }

      // Lokal Interest-Count erhoehen
      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx != -1) {
        final old = _events[idx];
        _events[idx] = CommunityEvent.fromJson({
          ...old.toJson(),
          'interestCount': old.interestCount + 1,
        });
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('CommunityEventService.showInterest: $e');
      return false;
    }
  }

  /// Laedt die Teilnehmer-Liste eines Events.
  Future<EventAttendeesResult> getAttendees(String eventId) async {
    _ensureApi();
    try {
      if (_api == null) {
        return const EventAttendeesResult(attendees: [], total: 0);
      }

      final response = await _api!.getJson('/api/community-events/$eventId/attendees');
      final list = (response['attendees'] as List? ?? [])
          .map((e) => EventAttendee.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = response['total'] as int? ?? list.length;

      final friendsSvc = ParentFriendsService.instance;
      await friendsSvc.load();
      final markedList = list.map((a) {
        if (!friendsSvc.isFriendByUserId(a.userId)) return a;
        return EventAttendee(
          userId: a.userId,
          displayName: a.displayName,
          message: a.message,
          createdAt: a.createdAt,
          isNetworkContact: true,
        );
      }).toList();
      final networkContacts =
          markedList.where((a) => a.isNetworkContact).toList();
      return EventAttendeesResult(
        attendees: markedList,
        total: total,
        networkContacts: networkContacts,
      );
    } catch (e) {
      debugPrint('CommunityEventService.getAttendees: $e');
      return const EventAttendeesResult(attendees: [], total: 0);
    }
  }

  /// Loescht ein eigenes Event.
  Future<bool> deleteEvent(String eventId) async {
    _ensureApi();
    try {
      if (_api != null) {
        final uid = AuthService.instance.currentUser?.uid ?? '';
        await _api!.delete('/api/community-events/$eventId?creatorId=${Uri.encodeComponent(uid)}');
      }
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CommunityEventService.deleteEvent: $e');
      return false;
    }
  }

  // ─── Rate-Limit Helper ────────────────────────────────────────────────────

  void _updateDayCounter() {
    final today = DateTime.now();
    if (_todayDate == null ||
        _todayDate!.day != today.day ||
        _todayDate!.month != today.month) {
      _todayCreatedCount = 0;
      _todayDate = today;
    }
  }
}
