import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';

/// Legacy reads for suggestions; profile publication uses PlaymateProfileService.
class SpielfreundeBackendService {
  SpielfreundeBackendService({BackendApiClient? apiClient})
      : _api = apiClient ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _api;
  String? lastError;

  /// Warteliste-Counter für einen Stadtteil abrufen.
  Future<WaitlistStatus> getWaitlistCount(String? district) async {
    if (_api == null) {
      return const WaitlistStatus(
          total: 0, threshold: 20, remaining: 20, progress: 0);
    }
    try {
      final path = district != null && district.isNotEmpty
          ? '/api/spielfreunde/waitlist-count?district=$district'
          : '/api/spielfreunde/waitlist-count';
      final data = await _api!.getJson(path);
      if (data is Map<String, dynamic>) {
        return WaitlistStatus(
          total: (data['total'] as num?)?.toInt() ?? 0,
          threshold: (data['threshold'] as num?)?.toInt() ?? 20,
          remaining: (data['remaining'] as num?)?.toInt() ?? 20,
          progress: (data['progress'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('SpielfreundeBackendService.getWaitlistCount failed: $e');
    }
    return const WaitlistStatus(
        total: 0, threshold: 20, remaining: 20, progress: 0);
  }

  /// Andere Familien-Profile abrufen (gefiltert).
  Future<List<Map<String, dynamic>>> getProfiles({
    String? district,
    String? familyForm,
    String? language,
    String? excludeUserId,
  }) async {
    if (_api == null) return [];
    try {
      final params = <String>[];
      if (district != null) params.add('district=$district');
      if (familyForm != null) params.add('familyForm=$familyForm');
      if (language != null) params.add('language=$language');
      if (excludeUserId != null) params.add('userId=$excludeUserId');
      final query = params.isEmpty ? '' : '?${params.join('&')}';
      final data = await _api!.getJson('/api/spielfreunde/profiles$query');
      if (data is Map<String, dynamic> && data['items'] is List) {
        return List<Map<String, dynamic>>.from(data['items']);
      }
    } catch (e) {
      debugPrint('SpielfreundeBackendService.getProfiles failed: $e');
    }
    return [];
  }

  /// Profil vom Server loeschen.
  Future<bool> deleteProfile(String userId) async {
    if (_api == null) return false;
    try {
      await _api!.delete('/api/spielfreunde/profiles/$userId');
      return true;
    } catch (e) {
      debugPrint('SpielfreundeBackendService.deleteProfile failed: $e');
      return false;
    }
  }
}

class WaitlistStatus {
  final int total;
  final int threshold;
  final int remaining;
  final double progress;
  const WaitlistStatus(
      {required this.total,
      required this.threshold,
      required this.remaining,
      required this.progress});
}
