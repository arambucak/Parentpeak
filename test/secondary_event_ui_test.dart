import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/ui/create_community_event_screen.dart';
import 'package:parentpeak/ui/widgets/event_safety_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(String code, Widget child) => MaterialApp(
  locale: Locale(code),
  supportedLocales: AppLanguages.supportedLocales,
  localizationsDelegates: const [
    AppLanguages.materialLocalizationsDelegate,
    AppLanguages.widgetsLocalizationsDelegate,
    AppLanguages.cupertinoLocalizationsDelegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('secondary event keys are explicit in all supported locales', () {
    final keys = <String>{};
    for (final path in [
      'lib/ui/create_community_event_screen.dart',
      'lib/ui/widgets/event_safety_widgets.dart',
      'lib/ui/event_detail_page.dart',
      'lib/ui/event_invitations_screen.dart',
      'lib/ui/meetup_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      keys.addAll(RegExp(r"'(events?_[A-Za-z0-9_]+)'")
          .allMatches(source)
          .map((match) => match.group(1)!)
          .where((key) => !key.endsWith('_')));
    }
    for (final creator in CreatorType.values) {
      keys.add('event_creator_${creator.name}');
      keys.add('event_creator_hint_${creator.name}');
    }
    for (final category in EventCategory.values.where((category) =>
        category != EventCategory.sport && category != EventCategory.sonstiges)) {
      keys.add('event_community_category_${category.name}');
    }
    for (final tag in AccessibilityTag.values) {
      keys.add('event_access_${tag.name}');
    }
    for (final venue in EventVenue.values) {
      keys.add('event_venue_${venue.name}');
    }
    for (final language in AppLanguages.supported) {
      for (final key in keys) {
        expect(AppStringsManager.allStrings[language.code]![key], isNotEmpty,
            reason: '${language.code}:$key');
      }
    }
  });

  for (final language in AppLanguages.supported) {
    testWidgets('${language.code}: safety is nonblank and reports selectable',
        (tester) async {
      await tester.pumpWidget(_app(language.code, Column(children: [
        EventDisclaimerBanner(onDismiss: () {}),
        const PrivateAddressHint(),
        const ReportEventSheet(eventId: 'test', eventTitle: 'Picnic'),
      ])));
      await tester.pumpAndSettle();
      final strings = AppStringsManager.allStrings[language.code]!;
      expect(find.text(strings['event_safety_title']!), findsOneWidget);
      expect(find.text(strings['event_report_title']!), findsOneWidget);
      final button = find.widgetWithText(FilledButton, strings['event_report_send']!);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      final reason = find.widgetWithText(RadioListTile<String>, strings['event_report_fake']!);
      await tester.ensureVisible(reason);
      await tester.tap(reason);
      await tester.pump();
      expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, 'fake');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('creator RadioGroup changes the organizer hint', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      home: CreateCommunityEventScreen(),
    ));
    await tester.pumpAndSettle();
    final company = find.widgetWithText(RadioListTile<CreatorType>, 'Business / provider');
    await tester.ensureVisible(company);
    await tester.tap(company);
    await tester.pumpAndSettle();
    expect(tester.widget<RadioGroup<CreatorType>>(find.byType(RadioGroup<CreatorType>)).groupValue,
        CreatorType.unternehmen);
    expect(find.text('e.g. Sunshine Daycare'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}