import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/ui/ritual_ruhe_screen.dart';

void main() {
  test('returns English text for English locale', () {
    expect(ritualRuheText('appBarNight', const Locale('en')), 'Good night');
  });

  test('returns Turkish text for Turkish locale', () {
    expect(ritualRuheText('sectionMorning', const Locale('tr')), 'Sabah');
  });

  test('returns Kurdish text for Kurdish locale', () {
    expect(ritualRuheText('sectionAfternoon', const Locale('ku')), 'Nîvro');
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

    for (final locale in const ['en', 'tr', 'ku']) {
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
