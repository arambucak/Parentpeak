import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/widgets/playmate_discovery_empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final groups = {
    'family': MatchOptions.familyForms,
    'gender': MatchOptions.genderLabels.keys,
    'child': MatchOptions.childInterests,
    'values': MatchOptions.valueOptions,
    'looking': MatchOptions.lookingForOptions,
    'days': MatchOptions.dayOptions,
    'times': MatchOptions.timeOptions,
    'specials': MatchOptions.specialOptions,
    'language': MatchOptions.languageLabels.keys,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final language in ['de', 'en', 'tr', 'ku']) {
    test('every wizard option has a central $language translation', () {
      for (final group in groups.entries) {
        for (final code in group.value) {
          final key = 'network_option_${group.key}_$code';
          final label = networkWizardOptionLabel(
            language,
            group.key,
            code,
            'missing',
          );
          expect(label, isNot('missing'), reason: key);
          expect(label, isNotEmpty, reason: key);
          expect(label, AppStringsManager.getString(language, key));
        }
      }
    });

    testWidgets('invite leaves playmates for the network tab in $language', (
      tester,
    ) async {
      final previous = languageService.currentLanguage;
      await tester.runAsync(() => languageService.setLanguage(language));
      addTearDown(() => languageService.setLanguage(previous));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: [Locale(language)],
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: DefaultTabController(
            length: 3,
            initialIndex: 2,
            child: Builder(
              builder: (context) {
                final tabs = DefaultTabController.of(context);
                return Scaffold(
                  body: TabBarView(
                    children: [
                      const Text('Chat target'),
                      const Text('Invitation link and QR target'),
                      SingleChildScrollView(
                        child: PlaymateDiscoveryEmptyState(tabs: tabs),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(
        find.text(
          AppStringsManager.getString(
            language,
            'network_copy_invite_playmates',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Invitation link and QR target'), findsOneWidget);
      expect(find.byType(PlaymateDiscoveryEmptyState), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('English and Turkish options no longer fall back to German', () {
    expect(
      networkWizardOptionLabel('en', 'family', 'alleinerziehend', ''),
      'Single parent',
    );
    expect(networkWizardOptionLabel('tr', 'child', 'bücher', ''), 'Kitaplar');
    expect(networkWizardOptionLabel('en', 'days', 'mittwoch', ''), 'Wed');
    expect(networkWizardOptionLabel('tr', 'times', 'flexibel', ''), 'Esnek');
    expect(
      networkWizardOptionLabel('ku', 'family', 'kernfamilie', ''),
      'Malbata biçûk',
    );
    expect(networkWizardOptionLabel('fr', 'child', 'bücher', ''), 'Books');
    expect(
      networkWizardOptionLabel('en', 'family', 'custom', 'My chosen family'),
      'My chosen family',
    );
  });

  test('public age tags are translated without changing stored codes', () {
    expect(networkChildAgeLabel('de', '3J'), '3 Jahre');
    expect(networkChildAgeLabel('en', '3J'), '3 years');
    expect(networkChildAgeLabel('tr', '3J'), '3 yaş');
    expect(networkChildAgeLabel('ku', '6M'), '6 meh');
    expect(networkChildAgeLabel('en', '6M'), '6 mo.');
    expect(networkChildAgeLabel('en', 'custom age'), 'custom age');
    expect(networkMatchReasonLabel('en', 'nearby'), 'Nearby');
    expect(networkMatchReasonLabel('tr', 'shared_languages'), 'Ortak diller');
    expect(networkMatchReasonLabel('en', 'future_reason'), 'future_reason');
  });

  testWidgets(
    'English wizard translates headings, child ages and custom hints',
    (tester) async {
      final previous = languageService.currentLanguage;
      await tester.runAsync(() => languageService.setLanguage('en'));
      addTearDown(() => languageService.setLanguage(previous));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlaymateProfileForm(onSave: (_) async {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 1: Your family'), findsOneWidget);
      expect(find.text('Single parent'), findsOneWidget);
      await tester.tap(
        find.widgetWithIcon(FilledButton, Icons.arrow_forward_rounded),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Child 1'), findsOneWidget);
      expect(find.text('3 years'), findsOneWidget);
      expect(find.text('e.g. Mia'), findsOneWidget);
      final custom = find.widgetWithText(ActionChip, '\u{2795} Custom');
      await tester.ensureVisible(custom);
      await tester.tap(custom);
      await tester.pumpAndSettle();
      expect(find.text('What else does your child enjoy?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
