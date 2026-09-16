import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

void main() {
  final placeholderPattern = RegExp(r'\{[^}]+\}');
  const developmentDomainIds = [
    'motorik',
    'sprache',
    'denken',
    'sozial',
    'selbst',
  ];

  final requiredDevelopmentKeys = <String>{
    'development_intro_title',
    'development_intro_subtitle',
    'development_intro_step_1',
    'development_intro_step_2',
    'development_intro_step_3',
    'development_intro_confirm',
    'development_quick_check_enabled',
    'development_start_quick_check',
    'development_snooze_3_days',
    'development_snooze_1_week',
    'development_snooze_2_weeks',
    'development_pause_reminders',
    'development_weight_early',
    'development_weight_middle',
    'development_weight_late',
    'development_weight_hint_early',
    'development_weight_hint_middle',
    'development_weight_hint_late',
    'development_stage_1',
    'development_stage_2',
    'development_stage_3',
    'development_quick_start_title',
    'development_hide_hint',
    'development_quick_start_steps',
    'development_status_not_yet',
    'development_status_emerging',
    'development_status_mostly',
    'development_status_reliable',
    'development_self_check_not_yet',
    'development_self_check_rarely',
    'development_self_check_often',
    'development_self_check_confident',
    for (final domainId in developmentDomainIds) ...[
      'development_domain_${domainId}_title',
      'development_domain_${domainId}_description',
      for (var index = 1; index <= 3; index++)
        'development_domain_${domainId}_question_$index',
      for (var index = 1; index <= 10; index++)
        'development_domain_${domainId}_detailed_$index',
      for (var index = 1; index <= 2; index++)
        'development_domain_${domainId}_action_$index',
    ],
  };
  const requiredWeeklyCompanionKeys = <String>{
    'weekly_companion_quick_title',
    'weekly_companion_quick_duration',
    'weekly_companion_quick_format',
    'weekly_companion_understand_title',
    'weekly_companion_understand_duration',
    'weekly_companion_understand_format',
    'weekly_companion_practice_title',
    'weekly_companion_practice_summary',
    'weekly_companion_practice_duration',
    'weekly_companion_practice_format',
    'weekly_companion_reflect_title',
    'weekly_companion_reflect_summary',
    'weekly_companion_reflect_duration',
    'weekly_companion_reflect_format',
    'weekly_companion_deepdive_title',
    'weekly_companion_deepdive_duration',
    'weekly_companion_deepdive_format',
  };

  test('Package 2 has an equal direct schema and preserves placeholders', () {
    const expectedLanguages = <String>{
      'de', 'en', 'tr', 'ku', 'ar', 'ru', 'uk', 'es', 'fr', 'it', 'pt',
    };
    expect(AppStringsManager.package2Languages.toSet(), expectedLanguages);

    for (final key in AppStringsManager.package2Keys) {
      final german = AppStringsManager.package2String('de', key)!;
      final germanPlaceholders = placeholderPattern
          .allMatches(german)
          .map((match) => match.group(0))
          .toList();
      for (final language in AppStringsManager.package2Languages) {
        expect(AppStringsManager.hasPackage2Translation(language, key), isTrue,
            reason: '$language/$key must be a direct Package 2 entry');
        final translation = AppStringsManager.package2String(language, key);
        expect(translation, isNotEmpty, reason: '$language/$key must not be empty');
        expect(
          placeholderPattern.allMatches(translation!).map((match) => match.group(0)).toList(),
          germanPlaceholders,
          reason: '$language/$key must preserve placeholders',
        );
      }
    }
  });

  test('Package 2 locale maps expose the same direct key schema', () {
    final germanKeys = AppStringsManager.package2Keys.toSet();
    for (final language in AppStringsManager.package2Languages) {
      final localeKeys = <String>{
        for (final key in AppStringsManager.package2Keys)
          if (AppStringsManager.hasPackage2Translation(language, key)) key,
      };
      expect(localeKeys, germanKeys, reason: '$language must match the de schema');
    }
  });

  test('Package 2 catalog has no English fallback construction', () {
    final source = File('${Directory.current.path}/lib/l10n/app_localizations_all.dart')
        .readAsStringSync();
    const forbidden = [
      '_kitchenCopy',
      '_kitchenLocalized',
      '_developmentStrings(',
      '_developmentFeatureStrings(',
      'isGermanLanguage',
      'isArabic',
      '..._package2WeeklyBaseStrings',
      '..._package2WeeklyEnglishStrings',
      "_package2SattBaseStrings['en']",
      "language: _package2SattBaseStrings['en']",
      "'tr': english",
      "'ku': english",
      "'ar': english",
      "'ru': english",
      "'uk': english",
      "'es': english",
      "'fr': english",
      "'it': english",
      "'pt': english",
    ];
    for (final pattern in forbidden) {
      expect(source.contains(pattern), isFalse,
          reason: 'Package 2 must not use fallback construction: $pattern');
    }
  });

  test('lib has no English or German map-copy inheritance', () {
    final libDirectory = Directory('${Directory.current.path}/lib');
    final copyPattern = RegExp(r'\.from\((?:english|german)\)');
    final matches = <String>[];

    for (final entity in libDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (copyPattern.hasMatch(entity.readAsStringSync())) {
        matches.add(entity.path);
      }
    }

    expect(matches, isEmpty,
        reason: 'Locale catalogs must not inherit from English or German maps');
  });

  test('Package 2 development catalog has no cross-locale map aliases', () {
    final source = File('${Directory.current.path}/lib/l10n/app_localizations_all.dart')
        .readAsStringSync();
    final developmentStart = source.indexOf('_package2DevelopmentStrings');
    final developmentEnd = source.indexOf('static final Map<String, Map<String, String>> _package2Strings');
    final developmentCatalog = source.substring(developmentStart, developmentEnd);

    expect(RegExp(r"'(?:tr|ku|ar|ru|uk|es|fr|it|pt)':\s*(?:english|german)")
        .hasMatch(developmentCatalog), isFalse);
    expect(developmentCatalog.contains('Map<String, String>.from('), isFalse);
    for (final language in AppStringsManager.package2Languages) {
      expect(
        developmentCatalog.contains(
            "'$language': _package2DevelopmentForLocale('$language')"),
        isTrue,
        reason: '$language must have an explicit native development map route',
      );
      expect(
        developmentCatalog.contains("'$language': {'titles':"),
        isTrue,
        reason: '$language must own native domain titles and content',
      );
    }
  });

  test('Package 2 representative translations are native', () {
    expect(AppStringsManager.package2String('de', 'gemini_hint'),
        'Stelle eine Frage...');
    expect(AppStringsManager.package2String('en', 'gemini_hint'),
        'Ask a question...');
    expect(AppStringsManager.package2String('ar', 'gemini_hint'),
        'اطرحوا سؤالًا...');
    expect(AppStringsManager.package2String('ar', 'meal_removed'),
      'تم إزالة الوجبة');

    const nativeKitchenLabels = {
      'de': 'Vegetarisch',
      'en': 'Vegetarian',
      'tr': 'Vejetaryen',
      'ku': 'Vegetaryen',
      'ar': 'نباتي',
      'ru': 'Вегетарианское',
      'uk': 'Вегетаріанське',
      'es': 'Vegetariano',
      'fr': 'Végétarien',
      'it': 'Vegetariano',
      'pt': 'Vegetariano',
    };
    const nativeWeeklyTitles = {
      'de': 'Heute in 2 Minuten',
      'en': 'Today in 2 minutes',
      'tr': 'Bugün 2 dakikada',
      'ku': 'Îro di 2 deqîqeyan de',
      'ar': 'اليوم في دقيقتين',
      'ru': 'Сегодня за 2 минуты',
      'uk': 'Сьогодні за 2 хвилини',
      'es': 'Hoy en 2 minutos',
      'fr': 'Aujourd’hui en 2 minutes',
      'it': 'Oggi in 2 minuti',
      'pt': 'Hoje em 2 minutos',
    };
    for (final language in AppStringsManager.package2Languages) {
      expect(AppStringsManager.package2String(language, 'food_vegetarian'),
          nativeKitchenLabels[language]);
      expect(AppStringsManager.package2String(
          language, 'weekly_companion_quick_title'), nativeWeeklyTitles[language]);
    }

    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    for (final key in [
      'food_vegetarian',
      'weekly_companion_quick_title',
      'meal_removed',
    ]) {
      expect(arabicPattern.hasMatch(AppStringsManager.package2String('ar', key)!),
          isTrue, reason: 'ar/$key must contain Arabic text');
    }
  });

  test('Package 2 development schema is direct and preserves placeholders', () {
    for (final key in requiredDevelopmentKeys) {
      final german = AppStringsManager.package2String('de', key)!;
      final germanPlaceholders = placeholderPattern
          .allMatches(german)
          .map((match) => match.group(0))
          .toList();
      for (final language in AppStringsManager.package2Languages) {
        expect(AppStringsManager.hasPackage2Translation(language, key), isTrue,
            reason: '$language/$key must be a direct development entry');
        final translation = AppStringsManager.package2String(language, key);
        expect(translation, isNotEmpty,
            reason: '$language/$key must not be empty');
        expect(
          placeholderPattern
              .allMatches(translation!)
              .map((match) => match.group(0))
              .toList(),
          germanPlaceholders,
          reason: '$language/$key must preserve placeholders',
        );
      }
    }

    expect(AppStringsManager.package2String(
        'de', 'development_domain_motorik_title'), 'Motorik');
    expect(AppStringsManager.package2String(
        'en', 'development_domain_motorik_title'), 'Motor skills');
    expect(AppStringsManager.package2String(
        'ar', 'development_domain_motorik_title'), 'المهارات الحركية');
  });

  test('Package 2 weekly companion defaults are direct in every locale', () {
    for (final key in requiredWeeklyCompanionKeys) {
      for (final language in AppStringsManager.package2Languages) {
        expect(AppStringsManager.hasPackage2Translation(language, key), isTrue,
            reason: '$language/$key must be a direct Package 2 entry');
        expect(AppStringsManager.package2String(language, key), isNotEmpty);
      }
    }
  });

  test('Package 2 feature sources have no static render text literals', () {
    final workspace = Directory.current.path;
    final sourceFiles = [
      'lib/models_and_widgets/development_schema_feature.dart',
      'lib/models_and_widgets/weekly_impulse_feature.dart',
    ];
    final renderLiteral = RegExp(
      r'''(?:\bText|\bpw\.Text|\bdrawText)\(['\"](?![^'\"]*\$)''',
      multiLine: true,
    );
    final weeklyDefaultLiteral = RegExp(
      r'''(?:title|summary|durationLabel|formatLabel):\s*['\"]''',
      multiLine: true,
    );

    for (final relativePath in sourceFiles) {
      final source = File('$workspace/$relativePath').readAsStringSync();
      final renderMatches = renderLiteral
        .allMatches(source)
        .map((match) => match.group(0))
        .toList();
      expect(renderMatches, isEmpty,
        reason: '$relativePath contains a static user-visible render literal');
      if (relativePath.endsWith('weekly_impulse_feature.dart')) {
        expect(weeklyDefaultLiteral.hasMatch(source), isFalse,
            reason: '$relativePath contains a static weekly content default');
      }
    }
  });

  test('Package 2 offer form and child picker use localized display text', () {
    final workspace = Directory.current.path;
    final development = File(
            '$workspace/lib/models_and_widgets/development_schema_feature.dart')
        .readAsStringSync();
    final offerSheet =
        File('$workspace/lib/ui/gemeinsam_satt_screen.dart').readAsStringSync();

    for (final literal in ['Kind 1', 'Kind 2', 'Kind 3']) {
      expect(development.contains("label: '$literal'"), isFalse);
    }
    for (final literal in [
      'Essen anbieten',
      'Was hast du heute zu viel gekocht?',
      'Gericht',
      'Beschreibung',
      'Wie viele Portionen?',
      'Hinweise für Eltern',
      'Abholzeit',
      'Jetzt teilen',
    ]) {
      expect(offerSheet.contains("'$literal'"), isFalse,
          reason: 'offer sheet literal "$literal" must use Package 2');
    }
  });

  test('Package 2 does not fall back and getString retains missing raw keys', () {
    expect(AppStringsManager.package2String('zh', 'gemini_hint'), isNull);
    expect(AppStringsManager.package2String('de', 'missing_key'), isNull);
    expect(AppStringsManager.getString('zh', 'package2_gemini_hint'),
        'package2_gemini_hint');
  });
}