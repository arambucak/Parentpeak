import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Ein Freund/eine offene Anfrage — UID-basiert (die stabile Identitaet).
class Friend {
  final String uid;
  final String name;
  final String roomId;
  const Friend({required this.uid, required this.name, required this.roomId});

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        uid: j['uid'] as String? ?? '',
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? (j['name'] as String).trim()
            : 'Familie',
        roomId: j['roomId'] as String? ?? '',
      );
}

class FriendshipData {
  final List<Friend> friends;
  final List<Friend> incoming; // Anfragen an mich
  final List<Friend> outgoing; // von mir gesendete Anfragen
  const FriendshipData({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
  });
}

/// UID-basiertes Freundschafts-System (ersetzt das alte Code-System als
/// Rueckgrat). Anfrage/Annehmen wie bei Instagram; Verbinden per Einladungs-
/// Link/QR. Der PP-Code bleibt nur noch Deko.
class FriendshipService extends ChangeNotifier {
  FriendshipService._();
  static final FriendshipService instance = FriendshipService._();

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  FriendshipData _data = const FriendshipData();
  FriendshipData get data => _data;
  List<Friend> get friends => _data.friends;
  List<Friend> get incoming => _data.incoming;
  List<Friend> get outgoing => _data.outgoing;

  /// Freundesliste + Anfragen vom Server laden.
  Future<void> load() async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return;
    try {
      final res = await api.getJson('/api/friendships/$uid');
      if (res is Map<String, dynamic>) {
        List<Friend> parse(String key) => (res[key] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Friend.fromJson)
            .toList();
        _data = FriendshipData(
          friends: parse('friends'),
          incoming: parse('incoming'),
          outgoing: parse('outgoing'),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FriendshipService.load failed: $e');
    }
  }

  /// Einladungs-Token erzeugen (fuer Link/QR). Gibt den Link zurueck.
  Future<String?> createInviteLink() async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return null;
    try {
      final res = await api.postJsonAny('/api/friendships/invite', {
        'userId': uid,
      });
      if (res is Map<String, dynamic> && res['token'] is String) {
        return 'https://parentpeak.de/f/${res['token']}';
      }
    } catch (e) {
      debugPrint('FriendshipService.createInviteLink failed: $e');
    }
    return null;
  }

  /// Einladungs-Token aufloesen -> {uid, name} des Einladenden.
  Future<Map<String, String>?> resolveInvite(String token) async {
    final api = _api;
    if (api == null || token.isEmpty) return null;
    try {
      final res = await api.getJson('/api/friendships/resolve-invite/$token');
      if (res is Map<String, dynamic> && res['uid'] is String) {
        return {
          'uid': res['uid'] as String,
          'name': (res['name'] as String?)?.trim() ?? '',
        };
      }
    } catch (e) {
      debugPrint('FriendshipService.resolveInvite failed: $e');
    }
    return null;
  }

  /// Bruecke: einen (alten) Freundes-Code -> {uid, name} aufloesen, damit man
  /// auch per Code eine UID-Freundschaftsanfrage senden kann.
  Future<Map<String, String>?> resolveCode(String code) async {
    final api = _api;
    if (api == null || code.isEmpty) return null;
    try {
      final res = await api.getJson('/api/friends/lookup/$code');
      if (res is Map<String, dynamic> &&
          res['uid'] is String &&
          (res['uid'] as String).isNotEmpty) {
        return {
          'uid': res['uid'] as String,
          'name': (res['name'] as String?)?.trim() ?? '',
        };
      }
    } catch (e) {
      debugPrint('FriendshipService.resolveCode failed: $e');
    }
    return null;
  }

  /// Freundschaftsanfrage an eine UID senden. Ist das Ziel nicht privat, wird
  /// die Freundschaft sofort bestaetigt (Server entscheidet).
  Future<bool> sendRequest(String toUid) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty || toUid.isEmpty)
      return false;
    if (uid == toUid) return false;
    try {
      await api.postJsonAny('/api/friendships/request', {
        'fromUid': uid,
        'toUid': toUid,
      });
      await load();
      return true;
    } catch (e) {
      debugPrint('FriendshipService.sendRequest failed: $e');
      return false;
    }
  }

  /// Eingehende Anfrage annehmen.
  Future<bool> accept(String otherUid) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty || otherUid.isEmpty)
      return false;
    try {
      await api.postJsonAny('/api/friendships/accept', {
        'uid': uid,
        'otherUid': otherUid,
      });
      await load();
      return true;
    } catch (e) {
      debugPrint('FriendshipService.accept failed: $e');
      return false;
    }
  }

  /// Freundschaft entfernen oder Anfrage ablehnen.
  Future<bool> remove(String otherUid) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty || otherUid.isEmpty)
      return false;
    try {
      await api.delete('/api/friendships?uid=$uid&otherUid=$otherUid');
      await load();
      return true;
    } catch (e) {
      debugPrint('FriendshipService.remove failed: $e');
      return false;
    }
  }
}
