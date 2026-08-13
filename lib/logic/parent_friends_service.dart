import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/parent_coin_service.dart';

class ParentFriend {
  final String code;
  final String name;
  final DateTime addedAt;

  const ParentFriend({
    required this.code,
    required this.name,
    required this.addedAt,
  });

  factory ParentFriend.fromJson(Map<String, dynamic> j) => ParentFriend(
        code: (j['code'] as String? ?? '').toLowerCase(),
        name: j['name'] as String? ?? 'Familie',
        addedAt:
            DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'addedAt': addedAt.toIso8601String(),
      };
}

class ParentFriendsService extends ChangeNotifier {
  static final ParentFriendsService instance = ParentFriendsService._();
  ParentFriendsService._();

  static const _prefsKey = 'friends.v1';
  bool _loaded = false;
  List<ParentFriend> _friends = [];

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
  }

  Future<void> addFriend(ParentFriend friend) async {
    if (_friends.any((f) => f.code == friend.code)) return;
    _friends.add(friend);
    await _persist();
    notifyListeners();
  }

  Future<void> removeFriend(String code) async {
    _friends.removeWhere((f) => f.code == code);
    await _persist();
    notifyListeners();
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
