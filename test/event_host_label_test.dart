import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/ui/widgets/event_host_identity.dart';

void main() {
  group('eventHostLabelKey', () {
    test('geteiltes Angebot -> event_shared_by', () {
      expect(eventHostLabelKey(isSharedOffer: true), 'event_shared_by');
    });

    test('sonst -> event_submitted_by (nicht mehr "Gastgeber")', () {
      expect(eventHostLabelKey(isSharedOffer: false), 'event_submitted_by');
    });
  });

  group('i18n: event_submitted_by', () {
    test('existiert in jeder Picker-Sprache und ist nicht "Gastgeber"', () {
      for (final lang in AppLanguages.supported) {
        final map = AppStringsManager.allStrings[lang.code];
        expect(map, isNotNull, reason: 'Sprachblock fehlt: ${lang.code}');
        final value = map!['event_submitted_by'];
        expect(value, isNotNull,
            reason: 'event_submitted_by fehlt in ${lang.code}');
        expect(value!.trim(), isNotEmpty, reason: 'leer in ${lang.code}');
      }
    });

    test('deutsches Label lautet "Eingetragen von"', () {
      expect(
        AppStringsManager.getString('de', 'event_submitted_by'),
        'Eingetragen von',
      );
    });
  });
}
