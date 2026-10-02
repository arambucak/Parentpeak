import 'package:parentpeak/models/event_participation.dart';
import 'package:parentpeak/logic/event_backend_service.dart';

class ParticipationService {
  static final List<EventParticipation> _participations = [];
  final EventBackendService _backend;
  ParticipationService({EventBackendService? backendService})
      : _backend = backendService ?? EventBackendService();

  Never _throwBackendRequired(String action) {
    throw StateError(
      _backend.lastSyncError ?? '$action ist aktuell nicht mit dem Backend verbunden.',
    );
  }

  void _storeLocal(EventParticipation participation) {
    final index = _participations.indexWhere((p) => p.id == participation.id);
    if (index == -1) {
      _participations.add(participation);
    } else {
      _participations[index] = participation;
    }
  }

  // Frage Teilnahme an
  Future<EventParticipation> requestParticipation({
    required String eventId,
    required String userId,
  }) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Teilnahmeanfrage');
    }

    final remote = await _backend.requestParticipation(
      eventId: eventId,
      userId: userId,
    );
    if (remote == null) {
      _throwBackendRequired('Teilnahmeanfrage');
    }

    _storeLocal(remote);
    return remote;
  }

  // Genehmige Teilnahme-Anfrage
  Future<bool> approveParticipation(String participationId) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Teilnahme genehmigen');
    }

    final remote = await _backend.respondToParticipation(
      participationId: participationId,
      accept: true,
    );
    if (remote == null) {
      _throwBackendRequired('Teilnahme genehmigen');
    }

    _storeLocal(remote);
    return true;
  }

  // Lehne Teilnahme-Anfrage ab
  Future<bool> declineParticipation(String participationId) async {
    if (!_backend.isEnabled) {
      _throwBackendRequired('Teilnahme ablehnen');
    }

    final remote = await _backend.respondToParticipation(
      participationId: participationId,
      accept: false,
    );
    if (remote == null) {
      _throwBackendRequired('Teilnahme ablehnen');
    }

    _storeLocal(remote);
    return true;
  }

  // Hole Partizipation-Details
  Future<EventParticipation?> getParticipation(String participationId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      return _participations.firstWhere((p) => p.id == participationId);
    } catch (e) {
      return null;
    }
  }

  // Prüfe ob User teilnehmer eines Events ist
  Future<EventParticipation?> getParticipationByUserAndEvent({
    required String userId,
    required String eventId,
  }) async {
    if (!_backend.isEnabled) _throwBackendRequired('Teilnahme laden');
    final remote = await _backend.fetchParticipationByUserAndEvent(
        userId: userId,
        eventId: eventId,
      );
    if (remote != null) _storeLocal(remote);
    return remote;
  }

  Future<void> withdrawParticipation({required String eventId, required String userId}) async {
    await _backend.withdrawParticipation(eventId: eventId, userId: userId);
    _participations.removeWhere((item) => item.eventId == eventId && item.userId == userId);
  }

  // Hole alle genehmigten Teilnehmer eines Events
  Future<List<EventParticipation>> getApprovedParticipantsForEvent(
      String eventId) async {
    if (!_backend.isEnabled) _throwBackendRequired('Teilnehmer laden');
    return _backend.fetchApprovedParticipantsForEvent(eventId);
  }
}
