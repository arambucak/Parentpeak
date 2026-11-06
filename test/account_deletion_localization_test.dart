import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/widgets/account_deletion_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const words = {
    'de': 'LÖSCHEN',
    'en': 'DELETE',
    'tr': 'SİL',
    'ku': 'JÊBIBE',
    'fr': 'SUPPRIMER',
    'es': 'ELIMINAR',
    'it': 'ELIMINA',
    'ar': 'حذف',
  };
  String text(String language, String key) =>
      AppStringsManager.getString(language, key);

  for (final entry in words.entries) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('${entry.key}: localized deletion confirmation at $scale',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.runAsync(() => languageService.setLanguage(entry.key));
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: words.keys.map(Locale.new),
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) =>
                            DeleteAccountSheet(theme: Theme.of(context)),
                      ),
                      child: const Text('Open'),
                    ),
                  )),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        expect(field, findsOneWidget);
        expect(find.text(text(entry.key, 'delete_account')), findsOneWidget);
        expect(
            tester.widget<TextField>(field).decoration!.hintText, entry.value);
        expect(find.text(text(entry.key, 'delete_account_permanent_warning')),
            findsOneWidget);
        expect(
            find.text(text(entry.key, 'delete_confirmation_prompt')
                .replaceAll('{word}', entry.value)),
            findsOneWidget);
        if (entry.key != 'de') {
          expect(find.textContaining('Alle deine Daten'), findsNothing);
          expect(find.text('LÖSCHEN'), findsNothing);
        }
        expect(Directionality.of(tester.element(field)),
            entry.key == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        final button = find.widgetWithText(
            FilledButton, text(entry.key, 'profile_delete_final'));
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.enterText(field, entry.value.substring(0, 1));
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.enterText(field, 'wrong');
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.enterText(field, ' ${entry.value} ');
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        await tester.enterText(
            field, entry.key == 'tr' ? 'sil' : entry.value.toLowerCase());
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        if (entry.key != 'de') {
          await tester.enterText(field, 'LÖSCHEN');
          await tester.pump();
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
        }
        expect(tester.takeException(), isNull);
        if (scale == 1.5) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          await tester.ensureVisible(field);
          expect(tester.takeException(), isNull);
        }
        final cancel =
            find.widgetWithText(OutlinedButton, text(entry.key, 'cancel'));
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(field, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
    for (final provider in ['password', 'google.com', 'apple.com']) {
      testWidgets('${entry.key}: localized $provider deletion reauthentication',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: words.keys.map(Locale.new),
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<Object>(
                  context: context,
                  builder: (context) => provider == 'password'
                      ? DeleteAccountPasswordDialog(theme: Theme.of(context))
                      : DeleteAccountProviderDialog(
                          theme: Theme.of(context), providerId: provider),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text(text(entry.key, 'profile_confirm_login')),
            findsOneWidget);
        if (provider == 'password') {
          expect(find.text(text(entry.key, 'delete_reauth_password_body')),
              findsOneWidget);
          expect(find.text(text(entry.key, 'auth_password_label')),
              findsOneWidget);
          expect(tester.widget<TextField>(find.byType(TextField)).obscureText,
              true);
        } else {
          final name = provider == 'google.com' ? 'Google' : 'Apple';
          expect(
              find.text(text(entry.key, 'delete_reauth_provider_body')
                  .replaceAll('{provider}', name)),
              findsOneWidget);
          expect(find.byType(TextField), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester
            .tap(find.widgetWithText(TextButton, text(entry.key, 'cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    }
  }

  test('deletion errors map to translated keys, never provider messages', () {
    const codes = {
      'wrong-password': 'delete_error_password',
      'invalid-credential': 'delete_error_password',
      'network-request-failed': 'delete_error_network',
      'too-many-requests': 'delete_error_throttled',
      'requires-recent-login': 'delete_error_session',
      'user-token-expired': 'delete_error_session',
      'invalid-user-token': 'delete_error_session',
      'user-disabled': 'delete_error_session',
      'user-not-found': 'delete_error_session',
      'unexpected': 'delete_error_failed',
    };
    for (final error in codes.entries) {
      expect(AuthService.deletionErrorKey(error.key), error.value);
    }
    for (final language in words.keys) {
      for (final key in [
        ...codes.values,
        'delete_error_server',
        'delete_reauth_password_body',
        'delete_reauth_provider_body',
        'auth_password_label',
        'delete_account_data_list',
        'delete_account_family_data',
        'delete_account_emergency_data',
        'delete_account_settings_data',
        'delete_account_area_data',
      ]) {
        expect(text(language, key), isNot(key));
        expect(text(language, key), isNotEmpty);
      }
    }
  });
}
