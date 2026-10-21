import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/services/location_service.dart';

class TreasureDiscoveryResult {
  final List<TreasureListing> listings;
  final String scope;
  final bool globalDigitalMode;
  final bool showInviteBanner;

  const TreasureDiscoveryResult({
    required this.listings,
    required this.scope,
    required this.globalDigitalMode,
    required this.showInviteBanner,
  });
}

class TreasureListingService {
  TreasureListingService._();

  static final TreasureListingService instance = TreasureListingService._();
  static const String _storageKey = 'treasure_listings.v1';
  static const String _draftStorageKey = 'treasure_upload_draft.v1';
  static const double _localDiscoveryRadiusKm = 25;

  List<TreasureListing>? _cache;
  final TreasureBackendService _backendService = TreasureBackendService();
  String? lastSyncError;

  bool get isBackendEnabled => _backendService.isEnabled;

  Future<TreasureDiscoveryResult> loadListingsWithFallback() async {
    if (_backendService.isEnabled) {
      final loc = LocationService.instance;
      if (!loc.hasLocation) {
        _cache = [];
        lastSyncError =
            'Standort benötigt, um Angebote in deiner Nähe zu zeigen.';
        return const TreasureDiscoveryResult(
          listings: [],
          scope: '25km',
          globalDigitalMode: false,
          showInviteBanner: false,
        );
      }

      final lat = loc.latitude;
      final lng = loc.longitude;
      final remoteListings = await _backendService.fetchTreasures(
        radiusKm: _localDiscoveryRadiusKm,
        latitude: lat,
        longitude: lng,
      );
      _cache = remoteListings;
      await _persist();
      lastSyncError = _backendService.lastSyncError;

      return TreasureDiscoveryResult(
        listings: List<TreasureListing>.from(_cache!),
        scope: '25km',
        globalDigitalMode: false,
        showInviteBanner: false,
      );
    }

    final local = await loadListings();
    return TreasureDiscoveryResult(
      listings: local,
      scope: 'local-cache',
      globalDigitalMode: false,
      showInviteBanner: false,
    );
  }

  Future<List<TreasureListing>> loadListings() async {
    if (_cache != null) {
      return List<TreasureListing>.from(_cache!);
    }

    if (_backendService.isEnabled) {
      final loc = LocationService.instance;
      if (!loc.hasLocation) {
        _cache = [];
        lastSyncError =
            'Standort benötigt, um Angebote in deiner Nähe zu zeigen.';
        return const [];
      }
      final remoteListings = await _backendService.fetchTreasures(
        radiusKm: _localDiscoveryRadiusKm,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      _cache = remoteListings;
      await _persist();
      lastSyncError = _backendService.lastSyncError;
      return List<TreasureListing>.from(_cache!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _cache = decoded
              .map((item) =>
                  TreasureListing.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          return List<TreasureListing>.from(_cache!);
        }
      }
    } catch (e) {
      // Continue with empty state when persisted data cannot be read.
    }

    _cache = [];
    return List<TreasureListing>.from(_cache!);
  }

  Future<TreasureListing?> createListing(
    TreasureListing listing, {
    String? userId,
  }) async {
    if (listing.latitude == null || listing.longitude == null) {
      lastSyncError = 'Standort benötigt, um ein Angebot zu veröffentlichen.';
      return null;
    }

    if (!_backendService.isEnabled) {
      lastSyncError = 'Verschenkmarkt ist gerade nicht verfügbar.';
      return null;
    }

    final resolvedUserId = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : AuthService.instance.currentUser?.uid;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      lastSyncError = 'Bitte melde dich an, um ein Angebot zu veröffentlichen.';
      return null;
    }

    final created = await _backendService.createTreasure(
      listing: listing,
      userId: resolvedUserId,
      location: listing.locationLabel ?? 'Familien-Nachbarschaft',
      latitude: listing.latitude!,
      longitude: listing.longitude!,
    );
    if (created == null) {
      lastSyncError = _backendService.lastSyncError;
      return null;
    }

    _cache = [
      created,
      ...?_cache?.where((item) => item.id != created.id),
    ];
    await _persist();
    lastSyncError = null;
    return created;
  }

  static const String _reservedStorageKey = 'treasure_reserved_ids.v1';

  /// IDs der reservierten Schätze (lokal, damit "reserviert" sofort sichtbar ist).
  Future<Set<String>> loadReservedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_reservedStorageKey) ?? const []).toSet();
  }

  Future<bool> reserveListing({
    required String listingId,
    String? preferredSlot,
    String? handoverMode,
    String? message,
  }) async {
    final userId = AuthService.instance.currentUser?.uid ?? 'guest';

    if (_backendService.isEnabled) {
      final ok = await _backendService.reserveTreasure(
        treasureId: listingId,
        requesterUserId: userId,
        preferredSlot: preferredSlot,
        handoverMode: handoverMode,
        message: message,
      );
      lastSyncError = ok ? null : _backendService.lastSyncError;
      if (!ok) return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final reserved =
        (prefs.getStringList(_reservedStorageKey) ?? <String>[]).toSet();
    reserved.add(listingId);
    await prefs.setStringList(_reservedStorageKey, reserved.toList());
    return true;
  }

  Future<bool> deleteListing({required String listingId}) async {
    final userId = AuthService.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      lastSyncError = 'Bitte melde dich an, um deine Anzeige zu löschen.';
      return false;
    }

    if (_backendService.isEnabled) {
      final deleted = await _backendService.deleteTreasure(
        treasureId: listingId,
        userId: userId,
      );
      lastSyncError = deleted ? null : _backendService.lastSyncError;
      if (!deleted) return false;
    }

    _cache = (_cache ?? const <TreasureListing>[])
        .where((item) => item.id != listingId)
        .toList();
    await _persist();
    return true;
  }

  Future<TreasureMineOverview?> loadMine() async {
    final userId = AuthService.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      lastSyncError = 'Bitte melde dich an, um deine Anzeigen zu sehen.';
      return null;
    }
    final overview = await _backendService.fetchMine(userId: userId);
    lastSyncError = _backendService.lastSyncError;
    return overview;
  }

  Future<bool> confirmHandover({
    required String listingId,
    required String handoverId,
  }) =>
      _updateHandoverStatus(listingId, handoverId, 'confirm');

  Future<bool> completeHandover({
    required String listingId,
    required String handoverId,
  }) =>
      _updateHandoverStatus(listingId, handoverId, 'complete');

  Future<bool> cancelReservation({required String listingId}) async {
    final userId = AuthService.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return false;
    final cancelled = await _backendService.cancelReservation(
      treasureId: listingId,
      requesterUserId: userId,
    );
    lastSyncError = cancelled ? null : _backendService.lastSyncError;
    return cancelled;
  }

  Future<bool> _updateHandoverStatus(
    String listingId,
    String handoverId,
    String action,
  ) async {
    final userId = AuthService.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return false;
    final updated = await _backendService.updateHandoverStatus(
      treasureId: listingId,
      handoverId: handoverId,
      userId: userId,
      action: action,
    );
    lastSyncError = updated ? null : _backendService.lastSyncError;
    return updated;
  }

  Future<bool> reportListing({
    required String listingId,
    required String reason,
    String? note,
    String? reporterUserId,
  }) async {
    if (!_backendService.isEnabled) {
      lastSyncError = 'Backend nicht verfügbar. Meldung lokal markiert.';
      return false;
    }

    final resolvedReporter =
        (reporterUserId != null && reporterUserId.trim().isNotEmpty)
            ? reporterUserId.trim()
            : (AuthService.instance.currentUser?.uid ?? 'anonymous-user');

    final sent = await _backendService.reportTreasure(
      treasureId: listingId,
      reporterUserId: resolvedReporter,
      reason: reason,
      note: note,
    );
    lastSyncError = _backendService.lastSyncError;
    return sent;
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftStorageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      // Ignore corrupted drafts and continue with empty state.
    }
    return null;
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftStorageKey, jsonEncode(draft));
    } catch (e) {
      // Ignore transient local persistence failures.
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftStorageKey);
    } catch (e) {
      // Ignore transient local persistence failures.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_cache?.map((item) => item.toMap()).toList() ?? const []),
      );
    } catch (e) {
      // Ignore transient local persistence failures.
    }
  }
}
