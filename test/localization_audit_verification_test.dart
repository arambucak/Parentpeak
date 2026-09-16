import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

void main() {
  const auditedCopiedEnglishKeys = {
    'premium_feature_desc',
    'open_new_connections',
    'open_parent_match',
    'no_new_connections',
    'soon_badge',
    'invites_successful',
    'premium_unlocked',
    'redeem_premium',
    'invite_reward',
    'share_failed',
    'families_waiting',
    'families_remaining',
    'how_it_will_look',
    'add_friend_by_code',
    'share_code_hint',
    'maybe_you_know',
    'real_parents_nearby',
    'suggestions_count',
    'show_this_code',
    'scan_to_connect',
    'connect_by_code',
    'enter_friend_code',
    'found_checkmark',
    'remove_friend_title',
    'remove_btn',
    'delete_profile_title',
    'delete_profile_warning',
    'app_invitation',
    'invite_parents',
    'scan_download_earn',
    'just_scan_no_code',
    'choose_best_fit',
    'looking_for_playmates',
    'add_child_btn',
    'gender_optional',
    'interests_label',
    'custom_value',
    'choose_activities',
    'custom_idea',
    'days_label',
    'times_label',
    'other_time',
    'all_family_languages',
    'matching_families',
    'custom_entry',
    'type_hint_shopping',
    'all_shopping_done',
    'list_complete',
    'no_children_data',
    'years_old',
    'show_emergency_info',
    'emergency_info',
    'recipe_saved',
    'ingredients_portions',
    'portions_label',
    'preparation_label',
    'ingredients_to_list',
    'did_it_taste',
    'yes_tasty',
    'no_tasty',
    'family_food_tips',
    'no_saved_recipes',
    'what_do_you_need',
    'select_only_needed',
    'already_on_list',
    'probably_at_home',
    'add_ingredients_count',
    'country_question',
    'country_hint',
    'monthly_child_costs',
    'per_year',
    'your_monthly_costs',
    'enter_once',
    'saving_tip',
    'what_you_deserve',
    'check_here',
    'whats_coming',
    'saving_recommendation',
    'change_btn',
    'quick_check',
    'employed_question',
    'single_parent',
    'net_income',
    'filter_benefits',
    'saving_goal',
    'saved_amount',
    'goal_amount',
    'month_tight',
    'delete_history_title',
    'ki_parenting_title',
    'no_previous_question',
    'no_questions_yet',
    'reset_counter',
    'feedback_saved',
    'quick_template',
    'add_new_event',
    'day_mo',
    'day_di',
    'day_mi',
    'day_do',
    'day_fr',
    'day_sa',
    'day_so',
    'gps_unavailable',
    'action_save_error',
    'events_title',
    'reload_btn',
    'ki_finds',
    'community_offers',
    'only_nearby',
    'only_free',
    'all_dates',
    'this_weekend',
    'daily_done_mark',
    'daily_done_message',
    'ai_explains_personal',
    'fits_age',
    'tip_label',
    'pedagogical_assessment',
    'ai_based_report',
    'streak_days',
    'whats_going_on',
    'explain_more',
    'how_was_your_day',
    'view_your_week',
    'common_topics',
    'your_impulse_today',
    'no_entry_yet',
    'ask_ai_hint',
    'ask_ai_btn',
    'what_you_can_do',
    'location_denied',
    'gps_error',
    'remaining_today',
    'i_am',
    'category_required',
    'age_group_required',
    'recurring_event',
    'private_address',
    'free_event',
    'accessibility_label',
    'event_language',
    'contact_optional',
    'contact_hint',
    'event_details_title',
    'open_event_website',
    'search_event_online',
    'new_member',
  };
  final placeholderPattern = RegExp(r'\{[^{}]+\}');
  final arabicScriptPattern = RegExp(r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]');

  test('audited localization invariants hold', () {
    final strings = AppStringsManager.allStrings;
    final referenceKeys = strings['de']!.keys.toSet();

    expect(auditedCopiedEnglishKeys, hasLength(148));
    for (final code in const ['en', 'tr', 'ku']) {
      expect(strings[code]!.keys.toSet(), referenceKeys, reason: code);
    }

    for (final key in referenceKeys) {
      final expected = placeholderPattern
          .allMatches(strings['de']![key]!)
          .map((match) => match.group(0))
          .toList()
        ..sort();
      for (final code in const ['en', 'tr', 'ku']) {
        final actual = placeholderPattern
            .allMatches(strings[code]![key]!)
            .map((match) => match.group(0))
            .toList()
          ..sort();
        expect(actual, expected, reason: '$code:$key');
      }
    }

    expect(
      strings['ku']!.values.where(arabicScriptPattern.hasMatch),
      isEmpty,
    );
    expect(
      auditedCopiedEnglishKeys.where(
        (key) => strings['ku']![key] == strings['en']![key],
      ),
      isEmpty,
    );
  });
}