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

  test(
      'direct chat hints name the reachable family tab in all launch languages',
      () {
    for (final language in ['de', 'en', 'ar', 'ku', 'fr', 'es', 'it', 'tr']) {
      expect(
        AppStringsManager.getString(language, 'network_start_direct_chat_hint'),
        contains(
            AppStringsManager.getString(language, 'network_tab_my_family')),
        reason: language,
      );
    }
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

    testWidgets('invite leaves discovery for My Family in $language', (
      tester,
    ) async {
      final previous = languageService.currentLanguage;
      await tester.runAsync(() => languageService.setLanguage(language));
      addTearDown(() => languageService.setLanguage(previous));
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: [Locale(language)],
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: StatefulBuilder(
            builder: (context, update) {
              return Scaffold(
                bottomNavigationBar: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (value) => update(() => index = value),
                  destinations: [
                    for (final key in [
                      'network_tab_discover',
                      'network_tab_moments',
                      'network_tab_chats',
                      'network_tab_my_family',
                    ])
                      NavigationDestination(
                        icon: const Icon(Icons.family_restroom),
                        label: AppStringsManager.getString(language, key),
                      ),
                  ],
                ),
                body: IndexedStack(
                  index: index,
                  children: [
                    SingleChildScrollView(
                      child: PlaymateDiscoveryEmptyState(
                        onInvite: () => update(() => index = 3),
                      ),
                    ),
                    const Text('Moments target'),
                    const Text('Chat target'),
                    const Text('Invitation link and QR target'),
                  ],
                ),
              );
            },
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
    // FR ist seit #188 für die Netzwerk-Optionen übersetzt (nicht mehr
    // EN-Fallback). Die geprüfte Invariante (EN/TR fallen nicht auf Deutsch
    // zurück) bleibt in den Zeilen oben erhalten.
    expect(networkWizardOptionLabel('fr', 'child', 'bücher', ''), '📚 Livres');
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
    expect(networkMatchReasonLabel('en', 'future_reason'), isNull);
  });

  testWidgets(
    'English wizard translates headings, child ages and custom hints',
    (tester) async {
      final previous = languageService.currentLanguage;
      await tester.runAsync(() => languageService.setLanguage('en'));
      addTearDown(() => languageService.setLanguage(previous));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Step 1 requires name and district before "Next".
            body: PlaymateProfileForm(
              initialProfile: FamilyMatchProfile(
                displayName: 'Test family',
                district: 'Berlin',
                children: [ChildEntry(name: '', ageMonths: 36)],
                languages: const ['en'],
                familyForm: 'kernfamilie',
                values: const [],
                lookingFor: const [],
                createdAt: DateTime(2024, 1, 2),
              ),
              onSave: (_) async {},
            ),
          ),
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
