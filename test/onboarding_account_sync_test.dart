import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/onboarding_sync_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
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
  OnboardingSyncService service(
    Future<http.Response> Function(http.Request) handler,
  ) => OnboardingSyncService(
    store: store,
    api: BackendApiClient(
      baseUrl: 'https://backend.example',
      authToken: 'test',
      httpClient: MockClient(handler),
    ),
  );

  test(
    'owner pull writes only that owner; false is not a network failure',
    () async {
      final api = service((req) async {
        expect(req.url.path, '/api/onboarding/a');
        return http.Response(
          jsonEncode({
            'completed': true,
            'familyName': 'Own',
            'parentRole': 'baby',
            'priorities': ['tips'],
          }),
          200,
        );
      });
      expect(await api.pullCompleted(store.ticket), true);
      expect(
        (await store.read(store.ticket))[ProfileAccountStore.familyNameKey],
        'Own',
      );
      uid = 'b';
      store.synchronize();
      expect(await store.read(store.ticket), isEmpty);
      final incomplete = service(
        (_) async => http.Response('{"completed":false}', 200),
      );
      expect(await incomplete.pullCompleted(store.ticket), false);
      expect(await store.read(store.ticket), isEmpty);
      for (final status in [401, 403, 503]) {
        await expectLater(
          service(
            (_) async => http.Response('{}', status),
          ).pullCompleted(store.ticket),
          throwsException,
        );
      }
    },
  );

  test('A pull cannot write after A logout A or switch to B', () async {
    for (final next in ['a', 'b']) {
      uid = 'a';
      store.synchronize();
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      final pull = service((_) {
        started.complete();
        return gate.future;
      }).pullCompleted(store.ticket);
      await started.future;
      uid = null;
      store.synchronize();
      uid = next;
      store.synchronize();
      gate.complete(
        http.Response(
          jsonEncode({
            'completed': true,
            'familyName': 'Old A',
            'parentRole': 'baby',
            'priorities': [],
          }),
          200,
        ),
      );
      await expectLater(pull, throwsA(isA<ProfileAccountChanged>()));
      expect(await store.read(store.ticket), isEmpty);
    }
  });

  test(
    'minimal push excludes children, ages, region, coordinates and other owners',
    () async {
      await store.write(store.ticket, {
        ProfileAccountStore.completedKey: true,
        ProfileAccountStore.familyNameKey: 'Own',
        ProfileAccountStore.childrenKey: ['Local|4'],
        ProfileAccountStore.agesKey: ['baby'],
        ProfileAccountStore.rolesKey: ['baby'],
        ProfileAccountStore.latitudeKey: 50.0,
      });
      await service((req) async {
        final body = jsonDecode(req.body) as Map;
        expect(body.keys.toSet(), {
          'userId',
          'completed',
          'familyName',
          'parentRole',
          'priorities',
        });
        expect(body['userId'], 'a');
        expect(req.headers['Authorization'], isNotNull);
        return http.Response('{"ok":true}', 200);
      }).pushCompleted(store.ticket);
      await expectLater(
        service(
          (_) async => http.Response('{"ok":false}', 200),
        ).pushCompleted(store.ticket),
        throwsStateError,
      );
    },
  );
}
