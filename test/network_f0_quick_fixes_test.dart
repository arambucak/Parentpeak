import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _launchLanguages = ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];

class _Variant {
  const _Variant(this.name, this.language, this.direction, this.textScale);
  final String name;
  final String language;
  final TextDirection direction;
  final double textScale;
}

const _variants = [
  _Variant('de', 'de', TextDirection.ltr, 1.0),
  _Variant('de 2x text', 'de', TextDirection.ltr, 2.0),
  _Variant('ar rtl', 'ar', TextDirection.rtl, 1.0),
  _Variant('ar rtl 2x text', 'ar', TextDirection.rtl, 2.0),
];

FamilyMatchProfile _profile({String name = '', String district = ''}) =>
    FamilyMatchProfile(
      displayName: name,
      district: district,
      children: [ChildEntry(name: 'Mia', birthDate: DateTime(2021, 3, 4))],
      languages: const ['de'],
      familyForm: 'kernfamilie',
      values: const [],
      lookingFor: const [],
      createdAt: DateTime(2024, 1, 2),
    );

Future<void> _pumpWizard(
  WidgetTester tester,
  _Variant variant,
  FamilyMatchProfile profile,
) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final previous = languageService.currentLanguage;
  await tester.runAsync(() => languageService.setLanguage(variant.language));
  addTearDown(() => languageService.setLanguage(previous));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: variant.direction, child: child!),
      home: Scaffold(
        body:
            PlaymateProfileForm(initialProfile: profile, onSave: (_) async {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _s(String language, String key) =>
    AppStringsManager.getString(language, key);

Future<void> _tapNext(WidgetTester tester, String language) async {
  await tester.tap(find.text(_s(language, 'next_btn_wizard')));
  await tester.pumpAndSettle();
}

bool _nameFocused(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .focusNode
    .hasFocus;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('match reasons', () {
    test('known reasons are translated', () {
      expect(networkMatchReasonLabel('en', 'nearby'), 'Nearby');
      expect(networkMatchReasonLabel('tr', 'shared_languages'), 'Ortak diller');
    });

    test('unknown reasons are hidden instead of shown raw', () {
      expect(networkMatchReasonLabel('en', 'future_reason'), isNull);
      expect(
        networkMatchReasonLabels('de', ['future_reason', 'nearby']),
        [_s('de', 'network_copy_reason_nearby')],
      );
    });

    test('same_city is translated in all launch languages', () {
      for (final language in _launchLanguages) {
        final label = networkMatchReasonLabel(language, 'same_city');
        expect(label, isNotNull, reason: language);
        expect(label, isNot('same_city'), reason: language);
        expect(label, _s(language, 'network_copy_same_city'), reason: language);
      }
      expect(networkMatchReasonLabel('de', 'same_city'), 'In deiner Stadt');
    });

    test('same_city is not repeated when the meta line already shows it', () {
      final codes = ['same_city', 'shared_values'];
      expect(
        networkMatchReasonLabels('de', codes, sameCityInMeta: true),
        [_s('de', 'network_copy_reason_shared_values')],
      );
      expect(networkMatchReasonLabels('de', codes), [
        'In deiner Stadt',
        _s('de', 'network_copy_reason_shared_values'),
      ]);
    });

    test('limit counts only visible reasons', () {
      final labels = networkMatchReasonLabels('en', [
        'unknown_a',
        'nearby',
        'unknown_b',
        'shared_values',
        'shared_languages',
        'shared_interests',
      ]);
      expect(labels, hasLength(3));
      expect(labels.first, 'Nearby');
    });
  });

  test('required-field messages exist in all launch languages', () {
    for (final key in [
      'network_field_name_required',
      'network_field_district_required',
      'network_required_fields_note',
    ]) {
      for (final language in _launchLanguages) {
        final value = _s(language, key);
        expect(value, isNot(key), reason: '$language $key');
        expect(value.trim(), isNotEmpty, reason: '$language $key');
        if (language != 'en') {
          expect(value, isNot(_s('en', key)), reason: '$language $key');
        }
      }
    }
  });

  for (final variant in _variants) {
    group('wizard step 1 (${variant.name}, 360x640)', () {
      testWidgets(
          'both missing: stays on step 1, errors at fields, '
          'focus on name', (tester) async {
        await _pumpWizard(tester, variant, _profile());
        final lang = variant.language;
        expect(find.text(_s(lang, 'network_required_fields_note')),
            findsOneWidget);
        await _tapNext(tester, lang);

        expect(tester.takeException(), isNull);
        expect(find.text(_s(lang, 'network_wizard_for_whom')), findsNothing);
        expect(
            find.text(_s(lang, 'network_field_name_required')), findsOneWidget);
        expect(find.text(_s(lang, 'network_field_district_required')),
            findsOneWidget);
        expect(_nameFocused(tester), isTrue);
        final field = tester.getRect(find.byType(TextField).first);
        expect(field.top, greaterThanOrEqualTo(0));
        expect(field.bottom, lessThanOrEqualTo(640));

        await tester.enterText(find.byType(TextField).first, 'Familie Test');
        await tester.pump();
        expect(
            find.text(_s(lang, 'network_field_name_required')), findsNothing);
        expect(find.text(_s(lang, 'network_field_district_required')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('only district missing: focus moves to location picker',
          (tester) async {
        await _pumpWizard(tester, variant, _profile(name: 'Familie Test'));
        await _tapNext(tester, variant.language);

        expect(tester.takeException(), isNull);
        expect(find.text(_s(variant.language, 'network_wizard_for_whom')),
            findsNothing);
        expect(
          find.text(_s(variant.language, 'network_field_name_required')),
          findsNothing,
        );
        final error =
            find.text(_s(variant.language, 'network_field_district_required'));
        expect(error, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(LocationPickerWidget),
            matching: error,
          ),
          findsOneWidget,
          reason: 'error must be shown directly at the location field',
        );
        expect(_nameFocused(tester), isFalse);
        final picker = find.descendant(
          of: find.byType(LocationPickerWidget),
          matching: find.byType(Focus),
        );
        expect(
          tester
              .widgetList<Focus>(picker)
              .any((f) => f.focusNode?.hasFocus ?? false),
          isTrue,
        );
        final rect = tester.getRect(find.byType(LocationPickerWidget));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640));
      });

      testWidgets('complete step 1 advances to step 2', (tester) async {
        await _pumpWizard(
          tester,
          variant,
          _profile(name: 'Familie Test', district: 'Berlin Mitte'),
        );
        await _tapNext(tester, variant.language);
        expect(tester.takeException(), isNull);
        expect(find.text(_s(variant.language, 'network_wizard_for_whom')),
            findsOneWidget);
        expect(
          find.text(_s(variant.language, 'network_field_district_required')),
          findsNothing,
        );
      });
    });
  }
}
