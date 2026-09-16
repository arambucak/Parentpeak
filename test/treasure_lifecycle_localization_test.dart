import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';

void main() {
  const expectedLanguages = [
    'de',
    'en',
    'tr',
    'ku',
    'ar',
    'ru',
    'uk',
    'es',
    'fr',
    'it',
    'pt',
  ];

  test('listing lifecycle notice is available for every launch language', () {
    for (final language in expectedLanguages) {
      final notice =
          AppLocalizations(Locale(language)).treasureListingLifecycleNotice;
      expect(notice, isNotEmpty, reason: '$language needs lifecycle copy');
      expect(notice, contains('30'));
      expect(notice, contains('60'));
    }
  });

  test('Arabic listing lifecycle notice uses Arabic script', () {
    final notice =
        AppLocalizations(const Locale('ar')).treasureListingLifecycleNotice;
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(notice), isTrue);
  });
}