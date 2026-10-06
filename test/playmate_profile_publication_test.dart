import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/widgets/playmate_publication_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilyMatchProfile profile() => FamilyMatchProfile(
      displayName: 'Test family',
      district: 'Berlin',
      city: 'Berlin',
      latitude: 52.521987,
      longitude: 13.404954,
      children: [
        ChildEntry(
            name: 'Local child',
            ageMonths: 36,
            gender: 'weiblich',
            interests: ['musik'],
            interestsCustom: 'local interest'),
      ],
      languages: ['en'],
      familyForm: 'kernfamilie',
      values: ['gfk'],
      lookingFor: ['spielplatz'],
      specials: ['allergien', 'chronisch_krank'],
      specialsCustom: 'local health note',
      bio: 'Looking for playdates',
      createdAt: DateTime(2026, 10, 6),
    );

PlaymateProfileService service(http.Client client) => PlaymateProfileService(
      matchingService: ParentMatchingBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          authToken: 'test-token',
          httpClient: client,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cancelled or dismissed publication never uploads or saves', () async {
    var calls = 0;
    final profiles = service(MockClient((_) async {
      calls++;
      throw StateError('must not upload');
    }));
    expect(
        await profiles.publishProfile(profile(), 'owner',
            confirmPublication: () async => false),
        PlaymatePublicationResult.cancelled);
    expect(calls, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('spielfreunde.profile'), isFalse);
    expect(prefs.containsKey(FamilyMatchProfile.storageKey('owner')), isFalse);
  });

  test('publishes only the allowed matching fields after explicit consent',
      () async {
    final consent = Completer<bool>();
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    Map<String, dynamic>? uploaded;
    final profiles = service(MockClient((request) async {
      expect(request.url.path, '/parent-matching/my-profile');
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer test-token');
      uploaded = jsonDecode(request.body) as Map<String, dynamic>;
      sent.complete();
      return response.future;
    }));
    final publishing = profiles.publishProfile(profile(), 'owner',
        confirmPublication: () => consent.future);
    await Future<void>.delayed(Duration.zero);
    expect(uploaded, isNull);
    consent.complete(true);
    await sent.future;
    final body = uploaded!;
    expect(body.keys.toSet(), {
      'userId', 'name', 'age', 'city', 'latitude', 'longitude', 'bio',
      'interests', 'languages', 'valuesFocus', 'childAges', 'familyForm',
    });
    expect(body['age'], isNull);
    expect(body['latitude'], 52.52);
    expect(body['longitude'], 13.40);
    expect(body['interests'], ['spielplatz']);
    expect(body['childAges'], [matches(RegExp(r'^\d+J$'))]);
    final raw = jsonEncode(body);
    for (final sensitive in [
      'Local child', 'birthDate', 'allergien', 'chronisch_krank',
      'local health note', 'weiblich', 'local interest',
    ]) {
      expect(raw, isNot(contains(sensitive)), reason: sensitive);
    }
    final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('spielfreunde.profile'), isFalse);
      expect(
        prefs.containsKey(FamilyMatchProfile.storageKey('owner')),
        isFalse,
      );
    response.complete(http.Response(
        jsonEncode({'item': {'id': 'self-owner', 'ownerUserId': 'owner',
          'name': body['name'], 'city': body['city']}}), 201));
    expect(await publishing, PlaymatePublicationResult.published);
      final local = await FamilyMatchProfile.load(userId: 'owner');
    expect(local!.children.first.name, 'Local child');
    expect(local.specials, ['allergien', 'chronisch_krank']);
    expect(local.specialsCustom, 'local health note');
  });

  test('failed or unacknowledged publication preserves an existing local copy',
      () async {
    final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        FamilyMatchProfile.storageKey('owner'),
        'existing-profile',
      );
    for (final response in [
      http.Response('{"error":"unavailable"}', 503),
      http.Response('{}', 201),
      http.Response('{"item":{"name":"Test"}}', 201),
      http.Response('{"item":{"id":"profile","ownerUserId":"other"}}', 201),
    ]) {
      final profiles = service(MockClient((_) async => response));
      expect(
          await profiles.publishProfile(profile(), 'owner',
              confirmPublication: () async => true),
          PlaymatePublicationResult.failed);
        expect(
          prefs.getString(FamilyMatchProfile.storageKey('owner')),
          'existing-profile',
        );
    }
  });

  test('offline publication preserves an unpublished local state', () async {
    final profiles = service(MockClient((_) async {
      throw http.ClientException('offline');
    }));
    expect(
        await profiles.publishProfile(profile(), 'owner',
            confirmPublication: () async => true),
        PlaymatePublicationResult.failed);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('spielfreunde.profile'), isFalse);
    expect(prefs.containsKey(FamilyMatchProfile.storageKey('owner')), isFalse);
  });

  test('all publication and local-only messages exist in de/en/tr/ku', () {
    for (final language in ['de', 'en', 'tr', 'ku']) {
      for (final key in [
        'network_publish_title', 'network_publish_body', 'network_publish_accept',
        'network_publish_failed', 'network_specials_local',
        'network_child_name_local', 'network_specials_hint',
      ]) {
        final text = AppStringsManager.getString(language, key);
        expect(text, isNot(key));
        expect(text, isNotEmpty);
      }
    }
  });

  testWidgets('dialog requires confirmation on every publication', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await confirmPlaymatePublication(context);
          },
          child: const Text('Open'),
        ),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(AppStringsManager.getString('en', 'network_publish_body')),
        findsOneWidget);
    await tester.tap(find.text(AppStringsManager.getString('en', 'cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(
        AppStringsManager.getString('en', 'network_publish_accept')));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    result = null;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
