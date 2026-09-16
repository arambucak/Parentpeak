import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

const _languages = ['de', 'en', 'tr', 'ku', 'ar', 'ru', 'uk', 'es', 'fr', 'it', 'pt'];

const _keys = [
  'ritual_add_step', 'ritual_step_title', 'ritual_step_subtitle',
  'ritual_timer_seconds', 'ritual_timer_hint', 'ritual_cancel',
  'ritual_add', 'ritual_edit_plan', 'ritual_name', 'ritual_time',
  'ritual_remove_step', 'ritual_step', 'ritual_save', 'ritual_days',
  'review_well_subtitle', 'review_well_hint', 'review_challenge_subtitle',
  'review_challenge_hint', 'review_learned_subtitle', 'review_learned_hint',
  'review_looking_subtitle', 'review_looking_hint', 'review_optional',
  'review_mood_subtitle', 'review_summary_week', 'review_mood_great',
  'review_mood_good', 'review_mood_mixed', 'review_mood_challenging',
  'review_mood_grateful', 'review_ai_feedback', 'review_ai_loading',
  'review_well_label', 'review_challenge_label', 'review_learned_label',
  'review_forward_label', 'paywall_title', 'paywall_beta', 'paywall_unlock',
  'paywall_trial', 'paywall_expired', 'paywall_limit', 'paywall_free',
  'paywall_premium', 'paywall_basic', 'paywall_full', 'paywall_unlimited',
  'paywall_weekly', 'paywall_ai', 'paywall_calendar', 'paywall_organization',
  'paywall_match', 'paywall_events', 'paywall_market', 'paywall_meals',
  'paywall_yearly', 'paywall_monthly', 'paywall_year_subline',
  'paywall_month_subline', 'paywall_badge', 'paywall_per_year',
  'paywall_per_month', 'paywall_activation_failed', 'paywall_guarantee',
  'paywall_continue', 'paywall_continue_hint',
];

const _placeholderKeys = {
  'ritual_edit_plan': {'title'},
  'review_summary_week': {'mood'},
  'paywall_trial': {'days'},
  'paywall_limit': {'feature'},
};

const _residualKeys = [
  'contacts_emergency', 'contacts_family', 'contacts_medical',
  'contacts_school', 'contacts_other', 'contacts_police', 'contacts_poison',
  'contacts_on_call', 'contacts_copied', 'contacts_add', 'contacts_edit',
  'contacts_name', 'contacts_phone', 'contacts_note', 'contacts_pinned',
  'contacts_not_pinned', 'contacts_delete', 'contacts_cancel',
  'contacts_save', 'contacts_update', 'contacts_title', 'contacts_subtitle',
  'contacts_count', 'contacts_quick_dial', 'contacts_empty_title',
  'contacts_empty_body', 'contacts_copy',
];

const _residualPlaceholderKeys = {
  'contacts_copied': {'number'},
  'contacts_count': {'contacts', 'pinned'},
};

const _ritualRuheKeys = [
  'title', 'tileSubtitle', 'appBarNight', 'appBarMorning',
  'sectionMorning', 'sectionAfternoon', 'sectionEvening', 'your', 'with',
  'for', 'years', 'welcomeNight', 'welcomeRelaxed', 'welcomeQuestion',
  'quietMode', 'close', 'editPlan', 'suggestPlan', 'storyTitle',
  'storyHint', 'storyButtonNew', 'storyButtonGenerate', 'gratitudeTitle',
  'gratitudeHint', 'gratitudePlaceholder', 'timerStart', 'timerDone',
  'allDone', 'timerBanner', 'emptyTitle', 'emptyDescription', 'emptyAction',
  'nightSectionTitle', 'timeCardSubtitle',
];

const _phase1ScreenPaths = [
  'lib/ui/legal_info_screen.dart',
  'lib/ui/marketplace_screen.dart',
  'lib/ui/payment_screen.dart',
  'lib/ui/weekly_planner_screen.dart',
];

const _newScreenKeys = [
  'legal_privacy_not_configured', 'legal_terms_not_configured',
  'payment_provider_reference_missing', 'payment_not_completed',
  'payment_status_unknown', 'payment_stripe_name', 'payment_paypal_name',
  'planner_demo_amount_300_g', 'planner_demo_amount_200_g',
  'planner_demo_amount_150_g', 'planner_demo_amount_400_g',
  'planner_demo_amount_120_g', 'planner_demo_amount_2_pieces',
  'planner_demo_amount_12_pieces', 'planner_demo_amount_500_ml',
  'planner_demo_amount_600_g', 'planner_demo_amount_750_ml',
  'planner_demo_amount_1_piece',
];

Set<String> _placeholders(String value) => RegExp(r'\{(\w+)\}')
    .allMatches(value)
    .map((match) => match.group(1)!)
    .toSet();

void main() {
  test('Phase1 catalog lists exactly the supported eleven locales', () {
    expect(AppStringsManager.phase1Languages, _languages);
  });

  test('every Phase1 locale has every key as direct, non-raw copy', () {
    for (final language in _languages) {
      for (final key in _keys) {
        final value = AppStringsManager.phase1String(language, key);
        expect(AppStringsManager.hasDirectPhase1String(language, key), isTrue,
            reason: '$language must define $key directly');
        expect(value, isNotEmpty, reason: '$language/$key must not be empty');
        expect(value, isNot(key),
            reason: '$language/$key must not return a raw fallback key');
      }
    }
  });

  test('Phase1 placeholders have the same schema in every locale', () {
    for (final language in _languages) {
      for (final key in _keys) {
        expect(
          _placeholders(AppStringsManager.phase1String(language, key)),
          _placeholderKeys[key] ?? <String>{},
          reason: '$language/$key has a different placeholder schema',
        );
      }
    }
  });

  test('residual Phase1 catalog is direct and schema-consistent', () {
    for (final language in _languages) {
      for (final key in _residualKeys) {
        final value = AppStringsManager.phase1ResidualString(language, key);
        expect(AppStringsManager.hasDirectPhase1ResidualString(language, key),
            isTrue, reason: '$language must define $key directly');
        expect(value, isNotEmpty, reason: '$language/$key must not be empty');
        expect(_placeholders(value), _residualPlaceholderKeys[key] ?? <String>{},
            reason: '$language/$key has a different placeholder schema');
      }
    }
  });

  test('ritual-and-calm catalog has direct, schema-consistent copy', () {
    for (final language in _languages) {
      for (final key in _ritualRuheKeys) {
        final value = AppStringsManager.ritualRuheString(language, key);
        expect(AppStringsManager.hasDirectRitualRuheString(language, key),
            isTrue, reason: '$language must define ritual-and-calm $key directly');
        expect(value, isNotEmpty,
            reason: '$language/$key ritual-and-calm copy must not be empty');
        expect(_placeholders(value), isEmpty,
            reason: '$language/$key has an unexpected placeholder');
      }
    }
  });

  test('Arabic Phase1 copy is represented in Arabic script', () {
    expect(
      AppStringsManager.phase1String('ar', 'review_well_label'),
      matches(RegExp(r'[\u0600-\u06FF]')),
    );
    expect(
      AppStringsManager.phase1ResidualString('ar', 'contacts_title'),
      matches(RegExp(r'[\u0600-\u06FF]')),
    );
  });

  test('Phase1 lookup does not fall back to a raw key', () {
    expect(
      () => AppStringsManager.phase1String('de', 'missing_phase1_key'),
      throwsStateError,
    );
    expect(
      () => AppStringsManager.phase1String('ja', 'ritual_add_step'),
      throwsStateError,
    );
    expect(
      () => AppStringsManager.phase1ResidualString('ja', 'contacts_title'),
      throwsStateError,
    );
  });

  test('new requested Phase1 screen copy is direct and schema-consistent', () {
    for (final key in _newScreenKeys) {
      final expectedPlaceholders =
          _placeholders(AppStringsManager.phase1String('de', key));
      for (final language in _languages) {
        final value = AppStringsManager.phase1String(language, key);
        expect(AppStringsManager.hasDirectPhase1String(language, key), isTrue,
            reason: '$language must define $key directly');
        expect(value, isNotEmpty, reason: '$language/$key must not be empty');
        expect(_placeholders(value), expectedPlaceholders,
            reason: '$language/$key has a different placeholder schema');
      }
    }
  });

  test('requested Phase1 screens contain no raw visible static text', () {
    final rawTextArgument = RegExp(
      r'''\b(?:Text|Tooltip)\b\s*\(\s*(?:const\s+)?['"](?![^'"]*\$)''',
    );
    final rawTextProperty = RegExp(
      r'''\b(?:labelText|hintText|tooltip)\s*:\s*['"]''',
    );

    for (final path in _phase1ScreenPaths) {
      final source = File(path).readAsStringSync();
    final codeLines = source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
    expect(codeLines, isNot(matches(rawTextArgument)),
      reason: '$path contains a raw visible text argument');
    expect(codeLines, isNot(matches(rawTextProperty)),
      reason: '$path contains a raw visible text property');
    }
  });

  test('refactored screens contain no local Phase1 maps', () {
    const screens = [
      'lib/ui/ritual_ruhe_screen.dart',
      'lib/ui/wochenrueckblick_screen.dart',
      'lib/ui/auth/paywall_screen.dart',
    ];
    final localMap = RegExp(r'const\s+(?:de|en|tr|ku|ar|ru|uk|es|fr|it|pt)\s*=\s*\{');

    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(matches(localMap)), reason: '$path has a local locale map');
    }
  });
}