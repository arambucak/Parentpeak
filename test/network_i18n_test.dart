import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'dart:io';

void main() {
  const languages = ['de', 'en', 'tr', 'ku', 'ar', 'ru', 'uk', 'es', 'fr', 'it', 'pt'];
  const keys = [
    'network_connect', 'network_cancel', 'network_connect_button',
    'network_friends', 'network_playmates', 'network_invite',
    'network_coins_until', 'network_invites_successful', 'network_coin_value',
    'network_coins_secured', 'network_invite_share', 'network_invite_share_hint',
    'network_qr_show', 'network_qr_hint', 'network_link_copy',
    'network_check_coins', 'network_check_coins_hint', 'network_setup_hint',
    'network_login_required', 'network_empty_title', 'network_empty_description',
    'network_invite_playmates', 'network_same_city', 'network_request_sent',
    'network_request_failed', 'network_invite_hero_title',
    'network_invite_hero_description', 'network_share', 'network_save',
    'network_create_profile', 'network_name_hint', 'network_name_example',
    'network_location_hint', 'network_family_form', 'network_custom',
    'network_custom_family', 'network_custom_example', 'network_no_gender',
    'network_values_tip', 'network_bio_title', 'network_bio_hint',
    'network_step_1', 'network_step_2', 'network_step_3', 'network_step_4',
    'network_step_5', 'network_gender_maennlich', 'network_gender_weiblich',
    'network_gender_divers', 'network_reason_nearby', 'network_reason_same_city',
    'network_reason_shared_interests', 'network_reason_similar_child_age',
    'network_reason_shared_languages', 'network_reason_shared_values',
    'network_reason_shared_family_form',
  ];
  const coreKeys = [
    'family_default', 'invite_expired', 'share_failed', 'link_create_failed',
    'qr_create_failed', 'share_message', 'qr_code', 'request_count',
    'friends_connected', 'outgoing_requests', 'blocked_name', 'report', 'block',
    'remove', 'hello', 'profile_active', 'scope_10km', 'scope_50km',
    'scope_100km', 'scope_all', 'match_score', 'family_name', 'child_title',
    'child_name_label', 'child_name_hint', 'custom_interest_hint',
    'values_title', 'values_hint', 'looking_for_title', 'looking_for_hint',
    'availability_title', 'availability_hint', 'languages_title', 'specials_title',
    'specials_hint', 'save_failed', 'validation_name', 'validation_district',
    'age_months', 'age_years', 'age_years_months', 'active', 'gdpr_compliant',
    'terms_subtitle', 'licenses_subtitle', 'blocked_count', 'contact_email',
    'moderation', 'moderation_subtitle', 'crashlytics_test',
    'crashlytics_subtitle', 'logout_message', 'imprint_provider', 'imprint_owner',
    'imprint_address', 'imprint_email', 'imprint_content_owner', 'beta_notice',
    'ai_intro', 'ai_parenting_title', 'ai_parenting_desc', 'ai_recipe_title',
    'ai_recipe_desc', 'ai_events_title', 'ai_events_desc', 'ai_review_title',
    'ai_review_desc', 'ai_basis', 'ai_basis_items', 'ai_warning_items',
    'tile_moved_up', 'premium_feature_template', 'export_copied',
  ];

  test('network copy is native and complete for each supported locale', () {
    for (final language in languages) {
      for (final key in keys) {
        final value = AppStringsManager.getString(language, key);
        expect(value, isNotEmpty, reason: '$language/$key must not be empty');
        expect(value, isNot(key), reason: '$language/$key must be translated');
      }
    }
  });

  test('invite hero title has the expected native copy', () {
    expect(AppStringsManager.getString('de', 'network_invite_hero_title'),
        'Freunde einladen');
    expect(AppStringsManager.getString('en', 'network_invite_hero_title'),
        'Invite friends');
    expect(AppStringsManager.getString('ar', 'network_invite_hero_title'),
        'ادعوا الأصدقاء');
  });

  test('core copy used by the target screens is directly complete', () {
    for (final language in languages) {
      for (final key in coreKeys) {
        expect(AppStringsManager.hasCoreTranslation(language, key), isTrue,
            reason: '$language/$key must be present in the core table');
      }
    }
    expect(AppStringsManager.coreString('de', 'invite_expired'),
        'Dieser Link ist nicht mehr aktiv. Bitte nutze den Einladungslink der anderen Familie.');
    expect(AppStringsManager.coreString('en', 'hello'), 'Say hello');
    expect(AppStringsManager.coreString('ar', 'hello'), 'قول مرحبًا');
  });

  test('package 1 screens contain no direct static UI text', () {
    const files = [
      'lib/ui/home_screen.dart',
      'lib/ui/profile_safety_screen.dart',
      'lib/ui/eltern_netzwerk_screen.dart',
    ];
    final directText = RegExp(
      r"""(?:Text|TextSpan|SelectableText)\s*\(\s*(?:const\s+)?['"][^$'"]+['"]""",
    );

    for (final path in files) {
      final matches = directText.allMatches(File(path).readAsStringSync());
      for (final match in matches) {
        final value = match.group(0)!;
        final isBrandName = value.endsWith("'Parentpeak'") ||
            value.endsWith('"Parentpeak"');
        expect(
          isBrandName ||
              RegExp(r'''['"](?:\\u\{[0-9A-Fa-f]+\}|[+\-])['"]$''')
                  .hasMatch(value),
          isTrue,
          reason: '$path contains direct UI text: $value',
        );
      }
    }
  });
}