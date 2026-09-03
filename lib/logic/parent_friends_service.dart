import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/parent_coin_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

class ParentFriend {
  final String code;
  final String name;
  final DateTime addedAt;

  /// Vom Server gelieferte, geteilte Chat-Raum-ID. Optional/abwaertskompatibel:
  /// wenn null, wird sie deterministisch aus beiden Codes berechnet.
  final String? roomId;

  const ParentFriend({
    required this.code,
    required this.name,
    required this.addedAt,
    this.roomId,
  });

  factory ParentFriend.fromJson(Map<String, dynamic> j) => ParentFriend(
        code: (j['code'] as String? ?? '').toLowerCase(),
        name: j['name'] as String? ?? 'Familie',
        addedAt:
            DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
        roomId: (j['roomId'] as String?)?.isNotEmpty == true
            ? j['roomId'] as String
            : null,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'addedAt': addedAt.toIso8601String(),
        if (roomId != null) 'roomId': roomId,
      };
}

class ParentFriendsService extends ChangeNotifier {
  static final ParentFriendsService instance = ParentFriendsService._();
  ParentFriendsService._();

  static const _prefsKey = 'friends.v1';
  bool _loaded = false;
  List<ParentFriend> _friends = [];

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  List<ParentFriend> get friends => List.unmodifiable(_friends);

  // My 6-char code derived from Firebase UID via ParentCoinService
  String get myCode => ParentCoinService.instance.referralCode.toLowerCase();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _friends = list
            .map((e) => ParentFriend.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _friends = [];
      }
    }
    notifyListeners();
    // Prio 2: restore the durable friend list from the server so friends
    // survive a reinstall. Runs in the background; local list shows instantly.
    unawaited(_syncFromServer());
  }

  /// Merge the server-persisted friend list into the local list.
  Future<void> _syncFromServer() async {
    final api = _api;
    if (api == null) return;
    final code = myCode;
    if (code.isEmpty) return;
    try {
      final data = await api.getJson('/api/friends/list/$code');
      if (data is Map<String, dynamic> && data['friends'] is List) {
        var changed = false;
        for (final raw in (data['friends'] as List)) {
          if (raw is! Map) continue;
          final fc = (raw['friendCode'] as String? ?? '').toLowerCase();
          final fn = raw['friendName'] as String? ?? 'Familie';
          if (fc.isEmpty || fc == code) continue;
          if (!_friends.any((f) => f.code == fc)) {
            _friends
                .add(ParentFriend(code: fc, name: fn, addedAt: DateTime.now()));
            changed = true;
          }
        }
        if (changed) {
          await _persist();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('ParentFriendsService._syncFromServer failed: $e');
    }
  }

  Future<void> addFriend(ParentFriend friend) async {
    if (_friends.any((f) => f.code == friend.code)) return;
    _friends.add(friend);
    await _persist();
    notifyListeners();
    unawaited(_pushEdge(friend.code, friend.name));
  }

  /// Atomare beidseitige Verbindung ueber das Backend. Beide Familien sind
  /// sofort befreundet, echter Name + geteilte roomId kommen vom Server.
  /// Gibt true zurueck, wenn der Server bestaetigt hat.
  Future<bool> connectMutual({
    required String friendCode,
    required String myName,
    required String myUserId,
  }) async {
    final api = _api;
    final code = myCode;
    final normalizedFriend = friendCode.trim().toLowerCase();
    if (normalizedFriend.isEmpty || normalizedFriend == code) return false;

    String? serverName;
    String? serverRoomId;
    if (api != null && code.isNotEmpty) {
      try {
        final data = await api.postJsonAny('/api/friends/connect-mutual', {
          'myCode': code,
          'myName': myName,
          'myUserId': myUserId,
          'friendCode': normalizedFriend,
        });
        if (data is Map<String, dynamic>) {
          serverName = (data['friendName'] as String?)?.trim();
          serverRoomId = (data['roomId'] as String?)?.trim();
        }
      } catch (e) {
        debugPrint('ParentFriendsService.connectMutual failed: $e');
      }
    }

    final friend = ParentFriend(
      code: normalizedFriend,
      name: (serverName != null && serverName.isNotEmpty)
          ? serverName
          : 'Familie',
      addedAt: DateTime.now(),
      roomId: serverRoomId,
    );
    // Vorhandenen Eintrag ersetzen (Name/roomId aktualisieren) oder neu anlegen.
    _friends.removeWhere((f) => f.code == normalizedFriend);
    _friends.add(friend);
    await _persist();
    notifyListeners();
    return serverRoomId != null;
  }

  Future<void> removeFriend(String code) async {
    _friends.removeWhere((f) => f.code == code);
    await _persist();
    notifyListeners();
    unawaited(_removeEdge(code));
  }

  /// Persist a friend edge on the server (my side of the relationship).
  Future<void> _pushEdge(String friendCode, String friendName) async {
    final api = _api;
    if (api == null) return;
    final code = myCode;
    if (code.isEmpty || friendCode.isEmpty) return;
    try {
      await api.postJsonAny('/api/friends/edge', {
        'ownerCode': code,
        'friendCode': friendCode.toLowerCase(),
        'friendName': friendName,
      });
    } catch (e) {
      debugPrint('ParentFriendsService._pushEdge failed: $e');
    }
  }

  Future<void> _removeEdge(String friendCode) async {
    final api = _api;
    if (api == null) return;
    final code = myCode;
    if (code.isEmpty || friendCode.isEmpty) return;
    try {
      await api.delete(
          '/api/friends/edge?ownerCode=$code&friendCode=${friendCode.toLowerCase()}');
    } catch (e) {
      debugPrint('ParentFriendsService._removeEdge failed: $e');
    }
  }

  // True if userId starts with a known friend's 6-char code
  bool isFriendByUserId(String userId) {
    final id = userId.toLowerCase();
    return _friends.any((f) => f.code.isNotEmpty && id.startsWith(f.code));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_friends.map((f) => f.toJson()).toList()),
    );
  }
}
