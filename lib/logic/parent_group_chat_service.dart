import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

class ParentChatGroup {
  const ParentChatGroup({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final int memberCount;

  factory ParentChatGroup.fromJson(Map<String, dynamic> json) {
    return ParentChatGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Elterngruppe',
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      memberCount: int.tryParse(json['memberCount']?.toString() ?? '') ?? 0,
    );
  }
}

class ParentGroupMessage {
  const ParentGroupMessage({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String authorUserId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  factory ParentGroupMessage.fromJson(Map<String, dynamic> json) {
    return ParentGroupMessage(
      id: json['id']?.toString() ?? '',
      authorUserId: json['authorUserId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Elternteil',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ParentGroupChatService {
  ParentGroupChatService({BackendApiClient? api})
      : _api = api ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _api;

  String? get _userId => AuthService.instance.currentUser?.uid;
  String get _userName =>
      AuthService.instance.currentUser?.friendlyName ?? 'Elternteil';

  Future<List<ParentChatGroup>> loadGroups() async {
    final api = _api;
    final userId = _userId;
    if (api == null || userId == null || userId.isEmpty) return [];
    try {
      final payload = await api.getJson('/api/chat/groups?userId=$userId');
      final raw = payload is Map ? payload['groups'] : null;
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((item) => ParentChatGroup.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ParentChatGroup?> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final api = _api;
    final userId = _userId;
    if (api == null || userId == null || userId.isEmpty) return null;
    try {
      final payload = await api.postJsonAny('/api/chat/groups', {
        'userId': userId,
        'name': name.trim(),
        'memberIds': memberIds,
      });
      final group = payload is Map ? payload['group'] : null;
      return group is Map
          ? ParentChatGroup.fromJson(Map<String, dynamic>.from(group))
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<ParentGroupMessage>> loadMessages(String groupId) async {
    final api = _api;
    final userId = _userId;
    if (api == null || userId == null || userId.isEmpty) return [];
    try {
      final payload = await api.getJson(
        '/api/chat/groups/$groupId/messages?userId=$userId',
      );
      final raw = payload is Map ? payload['messages'] : null;
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((item) => ParentGroupMessage.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ParentGroupMessage?> sendMessage({
    required String groupId,
    required String content,
  }) async {
    final api = _api;
    final userId = _userId;
    if (api == null || userId == null || userId.isEmpty) return null;
    try {
      final payload =
          await api.postJsonAny('/api/chat/groups/$groupId/messages', {
        'userId': userId,
        'userName': _userName,
        'content': content.trim(),
      });
      final item = payload is Map ? payload['item'] : null;
      return item is Map
          ? ParentGroupMessage.fromJson(Map<String, dynamic>.from(item))
          : null;
    } catch (_) {
      return null;
    }
  }
}
