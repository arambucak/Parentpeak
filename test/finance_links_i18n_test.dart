import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/config/country_finance_data.dart';

/// Schützt die Familien-Geld-Kachel vor Rückfällen bei (a) bekannt-toten Links
/// und (b) fehlenden i18n-Keys. Reiner Datentest, kein Widget-/Netzzugriff.
void main() {
  group('Keine bekannt-toten Links im Familien-Geld-Code', () {
    // URLs, die im Audit als 404 / tot bestätigt wurden. Sie dürfen nirgends
    // mehr im lib/-Code auftauchen.
    const deadUrls = [
      'web.arbeitsagentur.de/ofa/kindergeld',
      'web.arbeitsagentur.de/ofa/kiz',
      'bmf.gv.at/themen/steuern/privatpersonen/kinderbetreuungskosten',
      'caritas.de/hilfeundberatung/onlineberatung/sozialedienste',
      'tafel.de/infos-hilfe/tafel-suche',
      'verbraucherzentrale.de/themen/geld-versicherungen/kredit-und-schulden/schuldnerberatung',
      'caritas.at/hilfe-einrichtungen/beratung',
      'foodbankingeurope.org',
      'www.tafel.at',
    ];

    final financeFiles = [
      'lib/ui/familien_geld_screen.dart',
      'lib/config/country_finance_data.dart',
      'lib/config/benefit_application_de.dart',
    ];

    test('keine der toten URLs kommt im Code vor', () {
      final findings = <String>[];
      for (final path in financeFiles) {
        final content = File(path).readAsStringSync();
        for (final dead in deadUrls) {
          if (content.contains(dead)) {
            findings.add('$path enthält tote URL: $dead');
          }
        }
      }
      expect(findings, isEmpty, reason: findings.join('\n'));
    });

    test('alle kuratierten Benefit-URLs sind absolut https', () {
      for (final country in CountryFinanceData.availableCountries) {
        for (final b in country.benefits) {
          final url = b.url;
          if (url != null && url.isNotEmpty) {
            expect(url.startsWith('https://'), isTrue,
                reason: '${country.code}/${b.id}: $url ist nicht https');
          }
        }
      }
    });
  });

  group('i18n: Familien-Geld-Schlüssel in allen Hauptsprachen', () {
    const mainLanguages = ['de', 'en', 'tr', 'ku'];
    const requiredKeys = [
      'no_answer',
      'yes_answer',
      'finance_amounts_disclaimer',
      'finance_link_open_failed',
      'finance_legal_disclaimer',
    ];

    test('jeder Pflicht-Key existiert und ist nicht leer', () {
      final missing = <String>[];
      for (final lang in mainLanguages) {
        for (final key in requiredKeys) {
          final value = AppStringsManager.getString(lang, key);
          // getString gibt bei fehlendem Key den Key selbst zurück.
          if (value == key || value.trim().isEmpty) {
            missing.add('$lang fehlt/leer: $key');
          }
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('Kindergeld-Betrag ist aktualisiert (259€, nicht 250€)', () {
      // Betrag steckt im Pipe-String finance_benefit_de_kindergeld (de)
      // und in der Länder-Config.
      final de = AppStringsManager.getString('de', 'finance_benefit_de_kindergeld');
      expect(de.contains('259'), isTrue, reason: 'i18n DE nicht aktualisiert: $de');
      expect(de.contains('250€'), isFalse, reason: 'alter Betrag noch da: $de');

      final kindergeld = CountryFinanceData.germany.benefits
          .firstWhere((b) => b.id == 'kindergeld');
      expect(kindergeld.amount, contains('259'));
    });
  });
}
