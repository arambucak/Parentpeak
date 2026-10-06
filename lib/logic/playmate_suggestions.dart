import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';

class PlaymateSuggestion {
  final String userId;
  final String name;
  final String city;
  final List<String> childAgeTags;

  const PlaymateSuggestion({
    required this.userId,
    required this.name,
    required this.city,
    required this.childAgeTags,
  });
}

List<PlaymateSuggestion> selectPlaymateSuggestions({
  required Iterable<MatchResult> matches,
  required String userId,
  required Set<String> friendIds,
  required Set<String> dismissedIds,
  required bool Function(String) isBlocked,
  int limit = 6,
}) {
  if (userId.trim().isEmpty || limit < 1) {
    throw ArgumentError('Suggestion account and positive limit required');
  }
  final suggestions = <PlaymateSuggestion>[];
  final seen = <String>{};
  for (final match in matches) {
    final profile = match.profile;
    final ownerId = profile.userId;
    if (ownerId == null || ownerId.trim().isEmpty) {
      debugPrint('Skipping matching suggestion without an account owner');
      continue;
    }
    if (ownerId == userId ||
        friendIds.contains(ownerId) ||
        dismissedIds.contains(ownerId) ||
        isBlocked(ownerId) ||
        !seen.add(ownerId)) {
      continue;
    }
    suggestions.add(PlaymateSuggestion(
      userId: ownerId,
      name: profile.name,
      city: profile.city,
      childAgeTags: List.unmodifiable(profile.childAges),
    ));
    if (suggestions.length == limit) break;
  }
  return suggestions;
}
