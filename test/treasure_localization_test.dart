import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';

/// Stellt sicher, dass die Verschenkmarkt-UI-Keys (TreasureHandover/Upload)
/// für FR/ES/IT/AR tatsächlich übersetzt sind und NICHT auf Englisch oder
/// Deutsch zurückfallen.
void main() {
  // Repräsentative, in den Screens sichtbare Keys (Titel, CTAs, Labels),
  // mit dem bisher gezeigten englischen/deutschen Fallback-Text.
  const samples = <String, String>{
    'treasureReserveTitle': 'Plan handover',
    'treasureDateOrSwap': 'Quick meetup or quiet swap',
    'treasureFeedEmptyTitle': 'No treasures near you yet',
    'treasureFeedEmptyText':
        'Start with the first item your family is ready to pass on.',
    'treasureTakePhoto': 'Take photo',
    'treasureChooseFromLibrary': 'From library',
    'treasureAiTitle': 'Quickly recognized',
    'treasureAiAccept': 'Use suggestion',
    'treasureUploadSubtitle': 'One photo is enough to start',
    'treasurePhotoSectionHint': 'Show the item just as it is right now.',
    'treasureUploadHeadline': 'Teile, was bei euch nicht mehr gebraucht wird',
    'treasureCategoryLabel': 'Kategorie',
    'treasureConditionLabel': 'Zustand',
  };

  // "Color" ist auf Spanisch korrekt identisch zum Englischen — hier wird nur
  // geprüft, dass der Key existiert und nicht leer ist, nicht die Abweichung.
  const existenceOnly = <String>['treasureColorLabel'];

  AppLocalizations l10nFor(String lang) => AppLocalizations(Locale(lang));

  group('Verschenkmarkt (treasure) Lokalisierung', () {
    for (final lang in ['fr', 'es', 'it', 'ar']) {
      test('$lang: Schlüssel-Keys weder englisch noch deutsch', () {
        final l10n = l10nFor(lang);
        samples.forEach((key, fallbackText) {
          final value = l10n.t(key);
          expect(
            value,
            isNotEmpty,
            reason: '$lang/$key ist leer',
          );
          expect(
            value,
            isNot(key),
            reason: '$lang/$key liefert den Rohschlüssel (kein Wert)',
          );
          expect(
            value,
            isNot(fallbackText),
            reason: '$lang/$key fällt noch auf EN/DE zurück: "$value"',
          );
        });
        for (final key in existenceOnly) {
          final value = l10n.t(key);
          expect(value, isNotEmpty, reason: '$lang/$key ist leer');
          expect(value, isNot(key),
              reason: '$lang/$key liefert den Rohschlüssel');
        }
      });
    }

    test('en/de behalten den englischen bzw. ihren Wert', () {
      // treasureCategoryLabel hatte keinen EN-Wert -> jetzt "Category".
      expect(l10nFor('en').t('treasureCategoryLabel'), 'Category');
      expect(l10nFor('en').t('treasureConditionLabel'), 'Condition');
    });
  });
}
