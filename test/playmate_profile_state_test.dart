import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/widgets/playmate_profile_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilyMatchProfile draft(String name) => FamilyMatchProfile(
  displayName: name,
  district: 'Berlin',
  children: [ChildEntry(name: 'Local child', birthDate: DateTime(2022, 5, 2))],
  languages: ['de'],
  familyForm: 'kernfamilie',
  values: ['gfk'],
  lookingFor: ['spielplatz'],
  specials: ['allergien'],
  createdAt: DateTime(2024, 1, 1),
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

  test(
    'account storage isolates owners and preserves unassigned data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final old = jsonEncode(draft('Legacy').toJson());
      await prefs.setString('spielfreunde.profile', old);
      expect(await FamilyMatchProfile.load(userId: 'a'), isNull);
      expect(await FamilyMatchProfile.load(userId: 'b'), isNull);
      await draft('A').save(userId: 'a');
      await draft('B').save(userId: 'b');
      expect((await FamilyMatchProfile.load(userId: 'a'))!.displayName, 'A');
      expect((await FamilyMatchProfile.load(userId: 'b'))!.displayName, 'B');
      expect(prefs.getString('spielfreunde.profile'), old);
      await FamilyMatchProfile.removeForAccount('a');
      expect(await FamilyMatchProfile.load(userId: 'a'), isNull);
      expect((await FamilyMatchProfile.load(userId: 'b'))!.displayName, 'B');
      expect(prefs.getString('spielfreunde.profile'), old);
    },
  );

  test(
    'all default feature readers use the current session, never legacy',
    () async {
      await AuthService.instance.debugSeedSessionForTesting();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'spielfreunde.profile',
        jsonEncode(draft('Legacy').toJson()),
      );
      await draft('Other').save(userId: 'other');
      expect(await FamilyMatchProfile.load(), isNull);
      await draft('Current').save(userId: 'debug_demo_user');
      expect((await FamilyMatchProfile.load())!.displayName, 'Current');
      final auth = AuthService.instance;
      final previousFactory = AuthService.backendApiClientFactory;
      AuthService.backendApiClientFactory = () => null;
      try {
        await auth.logout();
        expect(await FamilyMatchProfile.load(), isNull);
      } finally {
        AuthService.backendApiClientFactory = previousFactory;
      }
      await AuthService.instance.debugSeedSessionForTesting();
      expect((await FamilyMatchProfile.load())!.displayName, 'Current');
    },
  );

  test(
    'explicit adoption moves the exact draft locally without any HTTP',
    () async {
      final old = draft('Legacy');
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(old.toJson());
      await prefs.setString('spielfreunde.profile', raw);
      var calls = 0;
      final profiles = service(
        MockClient((_) async {
          calls++;
          throw StateError('adoption must not upload or fetch');
        }),
      );
      expect(
        await profiles.adoptUnassignedDraft(
          'owner',
          confirmOwnership: () async => false,
        ),
        isFalse,
      );
      expect(prefs.getString('spielfreunde.profile'), raw);
      expect(await FamilyMatchProfile.load(userId: 'owner'), isNull);
      final consent = Completer<bool>();
      final assigning = profiles.adoptUnassignedDraft(
        'owner',
        confirmOwnership: () => consent.future,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await FamilyMatchProfile.load(userId: 'owner'), isNull);
      consent.complete(true);
      expect(await assigning, isTrue);
      expect(
        (await FamilyMatchProfile.load(userId: 'owner'))!.toJson(),
        old.toJson(),
      );
      expect(prefs.containsKey('spielfreunde.profile'), isFalse);
      expect(await FamilyMatchProfile.load(userId: 'other'), isNull);
      expect(calls, 0);
    },
  );

  test('adoption never overwrites an account profile', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'spielfreunde.profile',
      jsonEncode(draft('Legacy').toJson()),
    );
    await draft('Existing').save(userId: 'owner');
    final profiles = service(MockClient((_) async => http.Response('{}', 500)));
    await expectLater(
      profiles.adoptUnassignedDraft(
        'owner',
        confirmOwnership: () async => true,
      ),
      throwsStateError,
    );
    expect(
      (await FamilyMatchProfile.load(userId: 'owner'))!.displayName,
      'Existing',
    );
    expect(prefs.containsKey('spielfreunde.profile'), isTrue);
  });

  test('concurrent adoption cannot assign one draft to two accounts', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'spielfreunde.profile',
      jsonEncode(draft('Legacy').toJson()),
    );
    final profiles = service(MockClient((_) async => http.Response('{}', 500)));
    final consent = Completer<bool>();
    final opened = Completer<void>();
    final first = profiles.adoptUnassignedDraft(
      'a',
      confirmOwnership: () {
        opened.complete();
        return consent.future;
      },
    );
    await opened.future;
    await expectLater(
      profiles.adoptUnassignedDraft('b', confirmOwnership: () async => true),
      throwsStateError,
    );
    consent.complete(true);
    expect(await first, isTrue);
    expect(await FamilyMatchProfile.load(userId: 'b'), isNull);
    expect((await FamilyMatchProfile.load(userId: 'a'))!.displayName, 'Legacy');
  });

  test('corrupt or mismatched account envelope is not exposed', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      FamilyMatchProfile.storageKey('owner'),
      jsonEncode({'ownerUserId': 'other', 'profile': draft('Other').toJson()}),
    );
    expect(await FamilyMatchProfile.load(userId: 'owner'), isNull);
    await expectLater(
      FamilyMatchProfile.load(userId: 'owner', throwOnError: true),
      throwsFormatException,
    );
    expect(() => FamilyMatchProfile.storageKey(''), throwsArgumentError);
  });

  test('server-confirmed active status uses authenticated owner GET', () async {
    await draft('Owner').save(userId: 'owner&extra=value');
    final profiles = service(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['userId'], 'owner&extra=value');
        expect(request.headers.containsKey('Authorization'), isTrue);
        return http.Response(
          jsonEncode({
            'item': {'id': 'p', 'ownerUserId': 'owner&extra=value'},
          }),
          200,
        );
      }),
    );
    final state = await profiles.loadState('owner&extra=value');
    expect(state.status, PlaymateProfileStatus.active);
    expect(state.profile!.displayName, 'Owner');
    expect(state.hasUnassignedDraft, isFalse);
  });

  test(
    '404 leaves a local draft unpublished and preserves unassigned data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'spielfreunde.profile',
        jsonEncode(draft('Legacy').toJson()),
      );
      final profiles = service(
        MockClient((_) async => http.Response('{}', 404)),
      );
      final unassigned = await profiles.loadState('owner');
      expect(unassigned.status, PlaymateProfileStatus.draft);
      expect(unassigned.hasUnassignedDraft, isTrue);
      expect(unassigned.profile, isNull);
      await draft('Assigned').save(userId: 'owner');
      final local = await profiles.loadState('owner');
      expect(local.status, PlaymateProfileStatus.draft);
      expect(local.profile!.displayName, 'Assigned');
      expect(prefs.containsKey('spielfreunde.profile'), isTrue);
    },
  );

  test(
    'server, auth, transport and malformed errors never mean active or absent',
    () async {
      await draft('Owner').save(userId: 'owner');
      for (final response in [
        http.Response('{}', 401),
        http.Response('{}', 403),
        http.Response('{}', 503),
        http.Response('{}', 200),
        http.Response('not json', 200),
        http.Response('{"item":{"id":"p","ownerUserId":"other"}}', 200),
        http.Response('{"item":{"id":"","ownerUserId":"owner"}}', 200),
      ]) {
        final profiles = service(MockClient((_) async => response));
        expect(
          (await profiles.loadState('owner')).status,
          PlaymateProfileStatus.unavailable,
        );
        expect(profiles.matchingService.lastSyncError, isNotNull);
      }
      final offline = service(
        MockClient((_) async {
          throw http.ClientException('offline 404 in unrelated error text');
        }),
      );
      expect(
        (await offline.loadState('owner')).status,
        PlaymateProfileStatus.unavailable,
      );
      expect(
        (await FamilyMatchProfile.load(userId: 'owner'))!.displayName,
        'Owner',
      );
    },
  );

  test('retry can confirm active status after a failed verification', () async {
    var attempts = 0;
    final profiles = service(
      MockClient((_) async {
        attempts++;
        return attempts == 1
            ? http.Response('{}', 503)
            : http.Response('{"item":{"id":"p","ownerUserId":"owner"}}', 200);
      }),
    );
    expect(
      (await profiles.loadState('owner')).status,
      PlaymateProfileStatus.unavailable,
    );
    expect(
      (await profiles.loadState('owner')).status,
      PlaymateProfileStatus.active,
    );
    expect(profiles.matchingService.lastSyncError, isNull);
  });

  testWidgets('unverified panel shows retry and never claims activity', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: PlaymateProfileStatusPanel(
            status: PlaymateProfileStatus.unavailable,
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.tap(
      find.text(AppStringsManager.getString('en', 'network_profile_retry')),
    );
    expect(retried, isTrue);
    expect(
      find.text(AppStringsManager.getString('en', 'network_profile_active')),
      findsNothing,
    );
    expect(
      find.text(
        AppStringsManager.getString('en', 'network_profile_unverified'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'ownership dialog is explicit, cancellable and account-specific',
    (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await confirmPlaymateDraftOwnership(
                    context,
                    'Current account',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Current account'), findsOneWidget);
      await tester.tap(find.text(AppStringsManager.getString('en', 'cancel')));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppStringsManager.getString('en', 'network_draft_assign')),
      );
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
    },
  );
}
