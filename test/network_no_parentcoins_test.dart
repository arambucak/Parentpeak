import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

/// Schützt die ParentCoins-Entfernung vor Rückfällen: Das Belohnungssystem
/// wurde bewusst entfernt. Weder der Code noch die Home-Kachel-Beschreibung
/// dürfen ParentCoins/Coins wieder einführen.
void main() {
  group('ParentCoins vollständig entfernt', () {
    test('ParentCoinService-Datei existiert nicht mehr', () {
      expect(File('lib/logic/parent_coin_service.dart').existsSync(), isFalse);
    });

    test('kein lib/-Code referenziert ParentCoin mehr', () {
      final offenders = <String>[];
      final dir = Directory('lib');
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        // Die l10n-Datei enthält Kommentare/historische Keys? Wir prüfen Code-Nutzung:
        final text = f.readAsStringSync();
        if (text.contains('ParentCoinService') ||
            text.contains('parent_coin_service')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('tote Coin-l10n-Keys sind entfernt', () {
      const deadKeys = [
        'parent_coins',
        'invite_reward',
        'network_coin_per_registration',
      ];
      for (final lang in ['de', 'en', 'tr', 'ku']) {
        for (final key in deadKeys) {
          // getString gibt bei fehlendem Key den Key selbst zurück.
          expect(AppStringsManager.getString(lang, key), key,
              reason: '$lang: $key sollte entfernt sein');
        }
      }
    });

    test('Home-Kachel-Text erwähnt keine Coins mehr (de/en/tr/ku)', () {
      const coinWords = ['coin', 'münz', 'jeton', 'monnaie', 'moneda'];
      for (final lang in ['de', 'en', 'tr', 'ku']) {
        final desc =
            AppStringsManager.getString(lang, 'tile_network_desc').toLowerCase();
        expect(desc, isNotEmpty);
        for (final w in coinWords) {
          expect(desc.contains(w), isFalse,
              reason: '$lang tile_network_desc enthält noch "$w": $desc');
        }
      }
    });
  });
}
