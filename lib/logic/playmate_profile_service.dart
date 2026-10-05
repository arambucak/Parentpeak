import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlaymatePublicationResult { cancelled, failed, published }

/// Rounds location to a coarse grid before publishing it to other families.
double? coarseCoordinate(double? value) {
  if (value == null || !value.isFinite) return null;
  return (value * 100).round() / 100;
}

class PlaymateProfileService {
  PlaymateProfileService({required this.matchingService});

  final ParentMatchingBackendService matchingService;

  Future<PlaymatePublicationResult> publishProfile(
    FamilyMatchProfile profile,
    String userId, {
    required Future<bool> Function() confirmPublication,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    if (!await confirmPublication()) return PlaymatePublicationResult.cancelled;
    if (userId.trim().isEmpty) {
      debugPrint('PlaymateProfileService.publishProfile: user ID missing');
      return PlaymatePublicationResult.failed;
    }
    final saved = await matchingService.createProfile(
      userId: userId,
      name: profile.displayName,
      city: city?.trim().isNotEmpty == true ? city!.trim() : profile.district,
      latitude: coarseCoordinate(latitude),
      longitude: coarseCoordinate(longitude),
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
    await profile.save();
    return PlaymatePublicationResult.published;
  }

  Future<bool> deleteProfile(String userId) async {
    if (!await matchingService.deleteProfile(userId: userId)) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('spielfreunde.profile') &&
        !await prefs.remove('spielfreunde.profile')) {
      throw StateError('Could not remove the local playmate profile');
    }
    return true;
  }
}
