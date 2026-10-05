import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

/// Sichert, dass die neu lokalisierten Eltern-Netzwerk-Strings in allen vier
/// Hauptsprachen existieren und ihre Platzhalter behalten.
void main() {
  const mainLanguages = ['de', 'en', 'tr', 'ku'];

  group('Eltern-Netzwerk i18n', () {
    const requiredKeys = [
      'network_share_message',
      'network_link_create_failed',
      'network_qr_create_failed',
      'network_requests_count',
      'network_validation_name',
      'network_validation_district',
      'network_save_error',
      'network_scan_to_connect',
    ];

    test('alle Keys existieren und sind nicht leer (de/en/tr/ku)', () {
      final missing = <String>[];
      for (final lang in mainLanguages) {
        for (final key in requiredKeys) {
          final v = AppStringsManager.getString(lang, key);
          if (v == key || v.trim().isEmpty) missing.add('$lang: $key');
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('Platzhalter bleiben in allen Sprachen erhalten', () {
      const placeholders = {
        'network_share_message': '{link}',
        'network_requests_count': '{count}',
        'network_save_error': '{error}',
      };
      for (final lang in mainLanguages) {
        placeholders.forEach((key, token) {
          final v = AppStringsManager.getString(lang, key);
          expect(v.contains(token), isTrue,
              reason: '$lang: $key muss $token enthalten');
        });
      }
    });

    test('Share-Nachricht enthält keinen fest verdrahteten Link mehr', () {
      for (final lang in mainLanguages) {
        final v = AppStringsManager.getString(lang, 'network_share_message');
        // Der Link kommt zur Laufzeit über {link} rein, nicht hartcodiert.
        expect(v.contains('parentpeak.de/'), isFalse, reason: lang);
        expect(v.contains('{link}'), isTrue, reason: lang);
      }
    });
  });
}
