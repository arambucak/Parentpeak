import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_suggestions.dart';

MatchResult candidate(String? owner, {String? id, String? name}) => MatchResult(
  profile: ParentMatchingProfile(
    id: id ?? 'profile-$owner',
    userId: owner,
    name: name ?? 'Family $owner',
    city: 'Berlin',
    childAges: ['3J'],
  ),
  score: 80,
  breakdown: {},
);

List<PlaymateSuggestion> select(
  Iterable<MatchResult> matches, {
  Set<String> friends = const {},
  Set<String> dismissed = const {},
  Set<String> blocked = const {},
  int limit = 6,
}) => selectPlaymateSuggestions(
  matches: matches,
  userId: 'viewer',
  friendIds: friends,
  dismissedIds: dismissed,
  isBlocked: blocked.contains,
  limit: limit,
);

void main() {
  test('suggestions reuse authenticated matching without a legacy request',
      () async {
    final paths = <String>[];
    final matching = ParentMatchingBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authToken: 'test-token',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers.containsKey('Authorization'), isTrue);
          return http.Response(jsonEncode({
            'matches': [
              {
                'profile': {
                  'id': 'profile-other',
                  'ownerUserId': 'other',
                  'name': 'Other family',
                  'city': 'Berlin',
                  'childAges': ['3J'],
                  'children': [
                    {
                      'name': 'Private child',
                      'birthDate': '2023-01-02',
                      'specialAttributes': 'Private health detail',
                    },
                  ],
                },
                'score': 80,
                'breakdown': {},
              },
            ],
          }), 200);
        }),
      ),
    );
    final discovery = await matching.findMatchesWithFallback(userId: 'viewer');
    final suggestion = select(discovery.matches).single;
    expect(paths, ['/parent-matching/discover']);
    expect(suggestion.userId, 'other');
    expect(suggestion.name, 'Other family');
    expect(suggestion.city, 'Berlin');
    expect(suggestion.childAgeTags, ['3J']);
    expect(suggestion.childAgeTags.join(), isNot(contains('Private child')));
  });

  test('self, friends, dismissed, blocked and unaddressable owners are excluded',
      () {
    final suggestions = select(
      [
        candidate('viewer'),
        candidate('friend'),
        candidate('dismissed'),
        candidate('blocked'),
        candidate(null),
        candidate(' '),
        candidate('visible'),
      ],
      friends: {'friend'},
      dismissed: {'dismissed'},
      blocked: {'blocked'},
    );
    expect(suggestions.map((s) => s.userId), ['visible']);
  });

  test('deduplicates by account UID, not profile ID, preserving match order', () {
    final suggestions = select([
      candidate('first', id: 'one', name: 'First public copy'),
      candidate('second', id: 'two'),
      candidate('first', id: 'three', name: 'Duplicate'),
    ]);
    expect(suggestions.map((s) => s.userId), ['first', 'second']);
    expect(suggestions.first.name, 'First public copy');
  });

  test('six-card limit applies after filtering, with no invented candidates', () {
    final matches = [
      candidate('blocked'),
      for (var i = 0; i < 9; i++) candidate('visible-$i'),
    ];
    final suggestions = select(matches, blocked: {'blocked'});
    expect(suggestions, hasLength(6));
    expect(suggestions.map((s) => s.userId),
        [for (var i = 0; i < 6; i++) 'visible-$i']);
    expect(select(matches, blocked: {'blocked'}, limit: 2), hasLength(2));
    expect(select([]), isEmpty);
  });

  test('new friendship, block and dismissal state immediately removes cards',
      () {
    final matches = [candidate('one'), candidate('two'), candidate('three')];
    expect(select(matches), hasLength(3));
    expect(select(matches, friends: {'one'}).map((s) => s.userId),
        ['two', 'three']);
    expect(select(matches, dismissed: {'two'}).map((s) => s.userId),
        ['one', 'three']);
    expect(select(matches, blocked: {'three'}).map((s) => s.userId),
        ['one', 'two']);
    final tags = select(matches).first.childAgeTags;
    expect(() => tags.add('4J'), throwsUnsupportedError);
    expect(matches.first.profile.childAges, ['3J']);
  });

  test('invalid account or card limit is an explicit caller error', () {
    expect(
      () => selectPlaymateSuggestions(
        matches: [],
        userId: ' ',
        friendIds: {},
        dismissedIds: {},
        isBlocked: (_) => false,
      ),
      throwsArgumentError,
    );
    expect(() => select([], limit: 0), throwsArgumentError);
  });
}
