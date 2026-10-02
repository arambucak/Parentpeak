import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/ritual_ruhe_screen.dart';

void main() {
  test('giveaway feed, detail and upload resolve every literal key in Kurmanji', () {
    final ku = AppLocalizations(const Locale('ku'));
    final en = AppLocalizations(const Locale('en'));
    final keys = <String>{};
    for (final path in [
      'lib/ui/treasure_handover_screen.dart',
      'lib/ui/treasure_upload_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      keys.addAll(RegExp(r"'((?:treasure)[A-Za-z0-9_]+)'")
          .allMatches(source)
          .map((match) => match.group(1)!));
    }
    for (final key in keys) {
      expect(ku.t(key), isNot(key), reason: 'Missing Kurdish $key');
      expect(ku.t(key), isNot(en.t(key)), reason: 'English fallback for $key');
    }
  });

  test('ritual empty state and greeting resolve in Kurmanji', () {
    for (final key in [
      'ritual_morning',
      'ritual_evening',
      'ritual_empty_title',
      'ritual_empty_description',
      'ritual_empty_action',
    ]) {
      expect(AppStringsManager.getString('ku', key),
          isNot(AppStringsManager.getString('de', key)));
    }
  });

  test('Ritual UI keys and built-in steps have Kurmanji values', () {
    final source = File('lib/ui/ritual_ruhe_screen.dart').readAsStringSync();
    final keys = RegExp(r"_t\('(ritual_[a-z_]+)'\)")
        .allMatches(source).map((match) => match.group(1)!).toSet();
    for (final key in keys) {
      expect(AppStringsManager.allStrings['ku']?[key], isNotEmpty,
          reason: 'Missing Kurmanji Ritual $key');
    }
    final steps = RegExp(
      r"_RitualStep\('[^']+',\s*'([^']+)',\s*Icons\.[^,]+,\s*'([^']+)'",
    ).allMatches(source).toList();
    expect(steps.length, greaterThan(20));
    for (final step in steps) {
      for (final original in [step.group(1)!, step.group(2)!]) {
        expect(ritualStepCopy('ku', original), isNot(original),
            reason: 'Untranslated built-in Ritual step: $original');
      }
    }
  });

  test('network wizard choices for all five steps display Kurmanji', () {
    final groups = <String, Iterable<String>>{
      'family': MatchOptions.familyForms,
      'child': MatchOptions.childInterests,
      'values': MatchOptions.valueOptions,
      'looking': MatchOptions.lookingForOptions,
      'days': MatchOptions.dayOptions,
      'times': MatchOptions.timeOptions,
      'specials': MatchOptions.specialOptions,
      'language': MatchOptions.languageLabels.keys,
    };
    for (final entry in groups.entries) {
      for (final code in entry.value) {
        expect(networkWizardOptionLabel('ku', entry.key, code, 'German'),
            isNot('German'), reason: '${entry.key}/$code');
      }
    }
  });
}