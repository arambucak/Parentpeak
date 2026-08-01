import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import '../pages/login_page.dart';

void main() {
  group('Login Tests', () {
    late LoginPage loginPage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ✅ POZİTİF TEST — Requires real Firebase; runs only in integration tests
    testWidgets('Basarili login - gecerli credentials',
        skip: true,
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.login('fatihbucak56@gmail.com', 'Fth.951753');
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Hata mesaji gozukmemeli
      expect(loginPage.isErrorVisible(), isFalse);
    });

    // ❌ NEGATİF TESTLER
    testWidgets('Email bos - hata gosterir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.tapLogin();
      await tester.pumpAndSettle();

      expect(find.text('E-Mail ist erforderlich.'), findsOneWidget);
    });

    testWidgets('Sifre bos - hata gosterir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.enterEmail('fatihbucak56@gmail.com');
      await loginPage.tapLogin();
      await tester.pumpAndSettle();

      expect(find.text('Passwort ist erforderlich.'), findsOneWidget);
    });

    testWidgets('Gecersiz email - hata gosterir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.enterEmail('gecersiz-email');
      await loginPage.tapLogin();
      await tester.pumpAndSettle();

      expect(find.text('Bitte gib eine gültige E-Mail-Adresse ein.'),
          findsOneWidget);
    });

    testWidgets('Yanlis sifre - hata gosterir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );
      await tester.pumpAndSettle();
      loginPage = LoginPage(tester);

      await loginPage.login('fatihbucak56@gmail.com', 'yanlis_sifre');
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(loginPage.isErrorVisible(), isTrue);
    });
  });
}
