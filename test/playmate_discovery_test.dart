import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/ui/widgets/playmate_discovery_error.dart';

ParentMatchingBackendService service(http.Client client) =>
    ParentMatchingBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authToken: 'test-token',
        httpClient: client,
      ),
    );

Map<String, dynamic> match() => {
  'profile': {'id': 'family', 'ownerUserId': 'other', 'name': 'Other family'},
  'score': 75,
  'breakdown': {'distanceKm': 2},
};

void main() {
  test(
    'discovery uses the injected authenticated client and encoded query',
    () async {
      final matching = service(
        MockClient((request) async {
          expect(request.url.path, '/parent-matching/discover');
          expect(request.headers.containsKey('Authorization'), isTrue);
          expect(request.url.queryParameters, {
            'userId': 'owner&extra=value',
            'limit': '20',
            'maxDistanceKm': '10.0',
          });
          return http.Response(
            jsonEncode({
              'matches': [match()],
            }),
            200,
          );
        }),
      );
      final results = await matching.findMatches(
        userId: 'owner&extra=value',
        limit: 20,
        maxDistanceKm: 10,
      );
      expect(results.single.profile.userId, 'other');
      expect(results.single.score, 75);
      expect(results.single.breakdown['distanceKm'], 2);
    },
  );

  test(
    'empty successful radii expand in order until the first real matches',
    () async {
      final radii = <String>[];
      final matching = service(
        MockClient((request) async {
          final radius = request.url.queryParameters['maxDistanceKm']!;
          radii.add(radius);
          return http.Response(
            jsonEncode({
              'matches': radius == '100.0' ? [match()] : [],
            }),
            200,
          );
        }),
      );
      final result = await matching.findMatchesWithFallback(userId: 'owner');
      expect(radii, ['10.0', '50.0', '100.0']);
      expect(result.scope, '100km');
      expect(result.matches.single.profile.id, 'family');
      expect(result.globalDigitalMode, isFalse);
    },
  );

  test(
    'only four successful empty responses enable the existing global mode',
    () async {
      var calls = 0;
      final matching = service(
        MockClient((_) async {
          calls++;
          return http.Response('{"matches":[]}', 200);
        }),
      );
      final result = await matching.findMatchesWithFallback(
        userId: 'owner',
        childAges: ['3J'],
      );
      expect(calls, 4);
      expect(result.matches, isEmpty);
      expect(result.globalDigitalMode, isTrue);
      expect(result.scope, 'global');
      expect(matching.lastSyncError, isNull);
    },
  );

  for (final status in [401, 403, 404, 503]) {
    test(
      'HTTP $status stops radius expansion and is not a successful empty list',
      () async {
        var calls = 0;
        final matching = service(
          MockClient((_) async {
            calls++;
            return http.Response('{"error":"failed"}', status);
          }),
        );
        await expectLater(
          matching.findMatchesWithFallback(userId: 'owner'),
          throwsA(
            isA<BackendApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              status,
            ),
          ),
        );
        expect(calls, 1);
        expect(matching.lastSyncError, isNotNull);
      },
    );
  }

  test(
    'a failure at a later radius does not continue into country/global mode',
    () async {
      var calls = 0;
      final matching = service(
        MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('{"matches":[]}', 200)
              : http.Response('{"error":"failed"}', 503);
        }),
      );
      await expectLater(
        matching.findMatchesWithFallback(userId: 'owner'),
        throwsA(isA<BackendApiException>()),
      );
      expect(calls, 2);
    },
  );

  test('malformed success responses and entries are explicit errors', () async {
    for (final response in [
      '{}',
      '[]',
      'not json',
      '{"matches":null}',
      '{"matches":"bad"}',
      '{"matches":[{}]}',
      '{"matches":[{"profile":{"id":"p","name":"Family"},"score":"bad"}]}',
      '{"matches":[{"profile":{"id":"","name":"Family"},"score":50}]}',
    ]) {
      var calls = 0;
      final matching = service(
        MockClient((_) async {
          calls++;
          return http.Response(response, 200);
        }),
      );
      await expectLater(
        matching.findMatchesWithFallback(userId: 'owner'),
        throwsFormatException,
      );
      expect(calls, 1);
      expect(matching.lastSyncError, isNotNull);
    }
  });

  test(
    'offline errors propagate and retry can return a genuine success',
    () async {
      var calls = 0;
      final matching = service(
        MockClient((_) async {
          if (++calls == 1) throw http.ClientException('offline');
          return http.Response(
            jsonEncode({
              'matches': [match()],
            }),
            200,
          );
        }),
      );
      await expectLater(
        matching.findMatchesWithFallback(userId: 'owner'),
        throwsA(isA<http.ClientException>()),
      );
      final retry = await matching.findMatchesWithFallback(userId: 'owner');
      expect(retry.matches, hasLength(1));
      expect(retry.scope, '10km');
      expect(matching.lastSyncError, isNull);
    },
  );

  test(
    'missing authenticated configuration or invalid query never returns empty success',
    () async {
      final unconfigured = ParentMatchingBackendService();
      await expectLater(
        unconfigured.findMatches(userId: 'owner'),
        throwsStateError,
      );
      expect(unconfigured.lastSyncError, isNotNull);
      var calls = 0;
      final matching = service(
        MockClient((_) async {
          calls++;
          return http.Response('{"matches":[]}', 200);
        }),
      );
      await expectLater(matching.findMatches(userId: ''), throwsStateError);
      await expectLater(
        matching.findMatches(userId: 'owner', limit: 0),
        throwsArgumentError,
      );
      await expectLater(
        matching.findMatches(userId: 'owner', maxDistanceKm: double.nan),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );

  testWidgets(
    'error panel provides retry instead of an empty-family invitation',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: PlaymateDiscoveryError(onRetry: () => retries++),
          ),
        ),
      );
      expect(
        find.text(
          AppStringsManager.getString('en', 'network_discovery_failed'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppStringsManager.getString('en', 'network_discovery_retry')),
      );
      expect(retries, 1);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: PlaymateDiscoveryError(
              messageKey: 'network_discovery_auth_failed',
              onRetry: () => retries++,
            ),
          ),
        ),
      );
      expect(
        find.text(
          AppStringsManager.getString('en', 'network_discovery_auth_failed'),
        ),
        findsOneWidget,
      );
    },
  );
}
