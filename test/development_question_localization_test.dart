import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/models/child_development_data.dart';
import 'package:parentpeak/l10n/development_question_localizations.dart';

/// Verifiziert, dass der Entwicklungs-Check-Fragenkatalog für alle
/// Nicht-Deutsch-Sprachen vollständig lokalisiert ist: gleiche Struktur wie
/// das deutsche Original, aber abweichender (= übersetzter) Text.
void main() {
  const ageGroups = [
    '0-12m',
    '1-2y',
    '2-3y',
    '3-4y',
    '4-6y',
    '6-10y',
    '10-14y',
    '14-18y',
  ];

  // Sprachen mit vollständiger Fragenkatalog-Übersetzung.
  const translatedLanguages = ['en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];

  group('Entwicklungs-Check Fragenkatalog-Lokalisierung', () {
    for (final lang in translatedLanguages) {
      test('$lang: jede Altersgruppe strukturerhaltend und übersetzt', () {
        for (final ageGroup in ageGroups) {
          final german = DevelopmentQuestionBank.getQuestionsForAge(ageGroup);
          final localized = localizeDevelopmentDomains(german, lang, ageGroup);

          // Gleiche Anzahl Bereiche.
          expect(
            localized.length,
            german.length,
            reason: '$lang/$ageGroup: Bereichsanzahl weicht ab',
          );

          for (var i = 0; i < german.length; i++) {
            final g = german[i];
            final l = localized[i];

            // Struktur bleibt erhalten: id/emoji/color unverändert,
            // Fragen- und Tipp-Anzahl identisch.
            expect(l.id, g.id, reason: '$lang/$ageGroup: id verschoben');
            expect(l.emoji, g.emoji, reason: '$lang/$ageGroup/${g.id}: emoji');
            expect(
              l.questions.length,
              g.questions.length,
              reason: '$lang/$ageGroup/${g.id}: Fragenanzahl weicht ab',
            );
            expect(
              l.tips.length,
              g.tips.length,
              reason: '$lang/$ageGroup/${g.id}: Tippanzahl weicht ab',
            );

            // Tatsächlich übersetzt: Titel und alle Fragen weichen vom
            // deutschen Original ab (kein stiller Deutsch-Fallback).
            expect(
              l.title,
              isNot(g.title),
              reason: '$lang/$ageGroup/${g.id}: Titel noch deutsch',
            );
            for (var q = 0; q < g.questions.length; q++) {
              expect(
                l.questions[q],
                isNot(g.questions[q]),
                reason: '$lang/$ageGroup/${g.id}: Frage $q noch deutsch',
              );
              expect(
                l.questions[q].trim(),
                isNotEmpty,
                reason: '$lang/$ageGroup/${g.id}: Frage $q leer',
              );
            }
          }
        }
      });
    }

    test('unbekannte Sprache fällt sauber auf Deutsch zurück', () {
      final german = DevelopmentQuestionBank.getQuestionsForAge('2-3y');
      final fallback = localizeDevelopmentDomains(german, 'xx', '2-3y');
      expect(fallback.first.title, german.first.title);
    });
  });
}
