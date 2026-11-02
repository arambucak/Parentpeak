import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/models/family_profile_model.dart';

const launchLanguages = ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];

// Bekannte ASCII-Umschreibungen, die in sichtbaren Texten nie auftauchen dürfen.
final _transliterations = RegExp(
  r'\b(Frueh\w*|frueh(?!stueck\b)\w*|Maedchen|Fuer|fuer|Ueber\w*|ueber\w*|'
  r'Grossfamilie|Grosseltern|Religioes|Unvertraeglich\w*|\w*stoerung|'
  r'gueltig\w*|[Uu]ngueltig\w*|\w*bestaetig\w*|\w*Bestaetig\w*|hinzuf[u]egen|'
  r'Geraete?n?|Privatsphaere|persoenlich\w*|Persoenlich|moeglich\w*|'
  r'\w*(?:[Rr]ueck|[Zz]urueck|[Pp]ruef|[Ll]oesch|[Aa]ender|[Oo]effn|'
  r'[Gg]roess|[Vv]erfueg|[Ww]aehl|[Mm]oeglich|[Gg]efuehl|[Kk]uend)\w*|'
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
      'ungueltige Backend-Antwort',
      'Rueckerstattung',
      'Jahresrueckblick',
      'Zurueck',
      'Pruefen...',
      'Loeschung',
      'Aenderung',
      'Oeffnen',
      'Groesse',
      'Verfuegbar',
      'Waehlen',
      'Moeglich',
      'Gefuehl',
      'Kuendigen',
    ]) {
      expect(_transliterations.hasMatch(sample), isTrue, reason: sample);
    }
    for (final sample in [
      'Früh',
      'Mädchen',
      'Türkçe',
      'Kurdî (Kurmancî)',
      'Rückerstattung',
      'Jahresrückblick',
      'Prüfen',
    ]) {
      expect(_transliterations.hasMatch(sample), isFalse, reason: sample);
    }
  });

  test('source literals contain no ASCII transliterations of visible text', () {
    final literals = RegExp(r"""'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*" """.trim());
    // Search/OCR terms and persisted option codes are not displayed labels.
    const intentional = <String, Set<String>>{
      'lib/data/eltern_wissen_data.dart': {'pruefung', 'ueberfordert'},
      'lib/logic/marketplace_service.dart': {'pruefung'},
      'lib/logic/pedagogical_chat_backend.dart': {
        'anleitung fuer',
        'ich bin ueberfordert',
      },
      'lib/models/family_profile_model.dart': {'fruehchen'},
      'lib/ui/chat_screen.dart': {'moeglicher grund:'},
      'lib/ui/finance_budget_screen.dart': {'rueckgeld'},
    };
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') ||
            line.startsWith('import ') ||
            line.startsWith('export ') ||
            line.startsWith('part ')) {
          continue;
        }
        for (final literal in literals.allMatches(line)) {
          final value = literal[0]!.substring(1, literal[0]!.length - 1);
          if (value.startsWith('https://') ||
              value.startsWith('http://') ||
              (intentional[file.path]?.contains(value) ?? false)) {
            continue;
          }
          final match = _transliterations.firstMatch(value);
          if (match != null) {
            offenders.add('${file.path}:${i + 1}: ${match[0]}');
          }
        }
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
