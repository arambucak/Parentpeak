import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Manages blocked users and content reports across the entire app.
/// Used in: Chat, Verschenkmarkt, Events, Netzwerk.
class BlockReportService {
  static final BlockReportService instance = BlockReportService._();
  BlockReportService._();

  static const String _blockedKey = 'safety.blocked_users';
  static const String _reportsKey = 'safety.reports';

  List<BlockedUser> _blockedUsers = [];
  List<ContentReport> _reports = [];

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  List<BlockedUser> get blockedUsers => List.unmodifiable(_blockedUsers);

  /// Current signed-in user id, used as the server-side owner of blocks/reports.
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  /// Initialize — load from SharedPreferences, then merge server-side blocks.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedRaw = prefs.getString(_blockedKey);
    if (blockedRaw != null && blockedRaw.isNotEmpty) {
      try {
        _blockedUsers = (jsonDecode(blockedRaw) as List)
            .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final reportsRaw = prefs.getString(_reportsKey);
    if (reportsRaw != null && reportsRaw.isNotEmpty) {
      try {
        _reports = (jsonDecode(reportsRaw) as List)
            .map((e) => ContentReport.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    // Prio 4: merge server-side blocks so they apply on every device.
    unawaited(_syncBlocksFromServer());
  }

  /// Merge server-persisted blocks into the local list.
  Future<void> _syncBlocksFromServer() async {
    final api = _api;
    if (api == null) return;
    final uid = _currentUserId;
    if (uid == 'anonymous') return;
    try {
      final data = await api.getJson('/api/safety/blocks/$uid');
      if (data is Map<String, dynamic> && data['blocks'] is List) {
        var changed = false;
        for (final raw in (data['blocks'] as List)) {
          if (raw is! Map) continue;
          final id = raw['blockedUserId'] as String? ?? '';
          if (id.isEmpty) continue;
          if (!isBlocked(id)) {
            _blockedUsers.add(BlockedUser(
              userId: id,
              displayName: raw['blockedName'] as String? ?? '',
              blockedAt:
                  DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
            ));
            changed = true;
          }
        }
        if (changed) await _save();
      }
    } catch (e) {
      debugPrint('BlockReportService._syncBlocksFromServer failed: $e');
    }
  }

  /// Check if a user is blocked
  bool isBlocked(String userId) {
    return _blockedUsers.any((u) => u.userId == userId);
  }

  /// Block a user (local + server so it applies everywhere).
  Future<void> blockUser(String userId, String displayName) async {
    if (isBlocked(userId)) return;
    _blockedUsers.add(BlockedUser(
      userId: userId,
      displayName: displayName,
      blockedAt: DateTime.now(),
    ));
    await _save();
    final api = _api;
    final uid = _currentUserId;
    if (api != null && uid != 'anonymous') {
      try {
        await api.postJsonAny('/api/safety/block', {
          'blockerUserId': uid,
          'blockedUserId': userId,
          'blockedName': displayName,
        });
      } catch (e) {
        debugPrint('BlockReportService.blockUser server sync failed: $e');
      }
    }
  }

  /// Unblock a user (local + server).
  Future<void> unblockUser(String userId) async {
    _blockedUsers.removeWhere((u) => u.userId == userId);
    await _save();
    final api = _api;
    final uid = _currentUserId;
    if (api != null && uid != 'anonymous') {
      try {
        await api.postJsonAny('/api/safety/unblock', {
          'blockerUserId': uid,
          'blockedUserId': userId,
        });
      } catch (e) {
        debugPrint('BlockReportService.unblockUser server sync failed: $e');
      }
    }
  }

  /// Report content (message, listing, event, profile)
  /// Returns a moderation result from the AI.
  Future<ReportResult> reportContent({
    required String reporterUserId,
    required String reportedUserId,
    required String contentType, // 'message', 'listing', 'event', 'profile'
    required String content,
    required String
        reason, // 'insult', 'spam', 'inappropriate', 'fraud', 'other'
  }) async {
    final report = ContentReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      reporterUserId: reporterUserId,
      reportedUserId: reportedUserId,
      contentType: contentType,
      content: content,
      reason: reason,
      createdAt: DateTime.now(),
    );
    _reports.add(report);
    await _save();

    // Prio 4: persist the report on the server for the moderation trail.
    final api = _api;
    if (api != null) {
      try {
        await api.postJsonAny('/api/safety/report', {
          'reporterUserId': reporterUserId,
          'reportedUserId': reportedUserId,
          'contentType': contentType,
          'content': content,
          'reason': reason,
        });
      } catch (e) {
        debugPrint('BlockReportService.reportContent server sync failed: $e');
      }
    }

    // AI auto-moderation check
    final moderationResult =
        ChatModerationService.instance.checkMessage(content);
    if (moderationResult != null) {
      // Content is clearly harmful → auto-action
      debugPrint('BlockReportService: Auto-moderated: $moderationResult');
      return ReportResult(
        action: ReportAction.autoRemoved,
        message:
            'Der Inhalt wurde automatisch entfernt. Danke für deine Meldung.',
      );
    }

    // Check if user has multiple reports
    final userReportCount =
        _reports.where((r) => r.reportedUserId == reportedUserId).length;
    if (userReportCount >= 3) {
      return ReportResult(
        action: ReportAction.userWarned,
        message:
            'Dieser Nutzer wurde bereits mehrfach gemeldet. Wir prüfen den Fall.',
      );
    }

    return ReportResult(
      action: ReportAction.reviewPending,
      message: 'Danke für deine Meldung. Wir prüfen den Inhalt.',
    );
  }

  /// Get report count for a user (for warning system)
  int getReportCount(String userId) {
    return _reports.where((r) => r.reportedUserId == userId).length;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _blockedKey, jsonEncode(_blockedUsers.map((u) => u.toJson()).toList()));
    // Keep max 100 reports
    if (_reports.length > 100)
      _reports = _reports.sublist(_reports.length - 100);
    await prefs.setString(
        _reportsKey, jsonEncode(_reports.map((r) => r.toJson()).toList()));
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class BlockedUser {
  final String userId;
  final String displayName;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'blockedAt': blockedAt.toIso8601String(),
      };

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '',
        blockedAt: DateTime.tryParse(j['blockedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ContentReport {
  final String id;
  final String reporterUserId;
  final String reportedUserId;
  final String contentType;
  final String content;
  final String reason;
  final DateTime createdAt;

  const ContentReport({
    required this.id,
    required this.reporterUserId,
    required this.reportedUserId,
    required this.contentType,
    required this.content,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterUserId': reporterUserId,
        'reportedUserId': reportedUserId,
        'contentType': contentType,
        'content': content,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ContentReport.fromJson(Map<String, dynamic> j) => ContentReport(
        id: j['id'] as String,
        reporterUserId: j['reporterUserId'] as String,
        reportedUserId: j['reportedUserId'] as String,
        contentType: j['contentType'] as String? ?? '',
        content: j['content'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

enum ReportAction { autoRemoved, userWarned, reviewPending }

class ReportResult {
  final ReportAction action;
  final String message;

  const ReportResult({required this.action, required this.message});
}

/// Global helper to show a report bottom sheet from any screen.
/// Usage: showReportSheet(context, userId: '...', userName: '...', contentType: 'event');
Future<void> showReportSheet(
  BuildContext context, {
  required String userId,
  required String userName,
  required String contentType,
  String content = '',
}) async {
  final reasons = [
    {'label': 'Beleidigung / Hassrede', 'key': 'insult'},
    {'label': 'Spam / Werbung', 'key': 'spam'},
    {'label': 'Unangemessene Inhalte', 'key': 'inappropriate'},
    {'label': 'Betrug / Fake', 'key': 'fraud'},
    {'label': 'Sonstiges', 'key': 'other'},
  ];

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Inhalt melden',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Warum möchtest du "$userName" melden?',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 16),
          ...reasons.map((r) => ListTile(
                title: Text(r['label']!, style: const TextStyle(fontSize: 14)),
                leading: const Icon(Icons.flag_outlined, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result =
                      await BlockReportService.instance.reportContent(
                    reporterUserId:
                        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
                    reportedUserId: userId,
                    contentType: contentType,
                    content: content.isNotEmpty ? content : userName,
                    reason: r['key']!,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(result.message,
                                style: const TextStyle(fontSize: 13))),
                      ]),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
              )),
        ]),
      ),
    ),
  );
}
