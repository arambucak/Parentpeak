import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Ein gemeldeter Nutzer, gruppiert (Grund, Zeitstempel, Anzahl, gesperrt?).
class ReportGroup {
  final String reportedUserId;
  final int reportCount;
  final String lastReason;
  final DateTime? lastReportedAt;
  final bool suspended;

  const ReportGroup({
    required this.reportedUserId,
    required this.reportCount,
    required this.lastReason,
    required this.lastReportedAt,
    required this.suspended,
  });

  factory ReportGroup.fromJson(Map<String, dynamic> j) => ReportGroup(
        reportedUserId: j['reportedUserId'] as String? ?? '',
        reportCount: (j['reportCount'] as num?)?.toInt() ?? 0,
        lastReason: j['lastReason'] as String? ?? '',
        lastReportedAt:
            DateTime.tryParse(j['lastReportedAt']?.toString() ?? ''),
        suspended: j['suspended'] == true,
      );
}

/// Eine einzelne Meldung (Detailansicht).
class ReportDetail {
  final String id;
  final String reportedUserId;
  final String reporterUserId;
  final String contentType;
  final String content;
  final String reason;
  final String status;
  final DateTime? createdAt;

  const ReportDetail({
    required this.id,
    required this.reportedUserId,
    required this.reporterUserId,
    required this.contentType,
    required this.content,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory ReportDetail.fromJson(Map<String, dynamic> j) => ReportDetail(
        id: j['id'] as String? ?? '',
        reportedUserId: j['reportedUserId'] as String? ?? '',
        reporterUserId: j['reporterUserId'] as String? ?? '',
        contentType: j['contentType'] as String? ?? '',
        content: j['content'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      );
}

class AdminReportsResult {
  final List<ReportGroup> groups;
  final List<ReportDetail> reports;
  const AdminReportsResult({required this.groups, required this.reports});
}

/// Client fuer das Moderations-Dashboard. Ruft die /admin/* Endpoints.
/// Der Server prueft die Admin-Berechtigung (ADMIN_USER_IDS) – dieser Client
/// setzt sie nur voraus. Der Firebase-Token wird automatisch mitgesendet.
class AdminModerationService {
  AdminModerationService({BackendApiClient? apiClient})
      : _api = apiClient ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _api;

  Future<AdminReportsResult> fetchReports({String status = 'pending'}) async {
    final api = _api;
    if (api == null) {
      return const AdminReportsResult(groups: [], reports: []);
    }
    final data = await api.getJson('/admin/reports?status=$status');
    if (data is Map<String, dynamic>) {
      final groups = (data['groups'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportGroup.fromJson)
          .toList();
      final reports = (data['reports'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportDetail.fromJson)
          .toList();
      return AdminReportsResult(groups: groups, reports: reports);
    }
    return const AdminReportsResult(groups: [], reports: []);
  }

  Future<bool> resolveReportsForUser(String reportedUserId) async {
    final api = _api;
    if (api == null) return false;
    try {
      await api.postJsonAny('/admin/reports/resolve', {
        'reportedUserId': reportedUserId,
      });
      return true;
    } catch (e) {
      debugPrint('AdminModerationService.resolveReportsForUser failed: $e');
      return false;
    }
  }

  Future<bool> suspendUser(String userId, {String reason = ''}) async {
    final api = _api;
    if (api == null) return false;
    try {
      await api.postJsonAny('/admin/users/$userId/suspend', {
        'reason': reason,
      });
      return true;
    } catch (e) {
      debugPrint('AdminModerationService.suspendUser failed: $e');
      return false;
    }
  }

  Future<bool> unsuspendUser(String userId) async {
    final api = _api;
    if (api == null) return false;
    try {
      await api.postJsonAny('/admin/users/$userId/unsuspend', {});
      return true;
    } catch (e) {
      debugPrint('AdminModerationService.unsuspendUser failed: $e');
      return false;
    }
  }

  /// Vorschau: wie viele kaputte Freundschafts-Kanten wuerden bereinigt.
  /// Loescht nichts. Gibt -1 bei Fehler zurueck.
  Future<int> cleanupPreview() async {
    final api = _api;
    if (api == null) return -1;
    try {
      final data = await api.getJson('/admin/friends/cleanup-preview');
      if (data is Map<String, dynamic>) {
        return (data['brokenCount'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('AdminModerationService.cleanupPreview failed: $e');
      return -1;
    }
  }

  /// Fuehrt den Cleanup aus (loescht kaputte Kanten). Gibt Anzahl geloeschter
  /// Eintraege zurueck, -1 bei Fehler.
  Future<int> runCleanup() async {
    final api = _api;
    if (api == null) return -1;
    try {
      final data = await api.postJsonAny('/admin/friends/cleanup', {
        'confirm': true,
      });
      if (data is Map<String, dynamic>) {
        return (data['deleted'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('AdminModerationService.runCleanup failed: $e');
      return -1;
    }
  }
}
