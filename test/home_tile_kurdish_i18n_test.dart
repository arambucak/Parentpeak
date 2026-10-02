import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

void main() {
  test('Home giveaway and ritual tiles are translated in Kurmanji', () {
    expect(
      AppStringsManager.getString('ku', 'treasureTileTitle'),
      'Bazara tiştên belaş',
    );
    expect(
      AppStringsManager.getString('ku', 'treasureTileSubtitle'),
      'Tiştan bibexşîne, biguherîne û dêûbavên din nas bike',
    );
    expect(
      AppStringsManager.getString('ku', 'ritualRuheTitle'),
      'Rîtuel û Aramî',
    );
    expect(
      AppStringsManager.getString('ku', 'ritualRuheTileSubtitle'),
      'Demek aram ji bo jiyana rojane ya malbata we',
    );
  });

  test('Home tile keys resolve explicitly in supported target locales', () {
    for (final locale in ['de', 'en', 'tr', 'ku']) {
      for (final key in [
        'treasureTileTitle',
        'treasureTileSubtitle',
        'ritualRuheTitle',
        'ritualRuheTileSubtitle',
      ]) {
        expect(
          AppStringsManager.allStrings[locale]?[key],
          isNotEmpty,
          reason: '$locale is missing $key',
        );
      }
    }
  });
}
