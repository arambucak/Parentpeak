import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Manages blocked users and content reports across the entire app.
/// Used in: Chat, Verschenkmarkt, Events, Netzwerk.
class BlockReportService {
  static final BlockReportService instance = BlockReportService();
  BlockReportService({
    BackendApiClient? api,
    String? Function()? userIdProvider,
  }) : _api = api ?? BackendServiceFactory.createVerifiedApiClient(),
       _userIdProvider = userIdProvider ??
           (() => FirebaseAuth.instance.currentUser?.uid);

  static const String _blockedKey = 'safety.blocked_users';
  static const String _reportsKey = 'safety.reports';

  List<BlockedUser> _blockedUsers = [];
  List<ContentReport> _reports = [];

  final BackendApiClient? _api;
  final String? Function() _userIdProvider;

  List<BlockedUser> get blockedUsers => List.unmodifiable(_blockedUsers);

  /// Current signed-in user id, used as the server-side owner of blocks/reports.
  String get _currentUserId => _userIdProvider() ?? 'anonymous';

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
  /// Returns true only after the server accepted the report.
  Future<bool> reportContent({
    required String reporterUserId,
    required String reportedUserId,
    required String contentType, // 'message', 'listing', 'event', 'profile'
    required String content,
    required String
        reason, // 'insult', 'spam', 'inappropriate', 'fraud', 'other'
  }) async {
    final delivered = await _postReport(
      reporterUserId: reporterUserId,
      reportedUserId: reportedUserId,
      contentType: contentType,
      content: content,
      reason: reason,
    );
    if (!delivered) return false;

    _reports.add(ContentReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      reporterUserId: reporterUserId,
      reportedUserId: reportedUserId,
      contentType: contentType,
      content: content,
      reason: reason,
      createdAt: DateTime.now(),
    ));
    try {
      await _save();
    } catch (error) {
      // Delivery already succeeded; local history must not change that result.
      debugPrint(
        'BlockReportService delivered report history save failed: $error',
      );
    }
    return true;
  }

  /// Reports an event (AI-discovered or user-hosted) to the moderation queue.
  /// Returns true only when the server accepted the report, so the UI never
  /// claims success for a report that was not delivered.
  /// AI events have no host account; they are reported under the pseudo
  /// account `ai_event:<id>` so they show up grouped in the admin dashboard.
  Future<bool> reportEvent({
    required String eventId,
    required String eventTitle,
    required String reason,
    String? hostUserId,
  }) async {
    final reporterUserId = _currentUserId;
    if (reporterUserId == 'anonymous') return false;
    final reportedUserId = (hostUserId != null && hostUserId.trim().isNotEmpty)
        ? hostUserId.trim()
        : 'ai_event:$eventId';
    final content = '[$eventId] $eventTitle';
    return reportContent(
      reporterUserId: reporterUserId,
      reportedUserId: reportedUserId,
      contentType: 'event',
      content: content,
      reason: reason,
    );
  }

  Future<bool> _postReport({
    required String reporterUserId,
    required String reportedUserId,
    required String contentType,
    required String content,
    required String reason,
  }) async {
    final api = _api;
    if (api == null) {
      debugPrint('BlockReportService report failed: backend unavailable');
      return false;
    }
    try {
      await api.postJsonAny('/api/safety/report', {
        'reporterUserId': reporterUserId,
        'reportedUserId': reportedUserId,
        'contentType': contentType,
        'content': content,
        'reason': reason,
      });
      return true;
    } catch (e) {
      debugPrint('BlockReportService report server sync failed: $e');
      return false;
    }
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
    if (_reports.length > 100) {
      _reports = _reports.sublist(_reports.length - 100);
    }
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

/// Global helper to show a report bottom sheet from any screen.
/// Usage: showReportSheet(context, userId: '...', userName: '...', contentType: 'event');
Future<void> showReportSheet(
  BuildContext context, {
  required String userId,
  required String userName,
  required String contentType,
  String content = '',
  BlockReportService? reportService,
}) async {
  final service = reportService ?? BlockReportService.instance;
  final reasons = [
    {'label': 'Beleidigung / Hassrede', 'key': 'insult'},
    {'label': 'Spam / Werbung', 'key': 'spam'},
    {'label': 'Unangemessene Inhalte', 'key': 'inappropriate'},
    {'label': 'Betrug / Fake', 'key': 'fraud'},
    {'label': 'Sonstiges', 'key': 'other'},
  ];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
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
                  final delivered = await service.reportContent(
                    reporterUserId: service._currentUserId,
                    reportedUserId: userId,
                    contentType: contentType,
                    content: content.isNotEmpty ? content : userName,
                    reason: r['key']!,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        Icon(
                            delivered
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(context.tr(delivered
                                ? 'report_delivery_success'
                                : 'report_delivery_failed'),
                                style: const TextStyle(fontSize: 13))),
                      ]),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: delivered
                          ? const Color(0xFF16A34A)
                          : null,
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
