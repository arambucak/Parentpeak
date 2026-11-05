import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/auth_service.dart';

void main() {
  group('AuthService.pickPrimaryProviderId', () {
    test('null/leer → kein Anbieter', () {
      expect(AuthService.pickPrimaryProviderId(null), isNull);
      expect(AuthService.pickPrimaryProviderId([]), isNull);
    });

    test('reines Passwort-Konto', () {
      expect(AuthService.pickPrimaryProviderId(['password']), 'password');
    });

    test('Google wird gegenüber Passwort bevorzugt', () {
      expect(
        AuthService.pickPrimaryProviderId(['password', 'google.com']),
        'google.com',
      );
    });

    test('Apple wird gegenüber Passwort bevorzugt', () {
      expect(
        AuthService.pickPrimaryProviderId(['password', 'apple.com']),
        'apple.com',
      );
    });

    test('reines Google-Konto', () {
      expect(AuthService.pickPrimaryProviderId(['google.com']), 'google.com');
    });

    test('unbekannter Anbieter fällt auf den ersten zurück', () {
      expect(
        AuthService.pickPrimaryProviderId(['phone']),
        'phone',
      );
    });
  });
}
