import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/data/eltern_wissen_data.dart';
import 'package:parentpeak/l10n/eltern_wissen_localizations.dart';

/// Verifiziert, dass die Eltern-Wissen-FAQ für FR/ES/IT vollständig und
/// strukturerhaltend lokalisiert ist (AR separat geprüft, siehe unten).
void main() {
  // Sprachen mit vollständiger FAQ-Übersetzung (alle 32 Einträge).
  const fullLanguages = ['fr', 'es', 'it', 'ar'];

  group('Eltern-Wissen FAQ-Lokalisierung', () {
    for (final lang in fullLanguages) {
      test('$lang: alle Einträge übersetzt und strukturerhaltend', () {
        for (final entry in elternWissenData) {
          final localized = localizeElternWissenEntry(entry, lang);

          // Struktur: id, tags, category, Altersgrenzen unverändert.
          expect(localized.id, entry.id);
          expect(localized.tags, entry.tags, reason: '$lang/${entry.id}: tags');
          expect(
            localized.category,
            entry.category,
            reason: '$lang/${entry.id}: category',
          );
          expect(localized.minAge, entry.minAge);
          expect(localized.maxAge, entry.maxAge);

          // Gleiche Anzahl Handlungsschritte.
          expect(
            localized.aktion.length,
            entry.aktion.length,
            reason: '$lang/${entry.id}: Anzahl aktion weicht ab',
          );

          // Tatsächlich übersetzt: question, akut, beduerfnis, gfkSatz,
          // ermutigung weichen vom deutschen Original ab und sind nicht leer.
          for (final pair in <List<String>>[
            ['question', entry.question, localized.question],
            ['akut', entry.akut, localized.akut],
            ['beduerfnis', entry.beduerfnis, localized.beduerfnis],
            ['gfkSatz', entry.gfkSatz, localized.gfkSatz],
            ['ermutigung', entry.ermutigung, localized.ermutigung],
          ]) {
            expect(
              pair[2].trim(),
              isNotEmpty,
              reason: '$lang/${entry.id}: ${pair[0]} leer',
            );
            expect(
              pair[2],
              isNot(pair[1]),
              reason: '$lang/${entry.id}: ${pair[0]} noch deutsch',
            );
          }
        }
      });
    }

    test('unbekannte Sprache behält den deutschen Eintrag', () {
      final entry = elternWissenData.first;
      final fallback = localizeElternWissenEntry(entry, 'xx');
      expect(fallback.question, entry.question);
      expect(fallback.akut, entry.akut);
    });

    test('Deutsch (de) bleibt unverändert (kein Eintrag in der Map)', () {
      final entry = elternWissenData.first;
      final de = localizeElternWissenEntry(entry, 'de');
      expect(de.question, entry.question);
    });
  });
}
