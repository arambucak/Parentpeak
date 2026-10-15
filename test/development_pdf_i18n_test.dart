import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

void main() {
  // Alle neuen i18n-Keys für PDF-Export + KI-Report-Labels.
  const requiredKeys = <String>[
    'development_consent_save_failed',
    'development_report_special_needs',
    'dev_answer_yes',
    'dev_answer_sometimes',
    'dev_answer_not_yet',
    'pdf_report_title',
    'pdf_created_on',
    'pdf_progress_title',
    'pdf_compare_with',
    'pdf_ai_report_title',
    'pdf_disclaimer',
    'pdf_legend_current',
    'pdf_legend_previous',
    'pdf_trend_up',
    'pdf_trend_down',
    'pdf_trend_stable',
    'pdf_footer',
    'pdf_page_of',
    'pdf_filename_prefix',
    'pdf_age_years',
    'pdf_age_years_months',
    'pdf_default_child_name',
  ];

  group('PDF/Report i18n Keys', () {
    test('Bericht-Consent benennt Google Gemini in de/en/tr/ku explizit', () {
      for (final lang in ['de', 'en', 'tr', 'ku']) {
        final body =
            AppStringsManager.allStrings[lang]!['development_consent_body'];
        expect(body, isNotNull, reason: '$lang braucht einen eigenen Consent');
        expect(
          body,
          contains('Google Gemini'),
          reason: '$lang muss den KI-Empfaenger offenlegen',
        );
      }
    });

    test('Bericht-Consent benennt Google Gemini in allen fertigen Sprachen',
        () {
      // fr/es/it/ar haben jetzt eine eigene Übersetzung (statt EN-Fallback);
      // der KI-Empfänger muss in jeder davon offengelegt bleiben.
      for (final lang in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
        final body = AppStringsManager.getString(
          lang,
          'development_consent_body',
        );
        expect(
          body,
          contains('Google Gemini'),
          reason: '$lang muss den KI-Empfaenger offenlegen',
        );
      }
    });

    test('Deutsch definiert alle neuen Keys nicht-leer', () {
      for (final key in requiredKeys) {
        final value = AppStringsManager.getString('de', key);
        expect(value, isNotEmpty, reason: 'de fehlt Key: $key');
        // getString gibt bei fehlendem Key den Key selbst zurück.
        expect(
          value,
          isNot(key),
          reason: 'de hat keinen echten Wert für: $key',
        );
      }
    });

    test('Englisch definiert alle neuen Keys nicht-leer (Fallback-Quelle)', () {
      for (final key in requiredKeys) {
        final value = AppStringsManager.getString('en', key);
        expect(value, isNotEmpty, reason: 'en fehlt Key: $key');
        expect(
          value,
          isNot(key),
          reason: 'en hat keinen echten Wert für: $key',
        );
      }
    });

    test('Alle fertigen Sprachen definieren jeden PDF-Key eigenständig', () {
      // fr/es/it/ar sind jetzt vollständig übersetzt und dürfen für diese
      // Keys nicht mehr auf den englischen Fallback (oder den rohen Key)
      // zurückfallen.
      for (final lang in ['fr', 'es', 'it', 'ar']) {
        for (final key in requiredKeys) {
          final value = AppStringsManager.allStrings[lang]![key];
          expect(
            value,
            isNotNull,
            reason: '$lang fehlt eigener Wert für: $key',
          );
          expect(
            value,
            isNot(key),
            reason: '$lang hat keinen echten Wert für: $key',
          );
          expect(value!.trim(), isNotEmpty, reason: '$lang/$key ist leer');
        }
      }
    });

    test('Platzhalter-Keys enthalten ihre Platzhalter', () {
      expect(
        AppStringsManager.getString('de', 'pdf_created_on'),
        contains('{date}'),
      );
      expect(
        AppStringsManager.getString('en', 'pdf_created_on'),
        contains('{date}'),
      );
      expect(
        AppStringsManager.getString('de', 'pdf_compare_with'),
        contains('{date}'),
      );
      expect(
        AppStringsManager.getString('de', 'pdf_page_of'),
        allOf(contains('{page}'), contains('{total}')),
      );
      expect(
        AppStringsManager.getString('de', 'pdf_age_years'),
        contains('{years}'),
      );
      expect(
        AppStringsManager.getString('de', 'pdf_age_years_months'),
        allOf(contains('{years}'), contains('{months}')),
      );
    });

    test('Dateiname-Präfix ist ASCII-sicher (keine Umlaute/Leerzeichen)', () {
      for (final lang in ['de', 'en', 'tr', 'ku']) {
        final prefix = AppStringsManager.getString(lang, 'pdf_filename_prefix');
        expect(
          prefix,
          matches(r'^[A-Za-z0-9_-]+$'),
          reason: '$lang filename-prefix nicht ASCII-sicher: $prefix',
        );
      }
    });
  });
}
