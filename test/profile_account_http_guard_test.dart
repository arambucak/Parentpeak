import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/onboarding_sync_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ProfileAccountStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());
  void newSession() {
    uid = null; store.synchronize();
    uid = 'a'; store.synchronize();
  }

  for (final operation in ['pull', 'push', 'name', 'visibility', 'avatar']) {
    test('$operation sends no HTTP after session changes during token resolution', () async {
      await store.write(store.ticket, {ProfileAccountStore.completedKey: true});
      final token = Completer<String?>();
      final started = Completer<void>();
      var requests = 0;
      final api = BackendApiClient(
        baseUrl: 'https://backend.example',
        authTokenProvider: () { started.complete(); return token.future; },
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{"ok":true}', 200);
        }),
      );
      final onboarding = OnboardingSyncService(api: api, store: store);
      final profile = UserProfileService(api: api, store: store,
          userIdProvider: () => uid);
      final Future<dynamic> result = switch (operation) {
        'pull' => onboarding.pullCompleted(store.ticket),
        'push' => onboarding.pushCompleted(store.ticket),
        'name' => profile.setDisplayName('Own name'),
        'visibility' => profile.setVisibility(searchable: true),
        _ => profile.setAvatarUrl('https://images.example/own.png'),
      };
      final checked = operation == 'avatar'
          ? expectLater(result, completion(false))
          : expectLater(result, throwsA(isA<ProfileAccountChanged>()));
      await started.future;
      newSession();
      token.complete('new-session-token');
      await checked;
      expect(requests, 0);
    });
  }

  for (final push in [false, true]) {
    test('onboarding ${push ? "push" : "pull"} prevents 401 retry after account switch', () async {
      await store.write(store.ticket, {ProfileAccountStore.completedKey: true});
      final refreshing = Completer<void>();
      final token = Completer<String?>();
      var requests = 0;
      final api = BackendApiClient(baseUrl: 'https://backend.example',
        authToken: 'old-token',
        forceRefreshTokenProvider: () {
          refreshing.complete();
          return token.future;
        },
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 401);
        }),
      );
      final service = OnboardingSyncService(api: api, store: store);
      final result = push ? service.pushCompleted(store.ticket)
          : service.pullCompleted(store.ticket);
      final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
      await refreshing.future;
      uid = 'b'; store.synchronize();
      token.complete('b-token');
      await checked;
      expect(requests, 1);
      expect(await store.read(store.ticket), isEmpty);
    });
  }

  test('public profile identity reads remain available for another UID', () async {
    final profile = UserProfileService(store: store, userIdProvider: () => uid,
      api: BackendApiClient(baseUrl: 'https://backend.example',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/profile/b');
          return http.Response(
            '{"exists":true,"displayName":"Public B","avatarUrl":"https://images.example/b.png"}',
            200);
        }),
      ));
    expect(await profile.displayNameFor('b'), 'Public B');
    expect(await profile.avatarUrlFor('b'), 'https://images.example/b.png');
  });
}
