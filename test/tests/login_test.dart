import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import '../pages/login_page.dart';

Widget localizedTestApp(Widget child) => MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppLanguages.materialLocalizationsDelegate,
        AppLanguages.widgetsLocalizationsDelegate,
        AppLanguages.cupertinoLocalizationsDelegate,
        AppLocalizations.delegate,
      ],
      home: child,
    );

String translatedLoginText(WidgetTester tester, String key) {
  final context = tester.element(find.byType(LoginScreen));
  return context.tr(key);
}

void main() {
  group('Anmeldung', () {
    late LoginPage loginPage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // Benötigt echtes Firebase und läuft deshalb nur als Integrationstest.
    testWidgets(
      'Erfolgreiche Anmeldung mit gültigen Zugangsdaten',
      skip: true,
      (tester) async {
        await tester.pumpWidget(localizedTestApp(const LoginScreen()));
        await tester.pumpAndSettle();
        loginPage = LoginPage(tester);

        await loginPage.login('fatihbucak56@gmail.com', 'Fth.951753');
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Bei erfolgreicher Anmeldung darf keine Fehlermeldung erscheinen.
        expect(loginPage.isErrorVisible(), isFalse);
      },
    );

    testWidgets('Leere E-Mail-Adresse zeigt Fehlermeldung', (tester) async {
      await tester.pumpWidget(localizedTestApp(const LoginScreen()));
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.tapLogin();
      await tester.pumpAndSettle();

      expect(
        find.text(translatedLoginText(tester, 'auth_email_required')),
        findsOneWidget,
      );
    });

    testWidgets('Leeres Passwort zeigt Fehlermeldung', (tester) async {
      await tester.pumpWidget(localizedTestApp(const LoginScreen()));
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.enterEmail('fatihbucak56@gmail.com');
      await loginPage.tapLogin();
      await tester.pumpAndSettle();

      expect(
        find.text(translatedLoginText(tester, 'auth_password_required')),
        findsOneWidget,
      );
    });

    testWidgets('Ungültige E-Mail-Adresse zeigt Fehlermeldung', (tester) async {
      await tester.pumpWidget(localizedTestApp(const LoginScreen()));
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.enterEmail('gecersiz-email');
      await loginPage.tapLogin();
      await tester.pumpAndSettle();

      expect(
        find.text(translatedLoginText(tester, 'auth_email_invalid')),
        findsOneWidget,
      );
    });

    testWidgets('Falsches Passwort - zeigt Fehlermeldung', (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          LoginScreen(
            login: ({required email, required password}) async {
              expect(email, 'fatihbucak56@gmail.com');
              expect(password, 'yanlis_sifre');
              return AuthResult.fail(
                AuthErrorCode.wrongPassword,
                'E-Mail oder Passwort ist nicht korrekt.',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.login('fatihbucak56@gmail.com', 'yanlis_sifre');

      expect(
        find.text('E-Mail oder Passwort ist nicht korrekt.'),
        findsOneWidget,
      );
    });
  });
}
