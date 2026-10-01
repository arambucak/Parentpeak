/// FriendChatService — Chat-Übersicht, Gelesen-Status und Gruppenchat.
///
/// Ergänzt das bestehende 1:1-Chat-System (match_conversation_screen nutzt
/// weiterhin /friend-chat/messages direkt). Dieser Service liefert:
///   - Die Messenger-Übersicht (alle Unterhaltungen mit letzter Nachricht +
///     Ungelesen-Zähler) für den Chats-Tab.
///   - Gelesen-Status (markRead), damit Ungelesen-Badges ehrlich sind.
///   - Gruppenchat-API (erstellen, laden, Mitglieder) — Stufe 2.
///
/// Alles läuft über den Backend-Proxy (BackendApiClient). Fehler sind
/// fehlertolerant: leere Liste / false statt Crash.

import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Eine Zeile in der Chat-Übersicht (1:1 oder Gruppe).
class ConversationSummary {
  const ConversationSummary({
    required this.roomId,
    required this.isGroup,
    required this.name,
    required this.photoUrl,
    required this.lastMessage,
    required this.lastAuthorName,
    required this.lastAuthorUserId,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String roomId;
  final bool isGroup;

  /// Gruppenname (nur bei Gruppen gesetzt). Bei 1:1 null → UI nutzt Freundesname.
  final String? name;
  final String photoUrl;
  final String lastMessage;
  final String lastAuthorName;
  final String lastAuthorUserId;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    return ConversationSummary(
      roomId: (j['roomId'] ?? '').toString(),
      isGroup: j['isGroup'] == true,
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? (j['name'] as String).trim()
          : null,
      photoUrl: (j['photoUrl'] ?? '').toString(),
      lastMessage: (j['lastMessage'] ?? '').toString(),
      lastAuthorName: (j['lastAuthorName'] ?? '').toString(),
      lastAuthorUserId: (j['lastAuthorUserId'] ?? '').toString(),
      lastMessageAt:
          DateTime.tryParse(j['lastMessageAt']?.toString() ?? '')?.toLocal(),
      unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Eine Chat-Gruppe (z.B. "Kita-Gruppe Sonnenschein").
class ChatGroupInfo {
  const ChatGroupInfo({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.photoUrl,
    required this.roomId,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final String photoUrl;
  final String roomId;

  factory ChatGroupInfo.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString();
    return ChatGroupInfo(
      id: id,
      name: (j['name'] ?? '').toString(),
      ownerUserId: (j['ownerUserId'] ?? '').toString(),
      photoUrl: (j['photoUrl'] ?? '').toString(),
      roomId: (j['roomId'] ?? 'group_$id').toString(),
    );
  }
}

/// Ein Mitglied einer Chat-Gruppe.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.memberName,
    required this.role,
  });

  final String userId;
  final String memberName;
  final String role; // 'owner' | 'member'

  bool get isOwner => role == 'owner';

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: (j['userId'] ?? '').toString(),
        memberName: (j['memberName'] as String?)?.trim().isNotEmpty == true
            ? (j['memberName'] as String).trim()
            : 'Elternteil',
        role: (j['role'] ?? 'member').toString(),
      );
}

class FriendChatService {
  FriendChatService._();
  static final FriendChatService instance = FriendChatService._();

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  /// Alle Unterhaltungen des Nutzers (für die Messenger-Liste).
  Future<List<ConversationSummary>> fetchOverview(String userId) async {
    final api = _api;
    if (api == null || userId.isEmpty) return const [];
    try {
      final res = await api.getJson('/friend-chat/overview?userId=$userId');
      if (res is Map<String, dynamic> && res['conversations'] is List) {
        return (res['conversations'] as List)
            .whereType<Map<String, dynamic>>()
            .map(ConversationSummary.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('FriendChatService.fetchOverview failed: $e');
    }
    return const [];
  }

  /// "Für mich löschen": blendet den bisherigen Verlauf nur für diesen Nutzer
  /// aus. Der Verlauf der anderen Seite bleibt erhalten.
  Future<bool> clearForMe(String roomId, String userId) async {
    final api = _api;
    if (api == null || roomId.isEmpty || userId.isEmpty) return false;
    try {
      await api.postJsonAny('/friend-chat/clear-for-me', {
        'roomId': roomId,
        'userId': userId,
      });
      return true;
    } catch (e) {
      debugPrint('FriendChatService.clearForMe failed: $e');
      return false;
    }
  }

  /// "Für alle löschen": entfernt den Verlauf physisch für alle Teilnehmer.
  /// Nur ein Teilnehmer/Gruppenmitglied darf das auslösen (Server prüft).
  Future<bool> deleteForAll(String roomId, String userId) async {
    final api = _api;
    if (api == null || roomId.isEmpty || userId.isEmpty) return false;
    try {
      await api.postJsonAny('/friend-chat/delete-for-all', {
        'roomId': roomId,
        'userId': userId,
      });
      return true;
    } catch (e) {
      debugPrint('FriendChatService.deleteForAll failed: $e');
      return false;
    }
  }

  /// Markiert einen Raum für den Nutzer als gelesen (Ungelesen → 0).
  Future<void> markRead(String roomId, String userId) async {
    final api = _api;
    if (api == null || roomId.isEmpty || userId.isEmpty) return;
    try {
      await api.postJsonAny('/friend-chat/read', {
        'roomId': roomId,
        'userId': userId,
      });
    } catch (e) {
      debugPrint('FriendChatService.markRead failed: $e');
    }
  }

  /// Erstellt eine neue Gruppe. Gibt die Gruppe inkl. roomId zurück.
  Future<ChatGroupInfo?> createGroup({
    required String name,
    required String ownerUserId,
    required String ownerName,
    List<String> memberUids = const [],
    Map<String, String> memberNames = const {},
    String photoUrl = '',
  }) async {
    final api = _api;
    if (api == null || name.isEmpty || ownerUserId.isEmpty) return null;
    try {
      final res = await api.postJsonAny('/chat-groups', {
        'name': name,
        'ownerUserId': ownerUserId,
        'ownerName': ownerName,
        'photoUrl': photoUrl,
        'memberUids': memberUids,
        'memberNames': memberNames,
      });
      if (res is Map<String, dynamic> && res['group'] is Map) {
        return ChatGroupInfo.fromJson(
            Map<String, dynamic>.from(res['group'] as Map));
      }
    } catch (e) {
      debugPrint('FriendChatService.createGroup failed: $e');
    }
    return null;
  }

  /// Alle Gruppen des Nutzers.
  Future<List<ChatGroupInfo>> fetchGroups(String userId) async {
    final api = _api;
    if (api == null || userId.isEmpty) return const [];
    try {
      final res = await api.getJson('/chat-groups?userId=$userId');
      if (res is Map<String, dynamic> && res['groups'] is List) {
        return (res['groups'] as List)
            .whereType<Map<String, dynamic>>()
            .map(ChatGroupInfo.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('FriendChatService.fetchGroups failed: $e');
    }
    return const [];
  }

  /// Lädt ein Gruppen-Foto hoch (Web-kompatibel via Bytes) und gibt die
  /// öffentliche URL zurück, oder null bei Fehler.
  Future<String?> uploadGroupPhoto(
    List<int> bytes, {
    String filename = 'group.jpg',
  }) async {
    final api = _api;
    if (api == null || bytes.isEmpty) return null;
    try {
      final res = await api.uploadImageBytes('/uploads/image', bytes,
          filename: filename);
      final url = res['url']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (e) {
      debugPrint('FriendChatService.uploadGroupPhoto failed: $e');
      return null;
    }
  }

  /// Mitglieder einer Gruppe laden.
  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final api = _api;
    if (api == null || groupId.isEmpty) return const [];
    try {
      final res = await api.getJson('/chat-groups/$groupId/members');
      if (res is Map<String, dynamic> && res['members'] is List) {
        return (res['members'] as List)
            .whereType<Map<String, dynamic>>()
            .map(GroupMember.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('FriendChatService.fetchMembers failed: $e');
    }
    return const [];
  }

  /// Weitere Mitglieder zu einer Gruppe hinzufügen.
  Future<bool> addMembers({
    required String groupId,
    required String actingUserId,
    required List<String> memberUids,
    Map<String, String> memberNames = const {},
  }) async {
    final api = _api;
    if (api == null || groupId.isEmpty || actingUserId.isEmpty) return false;
    try {
      await api.postJsonAny('/chat-groups/$groupId/members', {
        'actingUserId': actingUserId,
        'memberUids': memberUids,
        'memberNames': memberNames,
      });
      return true;
    } catch (e) {
      debugPrint('FriendChatService.addMembers failed: $e');
      return false;
    }
  }

  /// Gruppe verlassen.
  Future<bool> leaveGroup(String groupId, String userId) async {
    final api = _api;
    if (api == null || groupId.isEmpty || userId.isEmpty) return false;
    try {
      await api.delete('/chat-groups/$groupId/members/$userId');
      return true;
    } catch (e) {
      debugPrint('FriendChatService.leaveGroup failed: $e');
      return false;
    }
  }
}
