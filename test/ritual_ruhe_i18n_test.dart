import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/ui/ritual_ruhe_screen.dart';

void main() {
  test('returns English text for English locale', () {
    expect(ritualRuheText('appBarNight', const Locale('en')), 'Good Evening');
    expect(ritualRuheText('appBarAfternoon', const Locale('en')), 'Good Afternoon');
  });

  test('returns Turkish text for Turkish locale', () {
    expect(ritualRuheText('sectionMorning', const Locale('tr')), 'Sabah');
    expect(ritualRuheText('title', const Locale('tr')), 'Ritüel ve Dinlenme');
    expect(ritualRuheText('appBarNight', const Locale('tr')), 'İyi Akşamlar');
    expect(ritualRuheText('emptyAction', const Locale('tr')), 'Aile Profiline Git');
  });

  test('returns Kurdish text for Kurdish locale', () {
    expect(ritualRuheText('sectionAfternoon', const Locale('ku')), 'Nîvro');
    expect(ritualRuheText('tileSubtitle', const Locale('ku')), 'Ji bo jiyana malbatê kêliyek aştîyane');
    expect(ritualRuheText('appBarNight', const Locale('ku')), 'Êvar baş');
    expect(ritualRuheText('emptyAction', const Locale('ku')), 'Herin Profîla Malbatê');
  });

  test('returns native ritual copy for the seven added locales', () {
    const expectedTitles = {
      'ar': 'طقوس وهدوء',
      'ru': 'Ритуалы и покой',
      'uk': 'Ритуали та спокій',
      'es': 'Rituales y calma',
      'fr': 'Rituels et calme',
      'it': 'Rituali e calma',
      'pt': 'Rituais e calma',
    };

    for (final entry in expectedTitles.entries) {
      expect(ritualRuheText('title', Locale(entry.key)), entry.value);
      expect(ritualRuheText('appBarNight', Locale(entry.key)), isNotEmpty);
    }
  });

  test('includes missing profile and onboarding translation keys', () {
    expect(AppStringsManager.getString('en', 'profile_edit_display_name_title'),
        'Edit display name');
    expect(AppStringsManager.getString('tr', 'profile_edit_display_name_title'),
        'Görünen adını düzenle');
    expect(AppStringsManager.getString('ku', 'onboarding_role_single_parent'),
        'Tenê dêûbav');
  });

  test('audited UI keys resolve for English, Turkish, and Kurdish', () {
    const keys = [
      'onboarding_stage_baby',
      'onboarding_stage_school_child',
      'onboarding_age_caregiver',
      'onboarding_age_professional_desc',
      'ai_memory_title',
      'ai_memory_enable',
      'ai_memory_transparency',
      'ai_memory_children',
      'ai_memory_add_child',
      'ai_memory_no_children',
      'ai_memory_no_items',
      'ai_memory_confirmed_description',
      'ai_memory_delete_child_title',
      'ai_memory_name',
      'ai_memory_gender_optional',
      'ai_memory_cancel',
      'ai_memory_save',
      'ai_memory_delete',
      'ai_memory_edit',
      'ai_memory_add_title',
      'ai_memory_edit_title',
      'ai_memory_load_failed',
      'ai_memory_request_failed',
      'ai_memory_without_profile',
      'ai_memory_confirmed_count',
      'ai_memory_none_confirmed',
      'onboarding_language_title',
      'onboarding_language_subtitle',
      'location_onboarding_explanation',
      'location_onboarding_privacy',
      'location_onboarding_skip',
      'location_onboarding_detect',
      'location_onboarding_manual_title',
      'location_onboarding_manual_hint',
      'profile_child_age_hint',
      'profile_display_name_updated',
      'profile_delete_confirmation_word',
      'profile_reauth_delete_prompt',
      'matching_safety_warning',
      'matching_profile_save_failed',
      'matching_location_center',
      'matching_new_connections',
      'matching_reason_family_stage',
      'matching_privacy_note',
      'matching_status_summary',
      'matching_quality',
      'matching_no_filtered_profiles',
    ];

    for (final locale in const [
      'de', 'en', 'tr', 'ku', 'ar', 'ru', 'uk', 'es', 'fr', 'it', 'pt'
    ]) {
      for (final key in keys) {
        expect(
          AppStringsManager.getString(locale, key),
          isNot(key),
          reason: '$key must be translated for $locale',
        );
      }
    }
  });
}
