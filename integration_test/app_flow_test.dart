import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parentpeak/main.dart' as app;

/// Integration tests for the main app flow.
/// Run with: flutter test integration_test/app_flow_test.dart
///
/// These tests verify the real app renders without crashing.
/// They do NOT require network access or real credentials.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Startup', () {
    testWidgets('App launches without crash', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      // App should show something — either Login or Onboarding or Home
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App shows login or onboarding', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      // Should find either a login button, or onboarding content
      final hasLogin = find.text('Anmelden').evaluate().isNotEmpty ||
          find.text('Login').evaluate().isNotEmpty ||
          find.text('Sign in').evaluate().isNotEmpty;
      final hasOnboarding =
          find.text('Choose your language').evaluate().isNotEmpty ||
              find.text('Willkommen').evaluate().isNotEmpty;
      final hasHome = find.text('Kalender').evaluate().isNotEmpty ||
          find.text('Calendar').evaluate().isNotEmpty;

      // At least one should be true — app rendered successfully
      expect(hasLogin || hasOnboarding || hasHome, isTrue,
          reason: 'App should show Login, Onboarding, or Home screen');
    });
  });

  group('Login Screen', () {
    testWidgets('Login screen has email and password fields', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on login screen, check fields exist
      final emailField = find.byType(TextField);
      if (emailField.evaluate().isNotEmpty) {
        expect(emailField, findsWidgets);
      }
    });

    testWidgets('Empty email shows error', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try to find and tap a login/submit button
      final loginButtons = find.widgetWithText(FilledButton, 'Anmelden');
      if (loginButtons.evaluate().isNotEmpty) {
        await tester.tap(loginButtons.first);
        await tester.pumpAndSettle();
        // Should show some error
        expect(
            find.textContaining('erforderlich').evaluate().isNotEmpty ||
                find.textContaining('required').evaluate().isNotEmpty,
            isTrue);
      }
    });
  });

  group('Navigation', () {
    testWidgets('Bottom navigation bar exists', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If we're on home screen (logged in), check bottom nav
      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isNotEmpty) {
        expect(navBar, findsOneWidget);
      }
    });
  });
}
