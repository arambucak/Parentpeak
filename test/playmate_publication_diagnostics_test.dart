import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/logic/playmate_publication_failure.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilyMatchProfile _profile() => FamilyMatchProfile(
      displayName: 'Test family',
      district: 'Berlin',
      city: 'Berlin',
      children: [ChildEntry(name: 'Local child', ageMonths: 36)],
      languages: ['de', 'tr'],
      familyForm: 'kernfamilie',
      values: [],
      lookingFor: ['spielplatz'],
      bio: 'Test bio',
      createdAt: DateTime(2026, 1, 1),
    );

PlaymateProfileService _service(
  Future<http.Response> Function(http.Request) handler, {
  required bool fallback,
  Future<String?> Function()? tokenProvider,
  bool requireAuthToken = false,
}) {
  final client = MockClient(handler);
  addTearDown(client.close);
  final token = tokenProvider ?? () async => 'test-only-token';
  return PlaymateProfileService(
    matchingService: fallback
        ? ParentMatchingBackendService(
            httpClient: client,
            firebaseTokenProvider: token,
          )
        : ParentMatchingBackendService(
            apiClient: BackendApiClient(
              baseUrl: 'https://backend.example',
              httpClient: client,
              authTokenProvider: token,
              requireAuthToken: requireAuthToken,
            ),
          ),
  );
}

Future<PlaymatePublicationResult> _publish(
  PlaymateProfileService service, {
  String userId = 'owner',
}) =>
    service.publishProfile(
      _profile(),
      userId,
      confirmPublication: () async => true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
        envString: 'BACKEND_BASE_URL=https://backend.example');
  });
  tearDown(dotenv.clean);

  final statusCases = [
    (400, PlaymatePublicationFailureReason.invalid, 'network_publish_invalid'),
    (
      401,
      PlaymatePublicationFailureReason.unauthenticated,
      'network_publish_unauthenticated',
    ),
    (403, PlaymatePublicationFailureReason.forbidden, 'network_publish_failed'),
    (
      408,
      PlaymatePublicationFailureReason.timeout,
      'network_publish_no_connection'
    ),
    (
      429,
      PlaymatePublicationFailureReason.rateLimited,
      'network_publish_failed'
    ),
    (
      500,
      PlaymatePublicationFailureReason.serverUnavailable,
      'network_publish_server_unavailable',
    ),
    (
      502,
      PlaymatePublicationFailureReason.serverUnavailable,
      'network_publish_server_unavailable',
    ),
    (
      503,
      PlaymatePublicationFailureReason.serverUnavailable,
      'network_publish_server_unavailable',
    ),
    (
      504,
      PlaymatePublicationFailureReason.serverUnavailable,
      'network_publish_server_unavailable',
    ),
    (409, PlaymatePublicationFailureReason.unknown, 'network_publish_failed'),
    (404, PlaymatePublicationFailureReason.unknown, 'network_publish_failed'),
  ];

  for (final fallback in [false, true]) {
    final path = fallback ? 'fallback' : 'typed client';
    for (final (status, reason, key) in statusCases) {
      test('$path preserves HTTP $status, body, reason and message key',
          () async {
        final body = jsonEncode({
          'error': 'synthetic private server detail',
          'code': 'diagnostic_server_code',
        });
        var requests = 0;
        final profiles = _service(
          (_) async {
            requests++;
            return http.Response(body, status);
          },
          fallback: fallback,
        );
        expect(await _publish(profiles), PlaymatePublicationResult.failed);
        final failure = profiles.lastPublicationFailure!;
        expect(failure.reason, reason);
        expect(failure.messageKey, key);
        expect(failure.statusCode, status);
        expect(failure.diagnosticCode, 'HTTP $status');
        final apiError =
            profiles.matchingService.lastProfileCreationApiException;
        expect(apiError?.statusCode, status);
        expect(apiError?.responseBody, body);
        expect(apiError?.serverCode, 'diagnostic_server_code');
        expect(profiles.matchingService.lastSyncError, contains('HTTP $status'));
        expect(
          profiles.matchingService.lastSyncError,
          isNot(contains('private server detail')),
        );
        expect(requests, 1);
      });
    }

    final faultCases = [
      (
        'timeout',
        TimeoutException('synthetic private detail'),
        PlaymatePublicationFailureReason.timeout,
        'network_publish_no_connection',
      ),
      (
        'socket',
        const SocketException('synthetic private detail'),
        PlaymatePublicationFailureReason.network,
        'network_publish_no_connection',
      ),
      (
        'client',
        http.ClientException('synthetic private detail'),
        PlaymatePublicationFailureReason.network,
        'network_publish_no_connection',
      ),
      (
        'unknown',
        StateError('synthetic private detail'),
        PlaymatePublicationFailureReason.unknown,
        'network_publish_failed',
      ),
    ];
    for (final (name, error, reason, key) in faultCases) {
      test('$path classifies $name without exposing its exception', () async {
        final profiles = _service((_) async => throw error, fallback: fallback);
        expect(await _publish(profiles), PlaymatePublicationResult.failed);
        expect(profiles.lastPublicationFailure?.reason, reason);
        expect(profiles.lastPublicationFailure?.messageKey, key);
        expect(profiles.lastPublicationFailure?.diagnosticCode, reason.name);
        expect(profiles.matchingService.lastSyncError, isNotEmpty);
        expect(
            profiles.matchingService.lastSyncError, isNot(contains('private')));
      });
    }

    final invalidResponses = {
      'empty': '',
      'empty object': '{}',
      'list': '[]',
      'non-JSON': '<html>synthetic private content</html>',
      'missing ID': '{"item":{"ownerUserId":"owner"}}',
      'empty ID': '{"item":{"id":" ","ownerUserId":"owner"}}',
      'wrong owner': '{"item":{"id":"p","ownerUserId":"someone-else"}}',
      'missing owner': '{"item":{"id":"p"}}',
      'bad field type': '{"item":{"id":"p","ownerUserId":"owner","age":"bad"}}',
      'bad coordinate':
          '{"item":{"id":"p","ownerUserId":"owner","latitude":"bad"}}',
    };
    for (final entry in invalidResponses.entries) {
      test('$path reports ${entry.key} as invalidResponse', () async {
        final profiles = _service(
          (_) async => http.Response(entry.value, 201),
          fallback: fallback,
        );
        expect(await _publish(profiles), PlaymatePublicationResult.failed);
        expect(
          profiles.lastPublicationFailure?.reason,
          PlaymatePublicationFailureReason.invalidResponse,
        );
        expect(profiles.lastPublicationFailure?.messageKey,
            'network_publish_failed');
        expect(
            profiles.lastPublicationFailure?.diagnosticCode, 'invalidResponse');
        expect(profiles.matchingService.lastSyncError, isNotEmpty);
        expect(
            profiles.matchingService.lastSyncError, isNot(contains('private')));
      });
    }

    test('$path reports a missing token without making a request', () async {
      var requests = 0;
      final profiles = _service(
        (_) async {
          requests++;
          return http.Response('{}', 200);
        },
        fallback: fallback,
        tokenProvider: () async => null,
        requireAuthToken: true,
      );
      expect(await _publish(profiles), PlaymatePublicationResult.failed);
      expect(
        profiles.lastPublicationFailure?.reason,
        PlaymatePublicationFailureReason.unauthenticated,
      );
      expect(
        profiles.lastPublicationFailure?.messageKey,
        'network_publish_unauthenticated',
      );
      expect(
          profiles.lastPublicationFailure?.diagnosticCode, 'unauthenticated');
      expect(requests, 0);
    });
  }

  test('missing user is distinct and never sends a request', () async {
    var requests = 0;
    final profiles = _service((_) async {
      requests++;
      return http.Response('{}', 200);
    }, fallback: false);
    for (final userId in ['', '   ']) {
      expect(await _publish(profiles, userId: userId),
          PlaymatePublicationResult.failed);
      expect(
        profiles.lastPublicationFailure?.reason,
        PlaymatePublicationFailureReason.missingUser,
      );
      expect(profiles.lastPublicationFailure?.messageKey,
          'network_publish_failed');
      expect(profiles.lastPublicationFailure?.diagnosticCode, 'missingUser');
      expect(profiles.matchingService.lastSyncError, isNotEmpty);
    }
    expect(requests, 0);
  });

  test('a later success or cancellation clears stale diagnostic state',
      () async {
    var requests = 0;
    final profiles = _service((_) async {
      requests++;
      if (requests == 1) return http.Response('{"error":"unavailable"}', 503);
      return http.Response(
        '{"item":{"id":"p","ownerUserId":"owner","name":"Test","city":"Berlin"}}',
        201,
      );
    }, fallback: false);
    expect(await _publish(profiles), PlaymatePublicationResult.failed);
    expect(profiles.lastPublicationFailure?.statusCode, 503);
    expect(await _publish(profiles), PlaymatePublicationResult.published);
    expect(profiles.lastPublicationFailure, isNull);
    expect(profiles.matchingService.lastSyncError, isNull);
    expect(profiles.matchingService.lastProfileCreationApiException, isNull);
    expect(await FamilyMatchProfile.load(userId: 'owner'), isNotNull);

    expect(
      await profiles.publishProfile(
        _profile(),
        'owner',
        confirmPublication: () async => false,
      ),
      PlaymatePublicationResult.cancelled,
    );
    expect(profiles.lastPublicationFailure, isNull);
    expect(requests, 2);
  });

  test('HTTP and malformed-response diagnostics log only reason and status',
      () async {
    final previousDebugPrint = debugPrint;
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = previousDebugPrint);

    const secret = 'synthetic-token-and-personal-data';
    final responses = [
      http.Response('{"error":"$secret"}', 503),
      http.Response('<html>$secret</html>', 201),
    ];
    for (final response in responses) {
      final profiles = _service((_) async => response, fallback: false);
      expect(await _publish(profiles), PlaymatePublicationResult.failed);
    }
    expect(logs.join('\n'), contains('reason=serverUnavailable status=503'));
    expect(logs.join('\n'), contains('reason=invalidResponse status=none'));
    expect(logs.join('\n'), isNot(contains(secret)));
  });

  test('token-provider exceptions are not printed', () async {
    final previousDebugPrint = debugPrint;
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = previousDebugPrint);
    const secret = 'synthetic-token-provider-secret';
    final profiles = _service(
      (_) async => http.Response('{}', 200),
      fallback: false,
      requireAuthToken: true,
      tokenProvider: () async => throw StateError(secret),
    );
    expect(await _publish(profiles), PlaymatePublicationResult.failed);
    expect(
      profiles.lastPublicationFailure?.reason,
      PlaymatePublicationFailureReason.unauthenticated,
    );
    expect(logs.join('\n'), contains('reason=unauthenticated'));
    expect(logs.join('\n'), isNot(contains(secret)));
  });

  test('a 401 does not log the current user out', () async {
    final auth = AuthService.instance;
    await auth.debugSeedSessionForTesting();
    final userId = auth.currentUser!.uid;
    final previousFactory = AuthService.backendApiClientFactory;
    addTearDown(() async {
      AuthService.backendApiClientFactory = () => null;
      try {
        await auth.logout();
      } finally {
        AuthService.backendApiClientFactory = previousFactory;
      }
    });
    final profiles = _service(
      (_) async => http.Response('{"error":"unauthorized"}', 401),
      fallback: false,
    );
    expect(await _publish(profiles, userId: userId),
        PlaymatePublicationResult.failed);
    expect(auth.currentUser?.uid, userId);
  });

  test('suspended account keeps its existing dedicated notice path', () async {
    final profiles = _service(
      (_) async => http.Response('{"code":"account_suspended"}', 403),
      fallback: false,
    );
    await expectLater(
        _publish(profiles), throwsA(isA<SuspendedAccountException>()));
    expect(
      profiles.lastPublicationFailure?.reason,
      PlaymatePublicationFailureReason.forbidden,
    );
    expect(profiles.lastPublicationFailure?.statusCode, 403);
    expect(
      profiles.matchingService.lastProfileCreationFailure?.reason,
      PlaymatePublicationFailureReason.forbidden,
    );
  });

  test(
      'new publication messages exist and differ from English in all launch languages',
      () {
    const keys = [
      'network_publish_unauthenticated',
      'network_publish_invalid',
      'network_publish_server_unavailable',
      'network_publish_no_connection',
      'network_publish_error_code',
    ];
    const languages = ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];
    for (final language in languages) {
      for (final key in keys) {
        final catalog = AppStringsManager.allStrings[language]!;
        expect(catalog.containsKey(key), isTrue, reason: '$language/$key');
        final text = AppStringsManager.getString(language, key);
        expect(text.trim(), isNotEmpty, reason: '$language/$key');
        if (language != 'en') {
          expect(text, isNot(AppStringsManager.getString('en', key)),
              reason: '$language/$key');
        }
        if (key == 'network_publish_error_code') {
          expect('{code}'.allMatches(text), hasLength(1), reason: language);
        }
      }
    }
  });
}
