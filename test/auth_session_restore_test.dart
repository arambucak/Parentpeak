import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockToken extends Mock implements IdTokenResult {}

class MockCredential extends Mock implements UserCredential {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuth firebase;
  late MockUser user;
  late MockToken token;
  late AuthService service;
  late StreamController<User?> states;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebase = MockAuth();
    user = MockUser();
    token = MockToken();
    states = StreamController<User?>.broadcast();
    when(() => firebase.currentUser).thenReturn(user);
    when(() => firebase.authStateChanges()).thenAnswer((_) => states.stream);
    when(() => firebase.signOut()).thenAnswer((_) async {});
    when(() => user.uid).thenReturn('a');
    when(() => user.email).thenReturn('a@example.com');
    when(() => user.displayName).thenReturn('Account A');
    when(() => user.emailVerified).thenReturn(true);
    when(() => user.reload()).thenAnswer((_) async {});
    when(() => user.getIdTokenResult(true)).thenAnswer((_) async => token);
    when(() => token.token).thenReturn('fresh-token');
    when(() => token.claims).thenReturn({'sub': 'a'});
    when(
      () => token.expirationTime,
    ).thenReturn(DateTime.now().add(const Duration(hours: 1)));
    service = AuthService.withFirebaseForTesting(firebase);
  });

  tearDown(() async {
    service.dispose();
    await states.close();
  });

  Future<void> saveOwner(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pp_current_user',
      jsonEncode(
        ParentUser(
          uid: uid,
          email: '$uid@example.com',
          displayName: uid,
          registeredAt: DateTime(2026),
          isPremium: false,
        ).toJson(),
      ),
    );
  }

  test(
    'restores matching verified owner with a freshly refreshed token',
    () async {
      await saveOwner('a');
      await service.initialize();
      expect(service.currentUser?.uid, 'a');
      verify(() => user.reload()).called(1);
      verify(() => user.getIdTokenResult(true)).called(1);
      verifyNever(() => firebase.signOut());
    },
  );

  test('UID mismatch is signed out and never adopted', () async {
    await saveOwner('b');
    await service.initialize();
    expect(service.currentUser, isNull);
    expect(
      (await SharedPreferences.getInstance()).containsKey('pp_current_user'),
      isFalse,
    );
    verify(() => firebase.signOut()).called(1);
    verifyNever(() => user.getIdTokenResult(true));
  });

  for (final failure in ['expired', 'wrong-owner', 'unverified', 'revoked']) {
    test(
      '$failure Firebase session is rejected without local fallback',
      () async {
        await saveOwner('a');
        switch (failure) {
          case 'expired':
            when(
              () => token.expirationTime,
            ).thenReturn(DateTime.now().subtract(const Duration(seconds: 1)));
          case 'wrong-owner':
            when(() => token.claims).thenReturn({'sub': 'b'});
          case 'unverified':
            when(() => user.emailVerified).thenReturn(false);
          case 'revoked':
            when(
              () => user.getIdTokenResult(true),
            ).thenThrow(FirebaseAuthException(code: 'user-token-expired'));
        }
        await service.initialize();
        expect(service.currentUser, isNull);
        verify(() => firebase.signOut()).called(1);
      },
    );
  }

  test(
    'account changes during token refresh cannot adopt the old result',
    () async {
      final gate = Completer<IdTokenResult>();
      when(() => user.getIdTokenResult(true)).thenAnswer((_) => gate.future);
      final restoring = service.initialize();
      await Future<void>.delayed(Duration.zero);
      when(() => firebase.currentUser).thenReturn(null);
      gate.complete(token);
      await restoring;
      expect(service.currentUser, isNull);
      verify(() => firebase.signOut()).called(1);
    },
  );

  test('external Firebase sign-out invalidates the local session', () async {
    await service.initialize();
    expect(service.isLoggedIn, isTrue);
    when(() => firebase.currentUser).thenReturn(null);
    states.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(service.isLoggedIn, isFalse);
    expect(
      (await SharedPreferences.getInstance()).containsKey('pp_current_user'),
      isFalse,
    );
  });

  test('a login response arriving after logout cannot restore a session', () async {
    final started = Completer<void>();
    final gate = Completer<UserCredential>();
    final credential = MockCredential();
    when(() => credential.user).thenReturn(user);
    when(() => firebase.signInWithEmailAndPassword(
      email: 'a@example.com', password: 'valid-password',
    )).thenAnswer((_) {
      started.complete();
      return gate.future;
    });
    final loggingIn = service.login(
      email: 'a@example.com', password: 'valid-password',
    );
    await started.future;
    await service.logout();
    gate.complete(credential);
    await loggingIn;
    expect(service.currentUser, isNull);
    verify(() => firebase.signOut()).called(2);
    expect(
      (await SharedPreferences.getInstance()).containsKey('pp_current_user'),
      isFalse,
    );
  });

  test(
    'missing Firebase session does not reuse the local saved owner',
    () async {
      await saveOwner('a');
      when(() => firebase.currentUser).thenReturn(null);
      when(
        () => firebase.authStateChanges(),
      ).thenAnswer((_) => Stream.value(null));
      await service.initialize();
      expect(service.currentUser, isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey('pp_current_user'),
        isFalse,
      );
    },
  );
}
