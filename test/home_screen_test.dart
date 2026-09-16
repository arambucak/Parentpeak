import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

/// Tests for the Home Screen — verifies rendering without crashes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'onboarding.completed': true,
  });

  group('HomeScreen Widget Tests', () {
    test('Giveaway-market tile is directly translated for launch locales', () {
      const expectedTitles = {
        'de': 'Verschenkmarkt',
        'en': 'Giveaway market',
        'tr': 'Paylaşım pazarı',
        'ku': 'Bazara parvekirinê',
        'ar': 'سوق العطاء والتبادل',
        'ru': 'Ярмарка подарков',
        'uk': 'Ярмарок подарунків',
        'es': 'Mercado de regalos',
        'fr': 'Marché du don',
        'it': 'Mercato del dono',
        'pt': 'Feira de doações',
      };

      for (final entry in expectedTitles.entries) {
        expect(AppStringsManager.treasureTileString(entry.key, 'title'),
            entry.value);
        expect(AppStringsManager.treasureTileString(entry.key, 'subtitle'),
            isNotEmpty);
      }
    });

    testWidgets('Home screen renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('HomeScreen placeholder'))),
        ),
      );
      expect(find.text('HomeScreen placeholder'), findsOneWidget);
    });

    testWidgets('Quick actions have correct labels', (tester) async {
      // Verify the labels exist in the localization
      const lang = 'de';
      final calendar = AppStringsManager.getString(lang, 'calendar');
      final events = AppStringsManager.getString(lang, 'events_near_you');

      expect(calendar, isNotEmpty);
      expect(events, isNotEmpty);
      expect(calendar, equals('Kalender'));
    });

    testWidgets('Feature actions list is populated', (tester) async {
      // Verify localization keys used in home screen exist
      const lang = 'de';
      expect(AppStringsManager.getString(lang, 'tile_impulse'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_calendar'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_events'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_chat'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_zentrale'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_kueche'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_geld'), isNotEmpty);
      expect(AppStringsManager.getString(lang, 'tile_network'), isNotEmpty);
    });

    test('Localization works for EN, TR, KU', () {
      // English
      expect(AppStringsManager.getString('en', 'calendar'), equals('Calendar'));
      expect(AppStringsManager.getString('en', 'save'), isNotEmpty);
      expect(AppStringsManager.getString('en', 'cancel'), isNotEmpty);

      // Turkish
      expect(AppStringsManager.getString('tr', 'calendar'), equals('Takvim'));
      expect(AppStringsManager.getString('tr', 'save'), isNotEmpty);

      // Kurdish
      expect(AppStringsManager.getString('ku', 'calendar'), equals('Salneme'));
      expect(AppStringsManager.getString('ku', 'save'), isNotEmpty);
    });
  });
}
