import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'dart:io';

void main() {
  const expectedLanguages = [
    'de',
    'en',
    'tr',
    'ku',
    'ar',
    'ru',
    'uk',
    'es',
    'fr',
    'it',
    'pt',
  ];

  Set<String> placeholders(String value) =>
      RegExp(r'\{[a-zA-Z_][a-zA-Z0-9_]*\}')
          .allMatches(value)
          .map((match) => match.group(0)!)
          .toSet();

  test('Package 3 has a complete direct schema for every supported language',
      () {
    expect(AppStringsManager.package3Languages, expectedLanguages);
    final keys = AppStringsManager.package3Keys.toSet();
    expect(keys, isNotEmpty);

    for (final language in expectedLanguages) {
      for (final key in keys) {
        expect(AppStringsManager.hasPackage3Translation(language, key), isTrue,
            reason: '$language is missing $key');
        expect(
          placeholders(AppStringsManager.package3String(language, key)!),
          placeholders(AppStringsManager.package3String('de', key)!),
          reason: '$language changes placeholders for $key',
        );
      }
    }
  });

  test('Package 3 preserves direct native samples and Arabic script', () {
    expect(
        AppStringsManager.package3String('de', 'event_title'), 'Event-Titel');
    expect(
        AppStringsManager.package3String('en', 'event_title'), 'Event title');
    final arabic = AppStringsManager.package3String('ar', 'event_title')!;
    expect(arabic, 'عنوان الفعالية');
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(arabic), isTrue);
    expect(AppStringsManager.getString('ar', 'package3_join_now'),
        'أنتم الآن ضمن الحضور.');
  });

  test('Package 3 event surfaces contain no raw UI-facing text literals', () {
    const files = [
      'lib/ui/weekly_planner_view.dart',
      'lib/ui/event_invitations_screen.dart',
      'lib/ui/create_event_screen.dart',
      'lib/ui/create_community_event_screen.dart',
      'lib/ui/event_discover_screen.dart',
      'lib/ui/events_activities_screen.dart',
      'lib/ui/widgets/event_safety_widgets.dart',
      'lib/ui/widgets/home/events_carousel_widget.dart',
      'lib/ui/widgets/home/next_event_widget.dart',
    ];
    final rawUiText = RegExp(
      r'''(?:Text|labelText|hintText|message)\s*\(?(?:\s*const\s+)?['"](?!\\u|\$)[^'"]*[A-Za-zäöüÄÖÜß][^'"]*['"]''',
    );

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(rawUiText.hasMatch(source), isFalse,
          reason: '$path contains a raw UI-facing text literal');
    }
  });
}
