import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/access_config.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/onboarding_sync_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import 'package:parentpeak/ui/auth/paywall_screen.dart';
import 'package:parentpeak/ui/home_screen.dart';
import 'package:parentpeak/ui/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'expired non-Premium account can enter Free onboarding without a paywall',
      (tester) async {
    final previousFactory = AuthService.backendApiClientFactory;
    final previousFirebaseFlag = AuthService.disableFirebaseInitForTesting;
    AuthService.backendApiClientFactory = () => null;
    AuthService.disableFirebaseInitForTesting = true;
    addTearDown(() {
      AuthService.backendApiClientFactory = previousFactory;
      AuthService.disableFirebaseInitForTesting = previousFirebaseFlag;
    });
    SharedPreferences.setMockInitialValues({
      'pp_current_user': jsonEncode({
        'uid': 'expired-free',
        'email': 'free@example.test',
        'displayName': 'Free Parent',
        'registeredAt':
            DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
        'isPremium': false,
        'serverHasFullAccess': false,
        'serverTrialDaysRemaining': 0,
      }),
    });
    await tester.runAsync(() => AuthService.instance.initialize());
    expect(AuthService.instance.currentUser!.isPremium, false);
    if (!AccessConfig.isBetaFreeAccess) {
      expect(AuthService.instance.currentUser!.hasFullAccess, false);
    }
    final accounts = ProfileAccountStore(userIdProvider: () => 'expired-free');
    addTearDown(accounts.dispose);
    final sync = OnboardingSyncService(
        store: accounts,
        api: BackendApiClient(
            baseUrl: 'https://quota.example.test',
            httpClient: MockClient(
                (_) async => http.Response('{"completed":false}', 200))));
    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
          devices: const [],
          onRevoke: (_, __) async => true,
          accountStore: accounts,
          onboardingSync: sync),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(PaywallScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => AuthService.instance.logout());
  });

  testWidgets('AuthGate requires login when currentUser is null',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => AuthService.instance.logout());
    expect(AuthService.instance.currentUser, isNull);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppLanguages.materialLocalizationsDelegate,
        AppLanguages.widgetsLocalizationsDelegate,
        AppLanguages.cupertinoLocalizationsDelegate,
        AppLocalizations.delegate,
      ],
      home: AuthGate(
        devices: const [],
        onRevoke: (_, __) async => true,
      ),
    ));

    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ParentpeakAppShell), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ParentpeakAppShell), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
