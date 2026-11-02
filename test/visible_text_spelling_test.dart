import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/models/family_profile_model.dart';

const launchLanguages = ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];

// Bekannte ASCII-Umschreibungen, die in sichtbaren Texten nie auftauchen dürfen.
final _transliterations = RegExp(
  r'\b(Frueh\w*|frueh(?!stueck\b)\w*|Maedchen|Fuer|fuer|Ueber\w*|ueber\w*|'
  r'Grossfamilie|Grosseltern|Religioes|Unvertraeglich\w*|\w*stoerung|'
  r'gueltig\w*|Ungueltig\w*|\w*bestaetig\w*|\w*Bestaetig\w*|hinzuf[u]egen|'
  r'Geraete?n?|Privatsphaere|persoenlich\w*|Persoenlich|moeglich\w*|'
  r'Tuerkce|Turkce|Francais|Espanol|Russkij|Portugues|Ukrainska|Romana|'
  r'Bulgarski|Ellinika|Zhongwen|Nihongo|Hangugeo|Tieng Viet|Kurdi)\b',
);

// Autonyme und Eigennamen, die in allen Sprachen gleich lauten dürfen.
const _sameAsEnglishAllowed = {
  'language': null, // alle Sprachnamen sind bewusst Autonyme
  'values': {'montessori', 'waldorf', 'pikler'},
  'family': {'patchwork', 'co_parenting'},
  'looking': <String>{},
  'child': <String>{},
  'specials': <String>{},
  'days': <String>{},
  'times': <String>{},
  'gender': <String>{},
};

// Geprüfte Einzelfälle, bei denen das Wort in der Zielsprache korrekt gleich lautet.
const _sameAsEnglishVerified = {
  'tr/values/feministisch', // türkisch "Feminist"
};

void main() {
  test('visible launch-language strings contain no ASCII transliterations', () {
    final offenders = <String>[];
    for (final language in launchLanguages) {
      final strings = AppStringsManager.allStrings[language]!;
      strings.forEach((key, value) {
        final match = _transliterations.firstMatch(value);
        if (match != null) offenders.add('$language/$key: ${match[0]}');
      });
    }
    for (final group in MatchOptions.fallbackLabels.entries) {
      group.value.forEach((code, label) {
        final match = _transliterations.firstMatch(label);
        if (match != null) {
          offenders.add('model/${group.key}/$code: ${match[0]}');
        }
      });
    }
    expect(offenders, isEmpty);
  });

  test('transliteration detector catches known regressions', () {
    for (final sample in [
      'Frueh (6–09)',
      '👧 Maedchen',
      'Fuer wen?',
      '🇹🇷 Tuerkce',
      'Kurdi',
      'Ungueltiger QR-Teil',
    ]) {
      expect(_transliterations.hasMatch(sample), isTrue, reason: sample);
    }
    for (final sample in ['Früh', 'Mädchen', 'Türkçe', 'Kurdî (Kurmancî)']) {
      expect(_transliterations.hasMatch(sample), isFalse, reason: sample);
    }
  });

  test('UI source literals contain no ASCII transliterations of labels', () {
    final pattern = RegExp(
      r"""['"][^'"\n]*\b(Frueh|Maedchen|Fuer|Grossfamilie|Religioes|"""
      r"""Tuerkce|Francais|Espanol|Russkij|Zhongwen|Ungueltig\w*|"""
      r"""Privatsphaere|Geraete)\b[^'"\n]*['"]""",
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (pattern.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  for (final language in launchLanguages) {
    test('network wizard labels are localized for $language', () {
      for (final group in MatchOptions.fallbackLabels.entries) {
        for (final code in group.value.keys) {
          final key = 'network_option_${group.key}_$code';
          final label = MatchOptions.localizedLabel(language, group.key, code);
          expect(label.trim(), isNotEmpty, reason: '$language/$key');
          expect(
            AppStringsManager.getString(language, key),
            isNot(key),
            reason: 'missing $language/$key',
          );
          if (language == 'en') continue;
          final allowed = _sameAsEnglishAllowed[group.key];
          if (allowed == null || allowed.contains(code)) continue;
          if (_sameAsEnglishVerified.contains('$language/${group.key}/$code')) {
            continue;
          }
          expect(
            label,
            isNot(MatchOptions.localizedLabel('en', group.key, code)),
            reason: 'English copy in $language/$key',
          );
        }
      }
    });
  }

  test('language options use one autonym across all launch languages', () {
    for (final code in MatchOptions.languageLabels.keys) {
      final expected = MatchOptions.languageLabels[code];
      for (final language in launchLanguages) {
        expect(
          MatchOptions.localizedLabel(language, 'language', code),
          expected,
          reason: '$language/$code',
        );
      }
    }
    expect(MatchOptions.languageLabels['ku'], 'Kurdî (Kurmancî)');
    expect(MatchOptions.languageLabels['sr'], contains('Srpski'));
  });

  test('stored option codes stay unchanged', () {
    expect(MatchOptions.genderLabels.keys, containsAll(['maennlich']));
    expect(MatchOptions.timeOptions, contains('morgens'));
    expect(MatchOptions.familyForms, contains('grossfamilie'));
    expect(MatchOptions.valueOptions, contains('religioes'));
    expect(MatchOptions.specialOptions, contains('fruehchen'));
    expect(MatchOptions.localizedLabel('de', 'gender', 'maennlich'),
        isNot('maennlich'));
  });
}
