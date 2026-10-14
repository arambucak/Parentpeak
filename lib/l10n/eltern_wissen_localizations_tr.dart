import 'package:parentpeak/l10n/eltern_wissen_localizations.dart';

/// Turkish translations for parent-knowledge FAQ entries.
///
/// Only `klein_04` was translated so far (migrated from the widget). Missing
/// ids fall back to the German source via [localizeElternWissenEntry].
const Map<String, ElternWissenText> elternWissenTr = {
  'klein_04': ElternWissenText(
    question: 'Çocuğum her şeye hayır diyor',
    akut:
        'Bu sağlıklı bir durum! Çocuğunuz kendi iradesi olan bağımsız bir birey olduğunu keşfediyor.',
    beduerfnis:
        'Özerklik temel bir ihtiyaçtır. “Hayır” demek, kendini belirlemenin ilk biçimidir.',
    gfkSatz:
        'Hayır dediğini duyuyorum. Bazı şeyleri yine de yapmamız gerekiyor; birlikte bir yol bulalım.',
    aktion: [
      'Emir vermek yerine seçenekler sunun (“Kırmızı mı mavi mi ceket?”)',
      'Gereksiz güç mücadelelerinden kaçının',
      'Mümkün olduğunda hayır demesine saygı gösterin; bu özgüvenini güçlendirir',
    ],
    ermutigung:
        'Evde hayır demesine izin verilen bir çocuk, yabancılara da hayır demeyi öğrenir.',
  ),
};
