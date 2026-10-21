import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/l10n/supported_languages.dart';

void main() {
  test('official languages are consistent with localization sources', () {
    const expectedCodes = {
      'de',
      'en',
      'ar',
      'fa',
      'ku',
      'ckb',
      'fr',
      'es',
      'it',
      'pt',
      'nl',
      'pl',
      'tr',
      'ja',
      'zh',
      'hi',
    };

    final configuredCodes = AppLanguages.supported
        .map((language) => language.code)
        .toSet();
    final localeCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();

    expect(configuredCodes, expectedCodes);
    expect(localeCodes, expectedCodes);
    expect(
      configuredCodes.every(AppStringsManager.allStrings.containsKey),
      isTrue,
    );
    expect(AppLanguages.isSupported('ko'), isFalse);
    expect(AppLanguages.normalizeCode('ko'), AppLanguages.defaultCode);
  });

  test('RTL classification distinguishes Sorani from Kurmanji', () {
    expect(AppLanguages.rtlCodes, {'ar', 'fa', 'ckb'});
    expect(AppLanguages.isRtl('ku'), isFalse);
  });

  test('launch picker offers only the fully translated languages', () {
    const expectedLaunchCodes = {
      'de',
      'en',
      'ar',
      'ku',
      'fr',
      'es',
      'it',
      'tr',
    };

    final launchCodes = AppLanguages.launchReady
        .map((language) => language.code)
        .toSet();

    expect(launchCodes, expectedLaunchCodes);
    // launchReady must be a subset of the full supported list.
    final supportedCodes = AppLanguages.supported
        .map((language) => language.code)
        .toSet();
    expect(launchCodes.difference(supportedCodes), isEmpty);
    // Every supported language flagged complete must appear in the picker.
    final completeCodes = AppLanguages.supported
        .where((language) => language.complete)
        .map((language) => language.code)
        .toSet();
    expect(launchCodes, completeCodes);
  });

  test('every launch-ready language carries every source translation key', () {
    final sourceKeys = AppStringsManager.allStrings['de']!.keys.toSet();

    for (final language in AppLanguages.launchReady) {
      final translatedKeys = AppStringsManager.allStrings[language.code]!.keys
          .toSet();
      final missing = sourceKeys.difference(translatedKeys);
      expect(
        missing,
        isEmpty,
        reason:
            '${language.code} is offered in the picker but is missing '
            '${missing.length} keys and would fall back to English',
      );
    }
  });

  test('launch translations preserve source placeholders', () {
    final source = AppStringsManager.allStrings['de']!;
    final placeholderPattern = RegExp(r'\{[^}]+\}');

    for (final languageCode in const [
      'en',
      'tr',
      'ku',
      'fr',
      'es',
      'it',
      'ar',
    ]) {
      final translated = AppStringsManager.allStrings[languageCode]!;
      for (final entry in source.entries) {
        final sourcePlaceholders =
            placeholderPattern
                .allMatches(entry.value)
                .map((match) => match.group(0))
                .toList()
              ..sort();
        final translatedPlaceholders =
            placeholderPattern
                .allMatches(translated[entry.key]!)
                .map((match) => match.group(0))
                .toList()
              ..sort();

        expect(
          translatedPlaceholders,
          sourcePlaceholders,
          reason: '$languageCode.${entry.key} must preserve placeholders',
        );
      }
    }
  });

  test('launch catalogs contain no empty translations', () {
    for (final language in AppLanguages.launchReady) {
      final empty = AppStringsManager.allStrings[language.code]!.entries
          .where((entry) => entry.value.trim().isEmpty)
          .map((entry) => entry.key)
          .toList();
      expect(empty, isEmpty, reason: '${language.code}: $empty');
    }
  });

  test(
    'fr es it ar have no English placeholders beyond reviewed shared terms',
    () {
      const common = {
        'events_source_ai',
        'family_hub_phone_hint',
        'finance_content_turkey_name_1',
        'finance_content_turkey_name_5',
        'finance_content_uk_name_1',
        'finance_content_uk_name_4',
        'finance_content_uk_name_7',
        'radius_km',
      };
      // Cognates, established UI terms, official program names, units and samples.
      const reviewed = {
        'fr': {
          'antrag_documents_tab',
          'antrag_guide_tab',
          'benefit_sources',
          'calendar_end_count',
          'calendar_person_parents',
          'calendar_template_sport',
          'calendar_template_vaccination',
          'category_sport',
          'chat_btn',
          'chat_spam',
          'contacts',
          'duration_1_min',
          'duration_2_min',
          'duration_3_min',
          'duration_5_min',
          'duration_minutes',
          'event_access_barrierefrei',
          'event_category_arts',
          'event_community_category_ausflug',
          'event_creator_verein',
          'event_detail_description',
          'event_detail_participants',
          'event_mode_label',
          'event_places',
          'event_scan_field_date',
          'event_scan_field_description',
          'events_invitations',
          'family_hub_notes',
          'family_ok',
          'filter_public',
          'finance_label_distance',
          'finance_label_note',
          'finance_label_parent',
          'host_participants',
          'market_contact',
          'network_owner_label',
          'network_suggestions_count',
          'notifications',
          'organisation_title',
          'parent_role',
          'pdf_trend_stable',
          'photos',
          'portions_label',
          'suggestions_count',
          'tooltip_options',
        },
        'es': {
          'category_general',
          'chat_btn',
          'chat_init_error',
          'chat_insight_crisis',
          'chat_spam',
          'common_error_with_detail',
          'duration_1_min',
          'duration_2_min',
          'duration_3_min',
          'duration_5_min',
          'duration_minutes',
          'error_generic',
          'event_detail_error',
          'family_hub_emergency_phone_hint',
          'family_ok',
          'finance_country_at',
          'home_greeting_name',
          'kitchen_error',
          'kitchen_minutes',
          'legal',
          'network_chat',
          'network_owner_label',
          'network_tab_chats',
          'no_answer',
          'no_tasty',
          'organization_category_general',
        },
        'it': {
          'account',
          'auth_password_label',
          'calendar_template_sport',
          'category_sport',
          'chat_btn',
          'chat_insight_media',
          'chat_spam',
          'event_community_category_kino',
          'family_hub_emergency_phone_hint',
          'family_ok',
          'finance_country_at',
          'home_greeting_name',
          'kitchen_minutes',
          'nav_home',
          'network_chat',
          'network_owner_label',
          'no_answer',
          'no_tasty',
          'privacy',
        },
        'ar': {'family_hub_emergency_phone_hint'},
      };
      final english = AppStringsManager.allStrings['en']!;
      for (final entry in reviewed.entries) {
        final identical = AppStringsManager.allStrings[entry.key]!.entries
            .where(
              (translation) => translation.value == english[translation.key],
            )
            .map((translation) => translation.key)
            .toSet();
        expect(
          identical,
          {...common, ...entry.value},
          reason:
              '${entry.key}: review new English-identical strings individually',
        );
      }
    },
  );

  test('Kurmanji catalog uses Latin rather than Sorani script', () {
    final arabicScript = RegExp(r'[\u0600-\u06FF\u0750-\u077F]');

    for (final entry in AppStringsManager.allStrings['ku']!.entries) {
      expect(
        arabicScript.hasMatch(entry.value),
        isFalse,
        reason: 'ku.${entry.key} must use Latin-script Kurmanji',
      );
    }
  });

  test('AppLocalizations resolves migrated keys from the primary manager', () {
    final german = AppLocalizations(const Locale('de'));
    final english = AppLocalizations(const Locale('en'));

    expect(german.t('family_recipe_delete_title'), 'Rezept löschen?');
    expect(english.t('family_recipe_delete_title'), 'Delete recipe?');
    expect(
      german.calendarTitle,
      AppStringsManager.getString('de', 'calendar_title'),
    );
  });

  testWidgets('BuildContext localization replaces placeholders', (
    tester,
  ) async {
    late String localized;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: Builder(
          builder: (context) {
            localized = context.tr(
              'family_recipe_delete_confirm',
              values: const {'title': 'Soup'},
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(localized, 'Do you really want to delete “Soup”?');
  });

  testWidgets('MaterialApp locale changes propagate to text and directionality', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('de'));
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, currentLocale, child) => MaterialApp(
          locale: currentLocale,
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: Builder(
            builder: (context) => Text(
              '${Localizations.localeOf(context).languageCode}|'
              '${Directionality.of(context).name}|'
              '${context.tr('family_recipe_delete_title')}',
            ),
          ),
        ),
      ),
    );

    expect(find.text('de|ltr|Rezept löschen?'), findsOneWidget);

    // Erwartete Werte je RTL-Sprache: ar ist für die Kern-UI übersetzt (#186),
    // fa/ckb fallen (noch) auf den englischen Wert zurück. Die eigentliche
    // Invariante dieses Tests ist Locale-Propagation + RTL-Directionality.
    const rtlExpected = <String, String>{
      'ar': 'ar|rtl|حذف الوصفة؟',
      'fa': 'fa|rtl|Delete recipe?',
      'ckb': 'ckb|rtl|Delete recipe?',
    };
    for (final entry in rtlExpected.entries) {
      locale.value = Locale(entry.key);
      await tester.pumpAndSettle();

      expect(
        find.text(entry.value),
        findsOneWidget,
        reason:
            '${entry.key} must update the app locale and use RTL directionality',
      );
    }

    locale.value = const Locale('ku');
    await tester.pumpAndSettle();
    expect(find.text('ku|ltr|Rêçeteyê jê bibî?'), findsOneWidget);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('en|ltr|Delete recipe?'), findsOneWidget);
  });

  for (final language in AppLanguages.launchReady) {
    testWidgets(
      '${language.code} renders Treasure detail values at large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const values = {
          'treasureConditionLine': {'condition': 'A'},
          'treasurePickupAreaLine': {'area': 'B'},
          'treasureRatingLine': {'rating': '4.5', 'count': '12'},
          'treasureSizeAgeLine': {'sizeAge': '92'},
          'treasureViewsLine': {'count': '42'},
        };
        final l10n = AppLocalizations(Locale(language.code));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language.code),
            supportedLocales: AppLanguages.supportedLocales,
            localizationsDelegates: const [
              AppLanguages.materialLocalizationsDelegate,
              AppLanguages.widgetsLocalizationsDelegate,
              AppLanguages.cupertinoLocalizationsDelegate,
            ],
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final entry in values.entries)
                        Text(l10n.tFormat(entry.key, entry.value)),
                      Text(l10n.t('no_items')),
                      Text(l10n.t('retry')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        for (final entry in values.entries) {
          final text = l10n.tFormat(entry.key, entry.value);
          expect(text.trim(), isNotEmpty);
          expect(text, isNot(entry.key));
          expect(text, isNot(contains('{')));
          for (final value in entry.value.values) {
            expect(text, contains(value));
          }
          expect(find.text(text), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(Column))),
          language.code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
      },
    );
  }

  for (final entry in const {
    'ar': TextDirection.rtl,
    'fa': TextDirection.rtl,
    'ckb': TextDirection.rtl,
    'ku': TextDirection.ltr,
  }.entries) {
    testWidgets('${entry.key} uses ${entry.value.name} directionality', (
      tester,
    ) async {
      late TextDirection direction;

      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: Builder(
            builder: (context) {
              direction = Directionality.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(direction, entry.value);
    });
  }
}
