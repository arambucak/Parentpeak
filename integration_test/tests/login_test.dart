import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parentpeak/main.dart' as app;
import '../pages/login_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login Integration Tests', () {
    late LoginPage loginPage;

    setUp(() async {
      final page = LoginPage(null as dynamic);
      await page.clearSession();
    });

    testWidgets('Basarili login - gecerli credentials', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      loginPage = LoginPage(tester);

      await loginPage.login('fatihbucak56@gmail.com', 'Fth.951753');
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(loginPage.isErrorVisible(), isFalse);
    });

    testWidgets('Email bos - hata gosterir', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      loginPage = LoginPage(tester);

      await loginPage.tapLogin();
      await tester.pump();

      expect(find.text('E-Mail ist erforderlich.'), findsOneWidget);
    });

    testWidgets('Sifre bos - hata gosterir', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      loginPage = LoginPage(tester);

      await loginPage.enterEmail('fatihbucak56@gmail.com');
      await loginPage.tapLogin();
      await tester.pump();

      expect(find.text('Passwort ist erforderlich.'), findsOneWidget);
    });

    testWidgets('Gecersiz email - hata gosterir', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      loginPage = LoginPage(tester);

      await loginPage.enterEmail('gecersiz-email');
      await loginPage.tapLogin();
      await tester.pump();

      expect(find.text('Bitte gib eine gültige E-Mail-Adresse ein.'),
          findsOneWidget);
    });

    testWidgets('Yanlis sifre - hata gosterir', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      loginPage = LoginPage(tester);

      await loginPage.login('fatihbucak56@gmail.com', 'yanlis_sifre');
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(loginPage.isErrorVisible(), isTrue);
    });
  });
}
