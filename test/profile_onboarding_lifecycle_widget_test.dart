import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/onboarding_sync_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/onboarding/onboarding_screen.dart';
import 'package:parentpeak/ui/profile_safety_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late String? uid;
  late ProfileAccountStore store;
  String text(String key) => AppStringsManager.getString('en', key);
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'profile.children': ['Hidden legacy|6'],
      ProfileAccountStore.storageKey: jsonEncode({
        'version': 1,
        'legacyOwners': {},
        'accounts': {
          for (final owner in ['a', 'b']) 'account.$owner': {
            'owner': 'account.$owner',
            'data': {'profile.children': ['$owner child|4']},
          },
        },
      }),
    });
    await languageService.setLanguage('en');
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());

  void switchTo(String? next) {
    uid = next;
    store.synchronize();
  }

  Future<void> profile(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileSafetyScreen(
      devices: const [], onRevoke: (_, __) async => true, accountStore: store,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> openChild(WidgetTester tester) async {
    final add = find.text(text('kind_hinzufuegen'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dialog child');
  }

  testWidgets('profile hides legacy, reloads B and rejects A dialog result', (tester) async {
    await profile(tester);
    expect(find.text('a child'), findsOneWidget);
    expect(find.text('Hidden legacy'), findsNothing);
    await openChild(tester);
    switchTo('b');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, text('kind_hinzufuegen')));
    await tester.pumpAndSettle();
    expect(find.text('a child'), findsNothing);
    expect(find.text('b child'), findsOneWidget);
    expect((await store.read(store.ticket))[ProfileAccountStore.childrenKey],
        ['b child|4']);
  });

  testWidgets('new A session rejects old dialog; current dialog persists only A', (tester) async {
    await profile(tester);
    await openChild(tester);
    switchTo(null);
    switchTo('a');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, text('kind_hinzufuegen')));
    await tester.pumpAndSettle();
    expect(find.text('Dialog child'), findsNothing);
    await openChild(tester);
    await tester.tap(find.widgetWithText(FilledButton, text('kind_hinzufuegen')));
    await tester.pumpAndSettle();
    expect(find.text('Dialog child'), findsOneWidget);
    expect((await store.read(store.ticket))[ProfileAccountStore.childrenKey],
        ['a child|4', 'Dialog child|']);
    switchTo('b');
    await tester.pumpAndSettle();
    expect(find.text('Dialog child'), findsNothing);
  });

  testWidgets('wizard discards completion after account changes in location dialog', (tester) async {
    var completions = 0;
    await tester.pumpWidget(MaterialApp(home: OnboardingScreen(
      accountStore: store, onComplete: () => completions++,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text('location_onboarding_skip')));
    await tester.pump(const Duration(milliseconds: 300));
    switchTo('b');
    await tester.tap(find.text(text('location_onboarding_skip')).last);
    await tester.pumpAndSettle();
    expect(completions, 0);
    expect((await store.read(store.ticket))[ProfileAccountStore.completedKey], isNull);
  });

  testWidgets('wizard surfaces failed persistence and retry permits another save', (tester) async {
    store.dispose();
    uid = null;
    var fail = true;
    store = ProfileAccountStore(userIdProvider: () => uid,
      persist: (key, value) async {
        if (fail) return false;
        return (await SharedPreferences.getInstance()).setString(key, value);
      });
    var completions = 0;
    await tester.pumpWidget(MaterialApp(home: OnboardingScreen(
      accountStore: store, onComplete: () => completions++,
    )));
    await tester.pumpAndSettle();
    for (final attempt in [0, 1]) {
      await tester.tap(find.text(text('location_onboarding_skip')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(text('location_onboarding_skip')).last);
      await tester.pumpAndSettle();
      if (attempt == 0) {
        expect(completions, 0);
        expect(find.text(text('profile_account_failed')), findsOneWidget);
        fail = false;
        await tester.tap(find.text(text('profile_account_failed')));
        await tester.pumpAndSettle();
      }
    }
    expect(completions, 1);
    expect((await store.read(store.ticket))[ProfileAccountStore.completedKey], true);
  });

  testWidgets('AuthGate waits, surfaces sync error and retries into owner wizard', (tester) async {
    await AuthService.instance.debugSeedSessionForTesting();
    final response = Completer<http.Response>();
    var calls = 0;
    final sync = OnboardingSyncService(store: store, api: BackendApiClient(
      baseUrl: 'https://backend.example', authToken: 'test',
      httpClient: MockClient((_) {
        calls++;
        return calls == 1 ? response.future
            : Future.value(http.Response('{"completed":false}', 200));
      }),
    ));
    await tester.pumpWidget(MaterialApp(home: AuthGate(
      devices: const [], onRevoke: (_, __) async => true,
      accountStore: store, onboardingSync: sync,
    )));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    response.complete(http.Response('{}', 503));
    await tester.pumpAndSettle();
    expect(find.text(text('profile_account_failed')), findsOneWidget);
    await tester.tap(find.text(text('profile_account_retry')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('AuthGate ignores A completion arriving after B wizard check', (tester) async {
    await AuthService.instance.debugSeedSessionForTesting();
    final response = Completer<http.Response>();
    final sync = OnboardingSyncService(store: store, api: BackendApiClient(
      baseUrl: 'https://backend.example', authToken: 'test',
      httpClient: MockClient((req) => req.url.path.endsWith('/a')
        ? response.future : Future.value(http.Response('{"completed":false}', 200))),
    ));
    await tester.pumpWidget(MaterialApp(home: AuthGate(
      devices: const [], onRevoke: (_, __) async => true,
      accountStore: store, onboardingSync: sync,
    )));
    await tester.pump();
    switchTo('b');
    await tester.pumpAndSettle();
    response.complete(http.Response('{"completed":true}', 200));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect((await store.read(store.ticket))[ProfileAccountStore.completedKey], isNull);
  });
}
