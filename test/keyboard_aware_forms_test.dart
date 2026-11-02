import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/create_community_event_screen.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/widgets/keyboard_aware_form.dart';
import 'package:parentpeak/ui/widgets/playmate_profile_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _screen = Size(360, 640);
const _keyboard = 300.0;

class _Variant {
  const _Variant(this.name, this.language, this.direction, this.textScale);
  final String name;
  final String language;
  final TextDirection direction;
  final double textScale;
}

const _variants = [
  _Variant('de', 'de', TextDirection.ltr, 1.0),
  _Variant('de large text', 'de', TextDirection.ltr, 2.0),
  _Variant('ar rtl', 'ar', TextDirection.rtl, 1.0),
  _Variant('ar rtl large text', 'ar', TextDirection.rtl, 2.0),
];

FamilyMatchProfile _profile() => FamilyMatchProfile(
      displayName: 'Familie Test',
      district: 'Berlin Mitte',
      children: [ChildEntry(name: 'Mia', birthDate: DateTime(2021, 3, 4))],
      languages: const ['de', 'ar'],
      familyForm: 'kernfamilie',
      values: const ['gfk'],
      lookingFor: const ['spielplatz'],
      createdAt: DateTime(2024, 1, 2),
    );

Future<void> _useSmallPhone(WidgetTester tester, _Variant variant) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final previous = languageService.currentLanguage;
  await tester.runAsync(() => languageService.setLanguage(variant.language));
  addTearDown(() => languageService.setLanguage(previous));
}

Widget _app(TextDirection direction, Widget home) => MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: home,
    );

Future<void> _openKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  await tester.pumpAndSettle();
}

/// The focused field must be visible between the wizard header and the
/// navigation bar, which itself must sit above the keyboard. A field taller
/// than the remaining viewport (multi-line + 2x text) must at least show its
/// top edge and first input line and fill the viewport.
void _expectFullyVisible(WidgetTester tester, Finder field) {
  final rect = tester.getRect(field);
  final viewport = tester.getRect(find.byType(PageView));
  final keyboardTop = _screen.height - _keyboard;
  expect(viewport.bottom, lessThanOrEqualTo(keyboardTop));
  expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: '$rect');
  if (rect.height <= viewport.height) {
    expect(rect.bottom, lessThanOrEqualTo(viewport.bottom),
        reason: 'field hidden: $rect in $viewport');
  } else {
    expect(rect.top, lessThanOrEqualTo(viewport.top + 8), reason: '$rect');
  }
  expect(viewport.height, greaterThanOrEqualTo(80),
      reason: 'viewport squeezed to a strip: $viewport');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Scaffold body hides keyboard insets, helper still detects them',
      (tester) async {
    await _useSmallPhone(tester, _variants.first);
    final seen = <bool>[];
    await tester.pumpWidget(_app(
      TextDirection.ltr,
      Scaffold(
        body: KeyboardAwareBuilder(
          compactHeight: 0,
          builder: (context, compact) {
            seen.add(compact);
            return CollapsibleFormHeader(
              visible: !compact,
              child: const Text('header'),
            );
          },
        ),
      ),
    ));
    expect(seen.last, isFalse);
    expect(find.text('header'), findsOneWidget);
    await _openKeyboard(tester);
    expect(seen.last, isTrue);
    expect(find.text('header'), findsNothing);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text('header'), findsOneWidget);
  });

  for (final variant in _variants) {
    testWidgets('playmate wizard keeps focused fields visible (${variant.name})',
        (tester) async {
      await _useSmallPhone(tester, variant);
      await tester.pumpWidget(_app(
        variant.direction,
        // Same chrome as ElternNetzwerkScreen: AppBar with TabBar.
        DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Netzwerk'),
              bottom: const TabBar(
                tabs: [Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C')],
              ),
            ),
            body: PlaymateSetupLayout(
              status: PlaymateProfileStatusPanel(
                status: PlaymateProfileStatus.draft,
                onRetry: () {},
              ),
              form: PlaymateProfileForm(
                initialProfile: _profile(),
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = find.text(
        AppStringsManager.getString(variant.language, 'find_playmates'),
      );
      expect(title, findsOneWidget);

      final name = find.byType(TextField).first;
      await tester.tap(name);
      await tester.pump();
      await _openKeyboard(tester);
      expect(tester.takeException(), isNull);
      _expectFullyVisible(tester, name);
      expect(find.textContaining('1/5'), findsOneWidget);
      expect(title, findsNothing, reason: 'header must collapse');
      final next =
          find.widgetWithIcon(FilledButton, Icons.arrow_forward_rounded);
      expect(
        tester.getRect(next).bottom,
        lessThanOrEqualTo(_screen.height - _keyboard),
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(title, findsOneWidget, reason: 'header returns');
      for (var step = 0; step < 4; step++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // Bio is the last field on the last step, far down the scroll view.
      final bio = find.byWidgetPredicate(
        (w) => w is TextField && w.maxLength == 200,
      );
      await tester.ensureVisible(bio);
      await tester.tap(bio);
      await tester.pump();
      await _openKeyboard(tester);
      expect(tester.takeException(), isNull);
      _expectFullyVisible(tester, bio);
      expect(find.textContaining('5/5'), findsOneWidget);
    });
  }

  testWidgets('tall phone: header collapses although enough height remains',
      (tester) async {
    await _useSmallPhone(tester, _variants.first);
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpWidget(_app(
      TextDirection.ltr,
      Scaffold(
        appBar: AppBar(title: const Text('Netzwerk')),
        body: PlaymateSetupLayout(
          status: const SizedBox.shrink(),
          form: PlaymateProfileForm(
            initialProfile: _profile(),
            onSave: (_) async {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final title =
        find.text(AppStringsManager.getString('de', 'find_playmates'));
    expect(title, findsOneWidget);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(title, findsNothing);
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.bottom, lessThanOrEqualTo(915 - 340));
  });

  testWidgets('tapping the background closes the keyboard', (tester) async {
    await _useSmallPhone(tester, _variants.first);
    await tester.pumpWidget(_app(
      TextDirection.ltr,
      Scaffold(
        body: PlaymateProfileForm(
          initialProfile: _profile(),
          onSave: (_) async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    bool focused() => tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode
        .hasFocus;
    expect(focused(), isTrue);
    await tester.tapAt(const Offset(180, 4));
    await tester.pump();
    expect(focused(), isFalse);
  });

  for (final variant in _variants) {
    testWidgets(
        'community event wizard keeps focused field visible (${variant.name})',
        (tester) async {
      await _useSmallPhone(tester, variant);
      await tester.pumpWidget(
          _app(variant.direction, const CreateCommunityEventScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final organizer = find.byType(TextField).first;
      await tester.ensureVisible(organizer);
      await tester.tap(organizer);
      await tester.pump();
      await _openKeyboard(tester);
      expect(tester.takeException(), isNull);
      _expectFullyVisible(tester, organizer);
    });
  }
}
