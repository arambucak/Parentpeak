import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      FamilyMatchProfile.storageKey('owner'): 'keep-me',
      'spielfreunde.profile': 'unassigned-draft',
    });
  });

  PlaymateProfileService service(http.Client client) => PlaymateProfileService(
    matchingService: ParentMatchingBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authToken: 'test-token',
        httpClient: client,
      ),
    ),
  );

  test(
    'deletion uses matching endpoint, authentication and explicit ack',
    () async {
      final response = Completer<http.Response>();
      final sent = Completer<void>();
      final profiles = service(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/parent-matching/my-profile');
          expect(request.url.queryParameters['userId'], 'owner&name=test');
          expect(request.headers['Authorization'], 'Bearer test-token');
          sent.complete();
          return response.future;
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(FamilyMatchProfile.storageKey('owner&name=test'), 'keep-me');
      final deleting = profiles.deleteProfile('owner&name=test');
      await sent.future;
      expect(prefs.getString(FamilyMatchProfile.storageKey('owner&name=test')), 'keep-me');
      response.complete(http.Response(jsonEncode({'success': true}), 200));
      expect(await deleting, isTrue);
      expect(prefs.containsKey(FamilyMatchProfile.storageKey('owner&name=test')), isFalse);
      expect(prefs.getString('spielfreunde.profile'), 'unassigned-draft');
      expect(prefs.getString(FamilyMatchProfile.storageKey('owner')), 'keep-me');
    },
  );

  test('server rejection or missing ack preserves local profile', () async {
    for (final response in [
      http.Response('{"error":"unavailable"}', 503),
      http.Response('{"error":"unauthorized"}', 401),
      http.Response('{"success":false}', 200),
      http.Response('{}', 200),
      http.Response('', 204),
    ]) {
      final profiles = service(MockClient((_) async => response));
      expect(await profiles.deleteProfile('owner'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FamilyMatchProfile.storageKey('owner')), 'keep-me');
      expect(profiles.matchingService.lastSyncError, isNotNull);
    }
  });

  test('transport failure preserves local profile', () async {
    final profiles = service(
      MockClient((_) async {
        throw http.ClientException('offline');
      }),
    );
    expect(await profiles.deleteProfile('owner'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(FamilyMatchProfile.storageKey('owner')), 'keep-me');
  });

  test(
    'missing authenticated backend or user never erases local profile',
    () async {
      final profiles = PlaymateProfileService(
        matchingService: ParentMatchingBackendService(),
      );
      expect(await profiles.deleteProfile('owner'), isFalse);
      var calls = 0;
      final withBackend = service(
        MockClient((_) async {
          calls++;
          return http.Response('{"success":true}', 200);
        }),
      );
      expect(await withBackend.deleteProfile(''), isFalse);
      expect(calls, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FamilyMatchProfile.storageKey('owner')), 'keep-me');
    },
  );

  test('delete failure copy exists in all four audit languages', () {
    for (final language in ['de', 'en', 'tr', 'ku']) {
      final text = AppStringsManager.getString(
        language,
        'network_delete_failed',
      );
      expect(text, isNot('network_delete_failed'));
      expect(text, isNotEmpty);
    }
  });
}
