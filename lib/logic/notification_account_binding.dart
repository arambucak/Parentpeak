import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_api_client.dart';

class NotificationAccountChanged implements Exception {
  const NotificationAccountChanged();
}

/// Serializes device-token ownership changes and invalidates pending requests.
class NotificationAccountBinding {
  NotificationAccountBinding({
    required this.currentUserId,
    required this.getToken,
    required this.deleteToken,
    required this.cancelReminders,
  });

  final String? Function() currentUserId;
  final Future<String?> Function() getToken;
  final Future<void> Function() deleteToken;
  final Future<void> Function() cancelReminders;
  Future<void> _tail = Future.value();
  String? _desiredOwner;
  String? _boundOwner;
  String? _boundToken;
  BackendApiClient? _boundClient;
  bool _registrationConfirmed = false;
  int _generation = 0;

  bool get isActive =>
      _desiredOwner != null && currentUserId() == _desiredOwner;

  bool acceptsMessage(String? owner) =>
      isActive && owner == _desiredOwner && owner == _boundOwner;

  void _require(String owner, int generation) {
    if (!isActive || _desiredOwner != owner || generation != _generation) {
      throw const NotificationAccountChanged();
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> bind(String owner, BackendApiClient client) {
    if (owner.isEmpty || currentUserId() != owner) {
      return Future.error(const NotificationAccountChanged());
    }
    if (_desiredOwner != owner) {
      _desiredOwner = owner;
      _generation++;
    }
    final generation = _generation;
    return _serialize(() async {
      _require(owner, generation);
      if (_boundOwner != null && _boundOwner != owner) {
        await _release();
        _require(owner, generation);
      }
      final token = await getToken().timeout(const Duration(seconds: 10));
      _require(owner, generation);
      if (token == null || token.isEmpty) {
        debugPrint(
          'Notification registration skipped: no device token available',
        );
        return;
      }
      await _register(owner, token, client, generation);
    });
  }

  Future<void> refresh(String token, {BackendApiClient? client}) {
    final owner = _desiredOwner;
    final ownerClient = client ?? _boundClient;
    final generation = _generation;
    if (owner == null || ownerClient == null || !isActive) {
      return Future.value();
    }
    return _serialize(() => _register(owner, token, ownerClient, generation));
  }

  Future<void> _register(
    String owner,
    String token,
    BackendApiClient client,
    int generation,
  ) async {
    _require(owner, generation);
    if (_boundToken == token &&
        _boundOwner == owner &&
        _registrationConfirmed) {
      _boundClient = client;
      return;
    }
    final previous = _boundToken;
    if (previous != null && _boundOwner == owner) {
      await client
          .withRequestGuard(() => _require(owner, generation))
          .unregisterFcmToken(userId: owner, token: previous);
    }
    // Track the attempted binding so a logout also cleans up a late HTTP ACK.
    _boundOwner = owner;
    _boundToken = token;
    _boundClient = client;
    _registrationConfirmed = false;
    await client
        .withRequestGuard(() => _require(owner, generation))
        .registerFcmToken(userId: owner, token: token);
    _require(owner, generation);
    _registrationConfirmed = true;
  }

  Future<void> endSession() {
    _desiredOwner = null;
    _generation++;
    return _serialize(_release);
  }

  Future<void> _release() async {
    final owner = _boundOwner;
    final token = _boundToken;
    final client = _boundClient;
    _boundOwner = null;
    _boundToken = null;
    _boundClient = null;
    _registrationConfirmed = false;
    try {
      if (owner != null && token != null && client != null) {
        await client.unregisterFcmToken(userId: owner, token: token);
      }
    } catch (error) {
      debugPrint(
        'Notification token deregistration failed; invalidating device token: $error',
      );
      rethrow;
    } finally {
      try {
        await deleteToken().timeout(const Duration(seconds: 10));
      } finally {
        await cancelReminders().timeout(const Duration(seconds: 10));
      }
    }
  }
}
