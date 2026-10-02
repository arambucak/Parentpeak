import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/models/meetup_event.dart';

void main() {
  const strings = AppStringsManager.allStrings;
  final eventKeys = strings.values
      .expand((locale) => locale.keys)
      .where((key) => key.startsWith('event_') || key.startsWith('events_'))
      .toSet();
  final placeholders = RegExp(r'\{[^{}]+\}');
  List<String> tokens(String text) =>
      placeholders.allMatches(text).map((match) => match.group(0)!).toList()
        ..sort();

  for (final language in AppLanguages.supported) {
    test(
      '${language.code}: explicit event translations and placeholder parity',
      () {
        final locale = strings[language.code]!;
        final resolved = AppLocalizations(Locale(language.code));
        final missing = eventKeys
            .where((key) => locale[key]?.trim().isNotEmpty != true)
            .toList();
        expect(
          missing,
          isEmpty,
          reason: '${language.code}: ${missing.join(', ')}',
        );
        for (final key in eventKeys) {
          expect(
            tokens(locale[key]!),
            tokens(strings['en']![key]!),
            reason: '${language.code}:$key',
          );
          expect(
            resolved.t(key),
            locale[key],
            reason: '${language.code}:$key resolved',
          );
        }
        expect(eventKeys.length, greaterThanOrEqualTo(172));
      },
    );
  }

  test('event enum labels exist in every registered locale', () {
    for (final language in AppLanguages.supported) {
      final locale = strings[language.code]!;
      for (final mode in ParticipationMode.values) {
        expect(
          locale['event_mode_${mode.name}'],
          isNotEmpty,
          reason: language.code,
        );
      }
      for (final category in EventCategory.values) {
        final key = category == EventCategory.socialGathering
            ? 'event_category_social'
            : 'event_category_${category.name}';
        expect(locale[key], isNotEmpty, reason: '${language.code}:$key');
      }
      for (final age in AgeGroup.values) {
        expect(
          locale['event_age_${age.name}'],
          isNotEmpty,
          reason: language.code,
        );
      }
    }
  });

  test('Kurmanci and Sorani use distinct scripts', () {
    final arabic = RegExp(r'[\u0600-\u06ff]');
    for (final key in [
      'event_host',
      'event_shared_by',
      'event_mode_direct',
      'event_interest_not_booking',
      'event_series_follow_hint',
      'event_scan_datetime_required',
    ]) {
      expect(arabic.hasMatch(strings['ku']![key]!), isFalse, reason: key);
      expect(arabic.hasMatch(strings['ckb']![key]!), isTrue, reason: key);
    }
  });

  test('new event workflows are genuinely localized, not English copies', () {
    for (final language in AppLanguages.supported.where(
      (language) => language.code != 'en',
    )) {
      for (final key in [
        'event_interest_not_booking',
        'event_pending_preserved',
        'event_status_failed',
        'event_owner_save_failed',
        'event_owner_delete_message',
        'event_series_follow_hint',
        'event_scan_datetime_required',
      ]) {
        expect(
          strings[language.code]![key],
          isNot(strings['en']![key]),
          reason: '${language.code}:$key',
        );
      }
    }
  });

  test('owned event screens use explicit translated event keys', () {
    for (final path in [
      'lib/ui/event_detail_screen.dart',
      'lib/ui/event_edit_sheet.dart',
      'lib/ui/widgets/event_host_identity.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final match in RegExp(
        r"'(events?_[A-Za-z0-9_]+)'",
      ).allMatches(source)) {
        for (final language in AppLanguages.supported) {
          expect(
            strings[language.code]!.containsKey(match.group(1)),
            isTrue,
            reason: '${language.code}:${match.group(1)}',
          );
        }
      }
      expect(source, isNot(contains("'event_mode_\${")));
    }
  });
}
