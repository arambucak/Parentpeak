import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/config/access_config.dart';

void main() {
  group('AccessConfig', () {
    final launch = DateTime.utc(2027, 1, 1);

    test('beta access does not show a trial countdown', () {
      final days = AccessConfig.trialDaysRemaining(
        DateTime.utc(2026, 8, 1),
        now: DateTime.utc(2026, 8, 15),
        betaFreeAccess: true,
      );

      expect(days, 0);
    });

    test('existing beta users receive 30 days from public launch', () {
      final registeredAt = DateTime.utc(2026, 8, 1);

      expect(
        AccessConfig.trialStartsAt(registeredAt, launchDate: launch),
        launch,
      );
      expect(
        AccessConfig.trialDaysRemaining(
          registeredAt,
          now: launch,
          launchDate: launch,
          betaFreeAccess: false,
        ),
        30,
      );
    });

    test('users joining after launch receive 30 days from registration', () {
      final registeredAt = DateTime.utc(2027, 2, 10, 12);

      expect(
        AccessConfig.trialStartsAt(registeredAt, launchDate: launch),
        registeredAt,
      );
      expect(
        AccessConfig.trialDaysRemaining(
          registeredAt,
          now: registeredAt,
          launchDate: launch,
          betaFreeAccess: false,
        ),
        30,
      );
    });
  });
}