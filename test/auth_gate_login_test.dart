import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import 'package:parentpeak/ui/home_screen.dart';
import 'package:parentpeak/ui/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AuthGate requires login when currentUser is null',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
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
