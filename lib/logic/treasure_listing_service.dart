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

  List<TreasureListing>? _cache;
  final TreasureBackendService _backendService = TreasureBackendService();
  String? lastSyncError;

  bool get isBackendEnabled => _backendService.isEnabled;

  Future<TreasureDiscoveryResult> loadListingsWithFallback() async {
    if (_backendService.isEnabled) {
      const radii = <double>[10, 50, 100, 1200];
      const scopes = <String>['10km', '50km', '100km', 'country'];

      final loc = LocationService.instance;
      final lat = loc.latitude;
      final lng = loc.longitude;

      for (var i = 0; i < radii.length; i++) {
        final remoteListings = await _backendService.fetchTreasures(
          radiusKm: radii[i],
          latitude: lat,
          longitude: lng,
        );
        if (remoteListings.isNotEmpty) {
          _cache = remoteListings;
          await _persist();
          lastSyncError = _backendService.lastSyncError;
          return TreasureDiscoveryResult(
            listings: List<TreasureListing>.from(_cache!),
            scope: scopes[i],
            globalDigitalMode: false,
            showInviteBanner: i > 0,
          );
        }
      }

      final fallbackDigital = <TreasureListing>[
        TreasureListing(
          id: 'digital-room-kids-books',
          title: 'Globaler Tauschraum: Kinderbücher',
          category: 'Bücher',
          sizeAge: '0-9 Jahre',
          conditionKey: 'round2',
          distanceMeters: 0,
          colorLabel: 'Online',
          note:
              'Digitale Matching-Liste für Familien, die Kinderbücher verschenken oder suchen.',
          locationLabel: 'Online',
          createdAt: DateTime.now(),
        ),
        TreasureListing(
          id: 'digital-room-clothes',
          title: 'Globaler Tauschraum: Kleidung',
          category: 'Kleidung',
          sizeAge: 'Baby bis Schule',
          conditionKey: 'round2',
          distanceMeters: 0,
          colorLabel: 'Online',
          note:
              'Kleidungspakete nach Größe sortiert mit direktem Elternkontakt.',
          locationLabel: 'Online',
          createdAt: DateTime.now(),
        ),
        TreasureListing(
          id: 'digital-room-toys',
          title: 'Globaler Tauschraum: Spielzeug',
          category: 'Spielzeug',
          sizeAge: '2-10 Jahre',
          conditionKey: 'round2',
          distanceMeters: 0,
          colorLabel: 'Online',
          note:
              'Themenbasierter digitaler Marktplatz für Spielsachen und Lernmaterialien.',
          locationLabel: 'Online',
          createdAt: DateTime.now(),
        ),
      ];

      return TreasureDiscoveryResult(
        listings: fallbackDigital,
        scope: 'global',
        globalDigitalMode: true,
        showInviteBanner: true,
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
      final remoteListings = await _backendService.fetchTreasures(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      if (remoteListings.isNotEmpty || _backendService.lastSyncError == null) {
        _cache = remoteListings;
        await _persist();
        lastSyncError = _backendService.lastSyncError;
        return List<TreasureListing>.from(_cache!);
      }
      lastSyncError = _backendService.lastSyncError;
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

  Future<List<TreasureListing>> createListing(
    TreasureListing listing, {
    String? userId,
  }) async {
    if (_backendService.isEnabled) {
      final resolvedUserId = (userId != null && userId.trim().isNotEmpty)
          ? userId.trim()
          : (AuthService.instance.currentUser?.uid ?? 'anonymous-user');
      final created = await _backendService.createTreasure(
        listing: listing,
        userId: resolvedUserId,
        location: listing.locationLabel ?? 'Familien-Nachbarschaft',
        latitude: listing.latitude ?? 52.5200,
        longitude: listing.longitude ?? 13.4050,
      );

      if (created != null) {
        final listings = await loadListings();
        final merged = [
          created,
          ...listings.where((item) => item.id != created.id),
        ];
        _cache = merged;
        await _persist();
        lastSyncError = _backendService.lastSyncError;
        return List<TreasureListing>.from(_cache!);
      }
      lastSyncError = _backendService.lastSyncError;
    }

    final listings = await loadListings();
    listings.insert(0, listing);
    _cache = listings;
    await _persist();
    lastSyncError = 'Backend nicht erreichbar - lokal gespeichert.';
    return List<TreasureListing>.from(_cache!);
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
