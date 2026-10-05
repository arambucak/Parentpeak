import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaymateProfileService {
  PlaymateProfileService({required this.matchingService});

  final ParentMatchingBackendService matchingService;

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
