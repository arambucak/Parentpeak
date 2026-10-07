import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
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

class TreasureRemoteCommitException implements Exception {
  const TreasureRemoteCommitException({
    required this.action,
    required this.cause,
    this.listing,
  });
  final String action;
  final Object cause;
  final TreasureListing? listing;
}

class TreasureListingService {
  TreasureListingService({
    TreasureAccountStore? store,
    TreasureBackendService? backend,
    this.expectedScope,
  }) : store = store ?? TreasureAccountStore.instance,
       _backendService = backend ?? TreasureBackendService() {
    _scope = this.store.scope;
    AuthService.instance.addListener(_accountChanged);
  }

  static final instance = TreasureListingService();
  final TreasureAccountStore store;
  final String? expectedScope;
  final TreasureBackendService _backendService;
  static const double _localDiscoveryRadiusKm = 25;
  List<TreasureListing>? _cache;
  late String _scope;
  int _revision = 0;
  bool _disposed = false;
  String? lastSyncError;

  TreasureListingService forScope(String scope) => TreasureListingService(
    store: store,
    backend: _backendService,
    expectedScope: scope,
  );

  void dispose() {
    _disposed = true;
    AuthService.instance.removeListener(_accountChanged);
    _clear();
  }

  void _clear() {
    _cache = null;
    lastSyncError = null;
    _backendService.lastSyncError = null;
    _revision++;
  }

  void _accountChanged() {
    if (_scope == store.scope) return;
    _scope = store.scope;
    _clear();
  }

  String get scope {
    if (_disposed) throw StateError('Treasure service has been disposed');
    _accountChanged();
    final expected = expectedScope ?? store.scope;
    store.requireScope(expected);
    return expected;
  }

  bool get isBackendEnabled => _backendService.isEnabled;

  Future<T> _run<T>(
    Future<T> Function(String scope, void Function() guard) operation,
  ) async {
    final owner = scope;
    final revision = _revision;
    void guard() {
      store.requireScope(owner);
      if (_disposed || revision != _revision) {
        throw const TreasureAccountChanged();
      }
    }

    try {
      final result = await operation(owner, guard);
      guard();
      return result;
    } catch (error) {
      debugPrint('Treasure operation failed: $error');
      if (store.scope == owner && revision == _revision) {
        _cache = null;
        lastSyncError = 'treasure_storage_failed';
      }
      rethrow;
    }
  }

  Future<void> _persist(String owner) async {
    final snapshot = _cache?.map((item) => item.toMap()).toList() ?? [];
    await store.update(
      (data) => data[TreasureAccountStore.feedKey] = snapshot,
      expectedScope: owner,
    );
  }

  Future<TreasureDiscoveryResult> loadListingsWithFallback() =>
      _run((owner, guard) async {
        if (_backendService.isEnabled) {
          _cache = null;
          final listings = await _load(owner, guard);
          return TreasureDiscoveryResult(
            listings: listings,
            scope: '25km',
            globalDigitalMode: false,
            showInviteBanner: false,
          );
        }
        return TreasureDiscoveryResult(
          listings: await _load(owner, guard),
          scope: 'local-cache',
          globalDigitalMode: false,
          showInviteBanner: false,
        );
      });

  Future<List<TreasureListing>> loadListings() => _run(_load);

  Future<List<TreasureListing>> _load(
    String owner,
    void Function() guard,
  ) async {
    if (_cache != null) return List.of(_cache!);
    if (_backendService.isEnabled) {
      final loc = LocationService.instance;
      if (!loc.hasLocation) {
        lastSyncError = 'treasure_location_required';
        return [];
      }
      final listings = await _backendService.fetchTreasures(
        radiusKm: _localDiscoveryRadiusKm,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      guard();
      _cache = listings.where((item) => item.isAvailable).toList();
      lastSyncError = _backendService.lastSyncError;
      await _persist(owner);
      return List.of(_cache!);
    }
    final data = await store.read(expectedScope: owner);
    guard();
    _cache = (data[TreasureAccountStore.feedKey] as List? ?? [])
        .map(
          (item) =>
              TreasureListing.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .where((item) => item.isAvailable)
        .toList();
    return List.of(_cache!);
  }

  Future<TreasureListing?> createListing(
    TreasureListing listing, {
    String? userId,
  }) => _run((owner, guard) async {
    if (listing.latitude == null || listing.longitude == null) {
      lastSyncError = 'treasure_location_required';
      return null;
    }
    if (!_backendService.isEnabled) {
      lastSyncError = 'treasure_market_unavailable';
      return null;
    }
    final uid = store.userId;
    if (uid == null || (userId != null && userId != uid)) {
      lastSyncError = 'treasure_signin_required';
      return null;
    }
    final created = await _backendService.createTreasure(
      listing: listing,
      userId: uid,
      location: listing.locationLabel ?? 'Familien-Nachbarschaft',
      latitude: listing.latitude!,
      longitude: listing.longitude!,
    );
    guard();
    if (created == null) {
      lastSyncError = _backendService.lastSyncError;
      return null;
    }
    _cache = [
      if (created.isAvailable) created,
      ...?_cache?.where((item) => item.id != created.id),
    ];
    try {
      await _persist(owner);
    } on TreasureAccountChanged {
      rethrow;
    } catch (error) {
      throw TreasureRemoteCommitException(
        action: 'create',
        cause: error,
        listing: created,
      );
    }
    lastSyncError = null;
    return created;
  });

  Future<Set<String>> loadReservedIds() => _run((owner, guard) async {
    final data = await store.read(expectedScope: owner);
    return Set<String>.from(
      data[TreasureAccountStore.reservedKey] as List? ?? [],
    );
  });

  Future<bool> reserveListing({
    required String listingId,
    String? preferredSlot,
    String? handoverMode,
    String? message,
  }) => _run((owner, guard) async {
    final uid = store.userId;
    if (uid == null) {
      lastSyncError = 'treasure_signin_required';
      return false;
    }
    if (!_backendService.isEnabled) {
      lastSyncError = 'treasure_reservation_offline';
      return false;
    }
    if (_backendService.isEnabled) {
      final ok = await _backendService.reserveTreasure(
        treasureId: listingId,
        requesterUserId: uid,
        preferredSlot: preferredSlot,
        handoverMode: handoverMode,
        message: message,
      );
      guard();
      lastSyncError = ok ? null : _backendService.lastSyncError;
      if (!ok) return false;
    }
    try {
      await store.update((data) {
        data[TreasureAccountStore.reservedKey] = {
          ...?data[TreasureAccountStore.reservedKey] as List?,
          listingId,
        }.toList();
      }, expectedScope: owner);
    } on TreasureAccountChanged {
      rethrow;
    } catch (error) {
      throw TreasureRemoteCommitException(action: 'reserve', cause: error);
    }
    return true;
  });

  Future<bool> deleteListing({required String listingId}) =>
      _run((owner, guard) async {
        final uid = store.userId;
        if (uid == null) {
          lastSyncError = 'treasure_signin_required';
          return false;
        }
        if (_backendService.isEnabled) {
          final deleted = await _backendService.deleteTreasure(
            treasureId: listingId,
            userId: uid,
          );
          guard();
          lastSyncError = deleted ? null : _backendService.lastSyncError;
          if (!deleted) return false;
        }
        final listings = await _load(owner, guard);
        guard();
        _cache = listings.where((item) => item.id != listingId).toList();
        await _persist(owner);
        return true;
      });

  Future<TreasureMineOverview?> loadMine() => _run((owner, guard) async {
    final uid = store.userId;
    if (uid == null) {
      lastSyncError = 'treasure_signin_required';
      return null;
    }
    final overview = await _backendService.fetchMine(userId: uid);
    guard();
    lastSyncError = _backendService.lastSyncError;
    return overview;
  });

  Future<bool> confirmHandover({
    required String listingId,
    required String handoverId,
  }) => _updateHandoverStatus(listingId, handoverId, 'confirm');
  Future<bool> completeHandover({
    required String listingId,
    required String handoverId,
  }) => _updateHandoverStatus(listingId, handoverId, 'complete');

  Future<bool> cancelReservation({required String listingId}) =>
      _run((owner, guard) async {
        final uid = store.userId;
        if (uid == null) return false;
        final ok = await _backendService.cancelReservation(
          treasureId: listingId,
          requesterUserId: uid,
        );
        guard();
        lastSyncError = ok ? null : _backendService.lastSyncError;
        if (ok) {
          try {
            await store.update((data) {
              final ids = Set<String>.from(
                data[TreasureAccountStore.reservedKey] as List? ?? [],
              );
              ids.remove(listingId);
              data[TreasureAccountStore.reservedKey] = ids.toList();
            }, expectedScope: owner);
          } on TreasureAccountChanged {
            rethrow;
          } catch (error) {
            throw TreasureRemoteCommitException(action: 'cancel', cause: error);
          }
        }
        return ok;
      });

  Future<bool> _updateHandoverStatus(
    String listingId,
    String handoverId,
    String action,
  ) => _run((owner, guard) async {
    final uid = store.userId;
    if (uid == null) return false;
    final ok = await _backendService.updateHandoverStatus(
      treasureId: listingId,
      handoverId: handoverId,
      userId: uid,
      action: action,
    );
    guard();
    lastSyncError = ok ? null : _backendService.lastSyncError;
    return ok;
  });

  Future<bool> reportListing({
    required String listingId,
    required String reason,
    String? note,
    String? reporterUserId,
  }) => _run((owner, guard) async {
    if (!_backendService.isEnabled) {
      lastSyncError = 'treasureReportLocalOnly';
      return false;
    }
    final uid = store.userId;
    if (uid == null || (reporterUserId != null && reporterUserId != uid)) {
      lastSyncError = 'treasure_account_changed';
      return false;
    }
    final sent = await _backendService.reportTreasure(
      treasureId: listingId,
      reporterUserId: uid,
      reason: reason,
      note: note,
    );
    guard();
    lastSyncError = _backendService.lastSyncError;
    return sent;
  });

  Future<Map<String, dynamic>?> loadDraft() => _run((owner, guard) async {
    final data = await store.read(expectedScope: owner);
    return data[TreasureAccountStore.draftKey] as Map<String, dynamic>?;
  });
  Future<void> saveDraft(Map<String, dynamic> draft) {
    final snapshot = jsonDecode(jsonEncode(draft)) as Map<String, dynamic>;
    return _run((owner, guard) async {
      await store.update(
        (data) => data[TreasureAccountStore.draftKey] = snapshot,
        expectedScope: owner,
      );
    });
  }

  Future<void> clearDraft() => _run((owner, guard) async {
    await store.update(
      (data) => data[TreasureAccountStore.draftKey] = null,
      expectedScope: owner,
    );
  });
}
