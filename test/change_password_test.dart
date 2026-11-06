import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/widgets/change_password_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Credential extends Mock implements UserCredential {}

class _Info extends Mock implements UserInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth firebase;
  late _User user;
  late _Info info;
  late AuthService service;
  late List<String> operations;
  const current = 'OldTest123';
  const next = 'NewTest456';

  setUpAll(() => registerFallbackValue(EmailAuthProvider.credential(
      email: 'test@example.test', password: current)));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await languageService.setLanguage('en');
    firebase = _Auth();
    user = _User();
    info = _Info();
    operations = [];
    when(() => firebase.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('a');
    when(() => user.email).thenReturn('test@example.test');
    when(() => user.providerData).thenReturn([info]);
    when(() => info.providerId).thenReturn('password');
    when(() => user.reauthenticateWithCredential(any()))
        .thenAnswer((invocation) async {
      final credential =
          invocation.positionalArguments.single as EmailAuthCredential;
      expect(credential.email, 'test@example.test');
      expect(credential.password, current);
      operations.add('reauth');
      return _Credential();
    });
    when(() => user.updatePassword(any())).thenAnswer((invocation) async {
      expect(invocation.positionalArguments.single, next);
      operations.add('update');
    });
    service = AuthService.withFirebaseForTesting(firebase);
  });
  tearDown(() => service.dispose());

  test('password validation matches registration and does not trim passwords',
      () {
    expect(AuthService.passwordValidationKey('Short1'),
        'register_password_min_length');
    expect(AuthService.passwordValidationKey('lowercase1'),
        'register_password_uppercase');
    expect(AuthService.passwordValidationKey('NoNumbers'),
        'register_password_number');
    expect(AuthService.passwordValidationKey(' Space123 '), null);
  });

  for (final code in [
    'wrong-password', 'invalid-credential', 'network-request-failed',
    'too-many-requests', 'user-disabled', 'unknown',
  ]) {
    test('deletion reauthentication returns localized error key for $code',
        () async {
      when(() => user.reauthenticateWithCredential(any()))
          .thenThrow(FirebaseAuthException(code: code, message: 'Provider text'));
      expect(await service.reauthenticateAndDeleteAccount(current),
          AuthService.deletionErrorKey(code));
      verifyNever(() => user.delete());
    });
  }

  test(
      'reauthentication must succeed before update; success waits for Firebase',
      () async {
    final acknowledged = Completer<void>();
    when(() => user.updatePassword(next))
        .thenAnswer((_) => acknowledged.future);
    var completed = false;
    final pending = service.changePassword(current, next).then((value) {
      completed = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, false);
    acknowledged.complete();
    expect(await pending, null);
    verifyInOrder([
      () => user.reauthenticateWithCredential(any()),
      () => user.updatePassword(next),
    ]);
  });

  test('missing current, invalid next and same password never call Firebase',
      () async {
    expect(await service.changePassword('', next),
        'password_change_current_required');
    expect(await service.changePassword(current, 'short'),
        'register_password_min_length');
    expect(
        await service.changePassword(current, current), 'password_change_same');
    expect(operations, isEmpty);
  });

  for (final provider in ['google.com', 'apple.com', 'phone']) {
    test('$provider accounts do not use password credentials', () async {
      when(() => info.providerId).thenReturn(provider);
      expect(await service.changePassword(current, next),
          'password_change_provider');
      expect(operations, isEmpty);
    });
  }

  test('missing Firebase user is an explicit session error', () async {
    when(() => firebase.currentUser).thenReturn(null);
    expect(
        await service.changePassword(current, next), 'password_change_session');
    expect(operations, isEmpty);
  });

  const errorKeys = {
    'wrong-password': 'password_change_wrong',
    'invalid-credential': 'password_change_wrong',
    'weak-password': 'password_change_weak',
    'password-does-not-meet-requirements': 'password_change_weak',
    'requires-recent-login': 'password_change_recent',
    'network-request-failed': 'password_change_network',
    'too-many-requests': 'password_change_throttled',
    'user-disabled': 'password_change_session',
    'unknown': 'password_change_failed',
  };
  for (final entry in errorKeys.entries) {
    test('maps ${entry.key} without exposing provider messages', () async {
      expect(AuthService.passwordChangeErrorKey(entry.key), entry.value);
      when(() => user.reauthenticateWithCredential(any())).thenThrow(
          FirebaseAuthException(
              code: entry.key, message: 'private provider details'));
      expect(await service.changePassword(current, next), entry.value);
      verifyNever(() => user.updatePassword(any()));
    });
  }

  test('update failure is not reported as success', () async {
    when(() => user.updatePassword(next))
        .thenThrow(FirebaseAuthException(code: 'weak-password'));
    expect(await service.changePassword(current, next), 'password_change_weak');
  });

  test('account switch during reauthentication does not update the old account',
      () async {
    final reply = Completer<UserCredential>();
    when(() => user.reauthenticateWithCredential(any()))
        .thenAnswer((_) => reply.future);
    final pending = service.changePassword(current, next);
    final other = _User();
    when(() => other.uid).thenReturn('b');
    when(() => firebase.currentUser).thenReturn(other);
    reply.complete(_Credential());
    expect(await pending, 'password_change_session');
    verifyNever(() => user.updatePassword(any()));
  });

  test('each error key is translated in all launch languages', () {
    for (final language in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
      for (final key in {
        ...errorKeys.values,
        'password_change_provider',
        'password_change_same',
        'password_change_current_required'
      }) {
        expect(AppStringsManager.allStrings[language]![key], isNotEmpty);
      }
    }
  });

  testWidgets(
      'confirmation mismatch makes no request; acknowledged success closes',
      (tester) async {
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (_) => ChangePasswordDialog(
                              auth: service, accounts: accounts));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        true);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), 'Different123');
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(operations, isEmpty);
    expect(
        find.text(
            AppStringsManager.getString('en', 'register_password_mismatch')),
        findsOneWidget);
    await tester.enterText(fields.at(2), next);
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();
    expect(operations, ['reauth', 'update']);
    expect(result, true);
    expect(find.byType(ChangePasswordDialog), findsNothing);
  });

  testWidgets(
      'busy submission is single-flight and a failure remains retryable',
      (tester) async {
    final accounts = ProfileAccountStore(userIdProvider: () => 'a');
    addTearDown(accounts.dispose);
    final reply = Completer<UserCredential>();
    var attempts = 0;
    when(() => user.reauthenticateWithCredential(any())).thenAnswer((_) {
      attempts++;
      return reply.future;
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChangePasswordDialog(auth: service, accounts: accounts))));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), next);
    await tester.tap(find.text('Save new password'));
    await tester.pump();
    await tester.tap(find.text('Save new password'));
    await tester.pump();
    expect(attempts, 1);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
    reply.completeError(FirebaseAuthException(code: 'wrong-password'));
    await tester.pumpAndSettle();
    expect(
        find.text(AppStringsManager.getString('en', 'password_change_wrong')),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    verifyNever(() => user.updatePassword(any()));
  });

  for (final language in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
    testWidgets(
        '$language password dialog fits a narrow screen with large text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final accounts = ProfileAccountStore(userIdProvider: () => 'a');
      addTearDown(accounts.dispose);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales:
            AppLanguages.launchReady.map((item) => Locale(item.code)).toList(),
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
            body: ChangePasswordDialog(auth: service, accounts: accounts)),
      ));
      await tester.pumpAndSettle();
      expect(
          find.text(
              AppStringsManager.getString(language, 'password_change_title')),
          findsOneWidget);
      expect(tester.takeException(), null);
      expect(
          Directionality.of(tester.element(find.byType(ChangePasswordDialog))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
    });
  }
}
