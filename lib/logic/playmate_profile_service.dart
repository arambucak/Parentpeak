import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlaymatePublicationResult { cancelled, failed, published }

enum PlaymateProfileStatus { draft, active, unavailable }

class PlaymateProfileState {
  const PlaymateProfileState({
    required this.status,
    this.profile,
    this.hasUnassignedDraft = false,
  });
  final PlaymateProfileStatus status;
  final FamilyMatchProfile? profile;
  final bool hasUnassignedDraft;
}

/// Rounds location to a coarse grid before publishing it to other families.
double? coarseCoordinate(double? value) {
  if (value == null || !value.isFinite) return null;
  return (value * 100).round() / 100;
}

class PlaymateProfileService {
  PlaymateProfileService({required this.matchingService});

  final ParentMatchingBackendService matchingService;
  static bool _assigningLegacyDraft = false;

  Future<PlaymateProfileState> loadState(String userId) async {
    final profile = await FamilyMatchProfile.load(
      userId: userId,
      throwOnError: true,
    );
    final prefs = await SharedPreferences.getInstance();
    final hasDraft =
        profile == null && prefs.containsKey('spielfreunde.profile');
    final remote = await matchingService.fetchMyProfile(userId: userId);
    return PlaymateProfileState(
      profile: profile,
      hasUnassignedDraft: hasDraft,
      status: matchingService.lastSyncError != null
          ? PlaymateProfileStatus.unavailable
          : remote == null
          ? PlaymateProfileStatus.draft
          : PlaymateProfileStatus.active,
    );
  }

  Future<bool> adoptUnassignedDraft(
    String userId, {
    required Future<bool> Function() confirmOwnership,
  }) async {
    if (_assigningLegacyDraft) {
      throw StateError('A legacy draft assignment is already in progress');
    }
    _assigningLegacyDraft = true;
    try {
      if (await FamilyMatchProfile.load(userId: userId, throwOnError: true) !=
          null) {
        throw StateError('An account profile already exists');
      }
      if (!await confirmOwnership()) return false;
      if (await FamilyMatchProfile.load(userId: userId, throwOnError: true) !=
          null) {
        throw StateError('An account profile already exists');
      }
      final draft = await FamilyMatchProfile.loadUnassignedDraft();
      if (draft == null) {
        throw StateError('The unassigned draft no longer exists');
      }
      await draft.save(userId: userId);
      final prefs = await SharedPreferences.getInstance();
      try {
        if (!await prefs.remove('spielfreunde.profile')) {
          throw StateError('Could not finish assigning the legacy draft');
        }
      } catch (_) {
        await FamilyMatchProfile.removeForAccount(userId);
        rethrow;
      }
      return true;
    } finally {
      _assigningLegacyDraft = false;
    }
  }

  Future<PlaymatePublicationResult> publishProfile(
    FamilyMatchProfile profile,
    String userId, {
    required Future<bool> Function() confirmPublication,
  }) async {
    if (!await confirmPublication()) return PlaymatePublicationResult.cancelled;
    if (userId.trim().isEmpty) {
      debugPrint('PlaymateProfileService.publishProfile: user ID missing');
      return PlaymatePublicationResult.failed;
    }
    final saved = await matchingService.createProfile(
      userId: userId,
      name: profile.displayName,
      city: profile.city?.trim().isNotEmpty == true
          ? profile.city!.trim()
          : profile.district,
      latitude: coarseCoordinate(profile.latitude),
      longitude: coarseCoordinate(profile.longitude),
      interests: profile.lookingFor.where((v) => v.trim().isNotEmpty).toList(),
      languages: profile.languages,
      valuesFocus: profile.values,
      childAges: profile.children.map((child) {
        final months = child.ageMonths;
        return months >= 12 ? '${months ~/ 12}J' : '${months}M';
      }).toList(),
      familyForm: profile.familyForm,
      bio: profile.bio,
    );
    if (saved == null || saved.id.isEmpty || saved.userId != userId) {
      debugPrint(
        'PlaymateProfileService.publishProfile: profile not acknowledged',
      );
      return PlaymatePublicationResult.failed;
    }
    await profile.save(userId: userId);
    return PlaymatePublicationResult.published;
  }

  Future<bool> deleteProfile(String userId) async {
    if (!await matchingService.deleteProfile(userId: userId)) return false;
    await FamilyMatchProfile.removeForAccount(userId);
    return true;
  }
}
