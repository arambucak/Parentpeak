import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';

/// Regressionstest gegen die i18n-Lücke im Kalender: Alle vom Kalender-Modul
/// genutzten String-Keys müssen in jeder im Sprach-Picker auswählbaren Sprache
/// vorhanden sein (nicht nur per englischem Fallback).
void main() {
  // Keys, die der Kalender-Screen über AppStringsManager.getString auflöst.
  const calendarKeys = <String>[
    'calendar',
    'day_mo',
    'day_di',
    'day_mi',
    'day_do',
    'day_fr',
    'day_sa',
    'day_so',
    'today_button',
    'quick_add_hint',
    'no_events_today',
    'event_added',
    'new_event',
    'quick_template',
    'save_btn',
    'sync_btn',
    'cancel',
    'delete_action',
    'rename',
    'rename_person',
    'save',
    'finance_save',
    // calendar_* Keys (Audit)
    'calendar_add_person',
    'calendar_add',
    'calendar_delete_event',
    'calendar_delete_event_confirm',
    'calendar_event_deleted',
    'calendar_new_person',
    'calendar_person',
    'calendar_person_parents',
    'calendar_person_kindergarten',
    'calendar_person_birthday',
    'calendar_public_holiday',
    'calendar_holidays_title',
    'calendar_country',
    'calendar_region',
    'calendar_choose_region',
    'calendar_edit',
    'calendar_jump_to_day',
    'calendar_edit_event',
    'calendar_field_title',
    'calendar_field_title_hint',
    'calendar_title_required',
    'calendar_field_for_whom',
    'calendar_field_start',
    'calendar_field_end',
    'calendar_field_brings',
    'calendar_field_picks_up',
    'calendar_person_nobody',
    'calendar_person_mum',
    'calendar_person_dad',
    'calendar_person_grandma',
    'calendar_person_grandpa',
    'calendar_person_other',
    'calendar_field_prep',
    'calendar_field_prep_hint',
    'calendar_field_recurrence',
    'calendar_field_reminder',
    'calendar_field_ends',
    'calendar_recurrence_once',
    'calendar_recurrence_daily',
    'calendar_recurrence_weekly',
    'calendar_recurrence_monthly',
    'calendar_recurrence_yearly',
    'calendar_end_never',
    'calendar_end_count',
    'calendar_end_pick_date',
    'calendar_reminder_smart',
    'calendar_reminder_smart_short',
    'calendar_reminder_none',
    'calendar_reminder_before',
    'calendar_pick_end_date',
    'calendar_ends_on',
    'calendar_ends_after_count',
    'calendar_offline_mode',
    'calendar_no_events_count',
    'calendar_events_count',
    'calendar_tap_to_add',
    'calendar_school_holiday',
    'calendar_this_week',
    'calendar_person_hint',
    'calendar_new_name_hint',
    'calendar_delete_person_title',
    'calendar_delete_person_body',
    'calendar_badge_brings',
    'calendar_badge_picks_up',
    'calendar_pack_tomorrow',
    'calendar_pack_dont_forget',
    'calendar_quick_add_bad_time',
    'calendar_quick_add_bad_date',
    'calendar_quick_add_failed',
    'calendar_sync_title',
    'calendar_sync_desc_on',
    'calendar_sync_desc_off',
    'calendar_holidays_until',
    'calendar_template_pediatrician',
    'calendar_template_dentist',
    'calendar_template_parent_teacher',
    'calendar_template_birthday',
    'calendar_template_swimming',
    'calendar_template_daycare_event',
    'calendar_template_sport',
    'calendar_template_vaccination',
  ];

  group('Calendar i18n completeness', () {
    test('alle Kalender-Keys existieren in jeder Picker-Sprache', () {
      final missing = <String>[];
      for (final lang in AppLanguages.supported) {
        final map = AppStringsManager.allStrings[lang.code];
        expect(map, isNotNull,
            reason: 'Sprachblock fehlt komplett: ${lang.code}');
        for (final key in calendarKeys) {
          if (map == null || !map.containsKey(key)) {
            missing.add('${lang.code}:$key');
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'Fehlende Übersetzungen:\n${missing.join('\n')}');
    });

    test('Platzhalter-Keys enthalten ihre Tokens', () {
      // Keys mit Platzhaltern müssen den jeweiligen Token behalten.
      const tokenChecks = {
        'calendar_delete_event_confirm': '{title}',
        'calendar_end_count': '{n}',
        'calendar_reminder_before': '{n}',
        'calendar_ends_after_count': '{n}',
        'calendar_delete_person_title': '{name}',
        'calendar_badge_brings': '{name}',
        'calendar_badge_picks_up': '{name}',
        'calendar_events_count': '{n}',
        'calendar_pack_tomorrow': '{title}',
        'calendar_pack_dont_forget': '{note}',
        'calendar_holidays_until': '{year}',
      };
      for (final lang in AppLanguages.supported) {
        final map = AppStringsManager.allStrings[lang.code]!;
        tokenChecks.forEach((key, token) {
          final value = map[key];
          if (value != null) {
            expect(value.contains(token), isTrue,
                reason: '${lang.code}:$key fehlt Token $token');
          }
        });
      }
    });
  });
}
