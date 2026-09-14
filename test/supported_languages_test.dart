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

    final configuredCodes =
        AppLanguages.supported.map((language) => language.code).toSet();
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

  test('launch languages contain every source translation key', () {
    final sourceKeys = AppStringsManager.allStrings['de']!.keys.toSet();

    for (final languageCode in const ['en', 'tr', 'ku']) {
      final translatedKeys =
          AppStringsManager.allStrings[languageCode]!.keys.toSet();
      expect(
        translatedKeys,
        sourceKeys,
        reason: '$languageCode must not rely on fallback or expose raw keys',
      );
    }
  });

  test('launch translations preserve source placeholders', () {
    final source = AppStringsManager.allStrings['de']!;
    final placeholderPattern = RegExp(r'\{[^}]+\}');

    for (final languageCode in const ['en', 'tr', 'ku']) {
      final translated = AppStringsManager.allStrings[languageCode]!;
      for (final entry in source.entries) {
        final sourcePlaceholders = placeholderPattern
            .allMatches(entry.value)
            .map((match) => match.group(0))
            .toList()
          ..sort();
        final translatedPlaceholders = placeholderPattern
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
    expect(german.calendarTitle,
        AppStringsManager.getString('de', 'calendar_title'));
  });

  testWidgets('BuildContext localization replaces placeholders',
      (tester) async {
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

  testWidgets('MaterialApp locale changes propagate to text and directionality',
      (tester) async {
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

    for (final code in const ['ar', 'fa', 'ckb']) {
      locale.value = Locale(code);
      await tester.pumpAndSettle();

      expect(
        find.text('$code|rtl|Delete recipe?'),
        findsOneWidget,
        reason: '$code must update the app locale and use RTL directionality',
      );
    }

    locale.value = const Locale('ku');
    await tester.pumpAndSettle();
    expect(find.text('ku|ltr|Rêçeteyê jê bibî?'), findsOneWidget);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('en|ltr|Delete recipe?'), findsOneWidget);
  });

  for (final entry in const {
    'ar': TextDirection.rtl,
    'fa': TextDirection.rtl,
    'ckb': TextDirection.rtl,
    'ku': TextDirection.ltr,
  }.entries) {
    testWidgets('${entry.key} uses ${entry.value.name} directionality',
        (tester) async {
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
