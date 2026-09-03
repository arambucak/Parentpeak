import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// Backend-Service für Spielfreunde + Referral.
///
/// Verbindet die App mit:
/// - POST/GET /api/spielfreunde/profiles
/// - GET /api/spielfreunde/waitlist-count
/// - POST /api/referral/register
/// - GET /api/referral/status/:code
/// - POST /api/referral/redeem
class SpielfreundeBackendService {
  SpielfreundeBackendService({BackendApiClient? apiClient})
      : _api = apiClient ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _api;
  String? lastError;

  /// Profil auf dem Server speichern.
  Future<bool> saveProfile(FamilyMatchProfile profile, String userId) async {
    if (_api == null) return false;
    lastError = null;
    try {
      await _api!.postJsonAny('/api/spielfreunde/profiles', {
        'userId': userId,
        'displayName': profile.displayName,
        'district': profile.district,
        'children': profile.children.map((c) => c.toJson()).toList(),
        'languages': profile.languages,
        'familyForm': profile.familyForm,
        'values': profile.values,
        'lookingFor': profile.lookingFor,
        'availability': profile.availability,
        'specials': profile.specials,
        'bio': profile.bio,
      });
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('SpielfreundeBackendService.saveProfile failed: $e');
      return false;
    }
  }

  /// Warteliste-Counter für einen Stadtteil abrufen.
  Future<WaitlistStatus> getWaitlistCount(String? district) async {
    if (_api == null)
      return WaitlistStatus(
          total: 0, threshold: 20, remaining: 20, progress: 0);
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
    return WaitlistStatus(total: 0, threshold: 20, remaining: 20, progress: 0);
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

  /// Referral registrieren (wenn eingeladener User sich registriert).
  Future<bool> registerReferral(
      String referralCode, String newUserId, String newUserName) async {
    if (_api == null) return false;
    try {
      await _api!.postJsonAny('/api/referral/register', {
        'referralCode': referralCode,
        'newUserId': newUserId,
        'newUserName': newUserName,
      });
      return true;
    } catch (e) {
      debugPrint('SpielfreundeBackendService.registerReferral failed: $e');
      return false;
    }
  }

  /// Referral-Status abrufen.
  Future<ReferralStatus> getReferralStatus(String code) async {
    if (_api == null) return ReferralStatus(code: code, coins: 0, invites: 0);
    try {
      final data = await _api!.getJson('/api/referral/status/$code');
      if (data is Map<String, dynamic>) {
        return ReferralStatus(
          code: code,
          coins: (data['totalCoins'] as num?)?.toInt() ?? 0,
          invites: (data['totalInvites'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('SpielfreundeBackendService.getReferralStatus failed: $e');
    }
    return ReferralStatus(code: code, coins: 0, invites: 0);
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

  /// Coins einloesen.
  Future<bool> redeemCoins(String referralCode, int amount) async {
    if (_api == null) return false;
    try {
      await _api!.postJsonAny('/api/referral/redeem', {
        'referralCode': referralCode,
        'coinsToSpend': amount,
      });
      return true;
    } catch (e) {
      debugPrint('SpielfreundeBackendService.redeemCoins failed: $e');
      return false;
    }
  }

  Future<void> registerFriendCode(String code, String name,
      {String? userId}) async {
    if (_api == null) return;
    try {
      await _api!.postJsonAny('/api/friends/register', {
        'code': code,
        'name': name,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      });
    } catch (e) {
      debugPrint('registerFriendCode failed: $e');
    }
  }

  Future<String?> lookupFriendName(String code) async {
    if (_api == null) return null;
    try {
      final data = await _api!
          .getJson('/api/friends/lookup/${Uri.encodeComponent(code)}');
      if (data is Map<String, dynamic>) return data['name'] as String?;
    } catch (_) {}
    return null;
  }

  Future<void> notifyFriendConnect(
      String fromCode, String fromName, String toCode) async {
    if (_api == null) return;
    try {
      await _api!.postJsonAny('/api/friends/connect', {
        'fromCode': fromCode,
        'fromName': fromName,
        'toCode': toCode,
      });
    } catch (e) {
      debugPrint('notifyFriendConnect failed: $e');
    }
  }

  /// Returns list of { fromCode, fromName } who added this code since last call.
  Future<List<Map<String, dynamic>>> claimPendingFriendConnections(
      String code) async {
    if (_api == null) return [];
    try {
      final data = await _api!
          .getJson('/api/friends/pending/${Uri.encodeComponent(code)}');
      if (data is Map<String, dynamic> && data['connections'] is List) {
        return List<Map<String, dynamic>>.from(data['connections']);
      }
    } catch (e) {
      debugPrint('claimPendingFriendConnections failed: $e');
    }
    return [];
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

class ReferralStatus {
  final String code;
  final int coins;
  final int invites;
  const ReferralStatus(
      {required this.code, required this.coins, required this.invites});
}
