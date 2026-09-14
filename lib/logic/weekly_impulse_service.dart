import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/language_service.dart';
import 'package:parentpeak/models_and_widgets/weekly_impulse_feature.dart';

import 'backend_api_client.dart';

class WeeklyImpulseModerationReport {
  final String id;
  final String postId;
  final String postTitle;
  final String postAuthorName;
  final String postRole;
  final String reason;
  final String reporterName;
  final String reporterUserId;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String resolvedBy;
  final String moderatorNote;
  final String lastAction;
  final DateTime? lastActionAt;
  final bool hiddenByModeration;
  final DateTime? hiddenAt;
  final String hiddenBy;

  const WeeklyImpulseModerationReport({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.postAuthorName,
    required this.postRole,
    required this.reason,
    required this.reporterName,
    required this.reporterUserId,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy = '',
    this.moderatorNote = '',
    this.lastAction = '',
    this.lastActionAt,
    this.hiddenByModeration = false,
    this.hiddenAt,
    this.hiddenBy = '',
  });

  bool get isResolved => resolvedAt != null;

  factory WeeklyImpulseModerationReport.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseModerationReport(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      postTitle: json['postTitle'] as String? ?? '',
      postAuthorName: json['postAuthorName'] as String? ?? '',
      postRole: json['postRole'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      reporterName: json['reporterName'] as String? ?? '',
      reporterUserId: json['reporterUserId'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      resolvedAt: DateTime.tryParse(json['resolvedAt'] as String? ?? ''),
      resolvedBy: json['resolvedBy'] as String? ?? '',
        moderatorNote: json['moderatorNote'] as String? ?? '',
        lastAction: json['lastAction'] as String? ?? '',
        lastActionAt: DateTime.tryParse(json['lastActionAt'] as String? ?? ''),
      hiddenByModeration: json['hiddenByModeration'] as bool? ?? false,
      hiddenAt: DateTime.tryParse(json['hiddenAt'] as String? ?? ''),
      hiddenBy: json['hiddenBy'] as String? ?? '',
    );
  }
}

class WeeklyImpulseVerificationStatus {
  final bool verified;
  final bool pendingRequest;
  final String verificationLabel;
  final DateTime? verifiedAt;
  final WeeklyImpulseVerifiedProfile? verifiedProfile;
  final WeeklyImpulseVerificationRequest? latestRequest;

  const WeeklyImpulseVerificationStatus({
    required this.verified,
    required this.pendingRequest,
    required this.verificationLabel,
    this.verifiedAt,
    this.verifiedProfile,
    this.latestRequest,
  });

  factory WeeklyImpulseVerificationStatus.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseVerificationStatus(
      verified: json['verified'] as bool? ?? false,
      pendingRequest: json['pendingRequest'] as bool? ?? false,
      verificationLabel: json['verificationLabel'] as String? ?? '',
      verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
      verifiedProfile: json['verifiedProfile'] is Map<String, dynamic>
          ? WeeklyImpulseVerifiedProfile.fromJson(
              json['verifiedProfile'] as Map<String, dynamic>,
            )
          : null,
      latestRequest: json['latestRequest'] is Map<String, dynamic>
          ? WeeklyImpulseVerificationRequest.fromJson(
              json['latestRequest'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class WeeklyImpulseVerifiedProfile {
  final String displayName;
  final String roleTitle;
  final String organization;
  final String verificationLabel;
  final DateTime? verifiedAt;
  final String reviewedBy;
  final String reviewNote;

  const WeeklyImpulseVerifiedProfile({
    required this.displayName,
    required this.roleTitle,
    required this.organization,
    required this.verificationLabel,
    this.verifiedAt,
    this.reviewedBy = '',
    this.reviewNote = '',
  });

  factory WeeklyImpulseVerifiedProfile.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseVerifiedProfile(
      displayName: json['displayName'] as String? ?? '',
      roleTitle: json['roleTitle'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      verificationLabel: json['verificationLabel'] as String? ?? '',
      verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
      reviewedBy: json['reviewedBy'] as String? ?? '',
      reviewNote: json['reviewNote'] as String? ?? '',
    );
  }
}

class WeeklyImpulseVerificationRequest {
  final String id;
  final String userId;
  final String email;
  final String displayName;
  final String roleTitle;
  final String organization;
  final String note;
  final String status;
  final String verificationLabel;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String reviewedBy;
  final String reviewNote;

  const WeeklyImpulseVerificationRequest({
    required this.id,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.roleTitle,
    required this.organization,
    required this.note,
    required this.status,
    required this.verificationLabel,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy = '',
    this.reviewNote = '',
  });

  bool get isPending => status == 'pending';

  factory WeeklyImpulseVerificationRequest.fromJson(Map<String, dynamic> json) {
    return WeeklyImpulseVerificationRequest(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      roleTitle: json['roleTitle'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? '',
      verificationLabel: json['verificationLabel'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
      reviewedBy: json['reviewedBy'] as String? ?? '',
      reviewNote: json['reviewNote'] as String? ?? '',
    );
  }
}

class WeeklyImpulseService {
  const WeeklyImpulseService({required this.apiClient});

  final BackendApiClient? apiClient;
  static const List<String> _requiredFields = [
    'id',
    'title',
    'content_body',
    'practical_tip',
    'category',
    'publish_date',
  ];
  String _cacheKey(String language) => 'pp_weekly_impulse_cache_${language}_v1';
  static const Duration _weeklyImpulseCacheMaxAge = Duration(days: 2);

  Future<WeeklyImpulse> fetchWeeklyImpulse({String? viewerUserId}) async {
    if (apiClient == null) {
      final cached = await _readCachedImpulse();
      if (cached != null) {
        return cached;
      }
      throw StateError('Weekly impulse backend unavailable');
    }

    final path = _weeklyImpulsePath(
      viewerUserId: viewerUserId,
      language: LanguageService.activeCode,
    );
    try {
      final decoded = await apiClient!.getJson(path);
      final impulse = _parseIfValid(_extractImpulsePayload(decoded));
      if (impulse != null) {
        await _cacheImpulse(impulse);
        return impulse;
      }
      final cached = await _readCachedImpulse();
      if (cached != null) {
        return cached;
      }
      throw StateError('Weekly impulse payload invalid');
    } catch (e) {
      debugPrint('WeeklyImpulse backend request failed: $e');
      final cached = await _readCachedImpulse();
      if (cached != null) {
        return cached;
      }
      throw StateError('Weekly impulse unavailable: backend request failed');
    }
  }

  Future<void> _cacheImpulse(WeeklyImpulse impulse) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'id': impulse.id,
        'title': impulse.title,
        'content_body': impulse.contentBody,
        'practical_tip': impulse.practicalTip,
        'audio_script': impulse.audioScript,
        'category': impulse.category.name,
        'publish_date': impulse.publishDate.toIso8601String(),
        'hero_headline': impulse.heroHeadline,
        'hero_description': impulse.heroDescription,
        'companion_impulses': impulse.companionImpulses
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'title': item.title,
                'summary': item.summary,
                'duration_label': item.durationLabel,
                'format_label': item.formatLabel,
              },
            )
            .toList(),
        'discussion_prompt': impulse.discussionPrompt == null
            ? null
            : <String, dynamic>{
                'id': impulse.discussionPrompt!.id,
                'title': impulse.discussionPrompt!.title,
                'body': impulse.discussionPrompt!.body,
              },
      };
      await prefs.setString(_cacheKey(LanguageService.activeCode), jsonEncode(payload));
    } catch (e) {
      debugPrint('WeeklyImpulse cache write skipped: $e');
    }
  }

  Future<WeeklyImpulse?> _readCachedImpulse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(LanguageService.activeCode);
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (!_isCachedPayloadFresh(decoded)) {
        await prefs.remove(key);
        debugPrint('WeeklyImpulse cache expired and was cleared');
        return null;
      }
      return _parseIfValid(_extractImpulsePayload(decoded));
    } catch (e) {
      debugPrint('WeeklyImpulse cache read skipped: $e');
      return null;
    }
  }

  bool _isCachedPayloadFresh(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    final cachedAtRaw = decoded['cached_at'];
    if (cachedAtRaw is String && cachedAtRaw.trim().isNotEmpty) {
      final cachedAt = DateTime.tryParse(cachedAtRaw)?.toUtc();
      if (cachedAt != null) {
        final cacheAge = DateTime.now().toUtc().difference(cachedAt);
        return cacheAge <= _weeklyImpulseCacheMaxAge;
      }
    }

    final payload = _extractImpulsePayload(decoded);
    if (payload is Map<String, dynamic>) {
      final publishDateRaw = payload['publish_date'];
      if (publishDateRaw is String && publishDateRaw.trim().isNotEmpty) {
        final publishDate = DateTime.tryParse(publishDateRaw)?.toUtc();
        if (publishDate != null) {
          final contentAge = DateTime.now().toUtc().difference(publishDate);
          return contentAge <= _weeklyImpulseCacheMaxAge;
        }
      }
    }

    return false;
  }

  Future<void> createCommunityPost({
    required String impulseId,
    required String title,
    required String body,
    required String authorName,
    required String authorUserId,
    required String authorEmail,
    required String role,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/posts',
      <String, dynamic>{
        'impulseId': impulseId,
        'title': title,
        'body': body,
        'authorName': authorName,
        'authorUserId': authorUserId,
        'authorEmail': authorEmail,
        'role': role,
      },
    );
  }

  Future<void> setCommunityLike({
    required String impulseId,
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/posts/$postId/like',
      <String, dynamic>{
        'impulseId': impulseId,
        'userId': userId,
        'isLiked': isLiked,
      },
    );
  }

  Future<void> addCommunityComment({
    required String impulseId,
    required String postId,
    required String authorName,
    required String role,
    required String comment,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/posts/$postId/comments',
      <String, dynamic>{
        'impulseId': impulseId,
        'authorName': authorName,
        'role': role,
        'comment': comment,
      },
    );
  }

  Future<void> reportCommunityPost({
    required String impulseId,
    required String postId,
    required String reporterUserId,
    required String reporterName,
    required String reason,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/posts/$postId/report',
      <String, dynamic>{
        'impulseId': impulseId,
        'reporterUserId': reporterUserId,
        'reporterName': reporterName,
        'reason': reason,
      },
    );
  }

  Future<WeeklyImpulseVerificationStatus> fetchVerificationStatus({
    required String userId,
    required String email,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    final path =
        '${APIConfig.getBackendWeeklyImpulsePath()}/community/verification-status?userId=${Uri.encodeQueryComponent(userId)}&email=${Uri.encodeQueryComponent(email)}';
    final decoded = await client.getJson(path);
    if (decoded is! Map<String, dynamic>) {
      return const WeeklyImpulseVerificationStatus(
        verified: false,
        pendingRequest: false,
        verificationLabel: '',
      );
    }
    return WeeklyImpulseVerificationStatus.fromJson(decoded);
  }

  Future<void> createVerificationRequest({
    required String userId,
    required String email,
    required String displayName,
    required String roleTitle,
    required String organization,
    required String note,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/verification-requests',
      <String, dynamic>{
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'roleTitle': roleTitle,
        'organization': organization,
        'note': note,
      },
    );
  }

  Future<List<WeeklyImpulseVerificationRequest>> fetchVerificationRequests({
    String status = '',
    required String reviewerEmail,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    final statusQuery = status.trim().isEmpty
        ? ''
        : 'status=${Uri.encodeQueryComponent(status.trim().toLowerCase())}&';
    final decoded = await client.getJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/verification-requests?${statusQuery}reviewerEmail=${Uri.encodeQueryComponent(reviewerEmail)}',
    );
    if (decoded is! Map<String, dynamic>) {
      return const <WeeklyImpulseVerificationRequest>[];
    }

    final rawItems = decoded['items'];
    if (rawItems is! List<dynamic>) {
      return const <WeeklyImpulseVerificationRequest>[];
    }

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(WeeklyImpulseVerificationRequest.fromJson)
        .toList();
  }

  Future<void> approveVerificationRequest({
    required String requestId,
    required String reviewerName,
    required String reviewerEmail,
    required String reviewNote,
    required String verificationLabel,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/verification-requests/$requestId/approve',
      <String, dynamic>{
        'reviewerName': reviewerName,
        'reviewerEmail': reviewerEmail,
        'reviewNote': reviewNote,
        'verificationLabel': verificationLabel,
      },
    );
  }

  Future<List<WeeklyImpulseModerationReport>> fetchModerationReports({
    required String impulseId,
    required String moderatorEmail,
    bool includeResolved = false,
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    final separator = APIConfig.getBackendWeeklyImpulsePath().contains('?')
        ? '&'
        : '?';
    final path =
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/reports${separator}impulseId=${Uri.encodeQueryComponent(impulseId)}&includeResolved=${includeResolved ? '1' : '0'}&moderatorEmail=${Uri.encodeQueryComponent(moderatorEmail)}';
    final decoded = await client.getJson(path);
    if (decoded is! Map<String, dynamic>) {
      return const <WeeklyImpulseModerationReport>[];
    }

    final rawItems = decoded['items'];
    if (rawItems is! List<dynamic>) {
      return const <WeeklyImpulseModerationReport>[];
    }

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(WeeklyImpulseModerationReport.fromJson)
        .toList();
  }

  Future<void> resolveModerationReport({
    required String impulseId,
    required String reportId,
    required String moderatorName,
    required String moderatorEmail,
    String moderatorNote = '',
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/reports/$reportId/resolve',
      <String, dynamic>{
        'impulseId': impulseId,
        'moderatorName': moderatorName,
        'moderatorEmail': moderatorEmail,
        'moderatorNote': moderatorNote,
      },
    );
  }

  Future<void> setCommunityPostHidden({
    required String impulseId,
    required String postId,
    required String moderatorName,
    required String moderatorEmail,
    required bool hidden,
    String moderatorNote = '',
    String reportId = '',
  }) async {
    final client = apiClient;
    if (client == null) {
      throw StateError('Weekly impulse backend unavailable');
    }

    await client.postJson(
      '${APIConfig.getBackendWeeklyImpulsePath()}/community/posts/$postId/moderation-visibility',
      <String, dynamic>{
        'impulseId': impulseId,
        'moderatorName': moderatorName,
        'moderatorEmail': moderatorEmail,
        'hidden': hidden,
        'moderatorNote': moderatorNote,
        'reportId': reportId,
      },
    );
  }

  WeeklyImpulse? _parseIfValid(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    for (final field in _requiredFields) {
      final value = decoded[field];
      if (value is! String || value.trim().isEmpty) {
        return null;
      }
    }

    try {
      return WeeklyImpulse.fromJson(decoded);
    } catch (e) {
      debugPrint('WeeklyImpulse parse invalid payload: $e');
      return null;
    }
  }

  dynamic _extractImpulsePayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return decoded;
    }

    final item = decoded['item'];
    if (item is Map<String, dynamic>) {
      return item;
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return decoded;
  }

  String _weeklyImpulsePath({
    String? viewerUserId,
    required String language,
  }) {
    final basePath = APIConfig.getBackendWeeklyImpulsePath();
    final separator = basePath.contains('?') ? '&' : '?';
    final query = <String>[
      'language=${Uri.encodeQueryComponent(language)}',
      if (viewerUserId != null && viewerUserId.trim().isNotEmpty)
        'viewerUserId=${Uri.encodeQueryComponent(viewerUserId.trim())}',
    ];
    return '$basePath$separator${query.join('&')}';
  }

}
