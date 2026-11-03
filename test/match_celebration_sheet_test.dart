import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/ui/widgets/network/match_celebration_sheet.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppLanguages.materialLocalizationsDelegate,
        AppLanguages.widgetsLocalizationsDelegate,
        AppLanguages.cupertinoLocalizationsDelegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows both names, title and icebreakers', (tester) async {
    await tester.pumpWidget(_host(
      MatchCelebrationSheet(
        ownName: 'Aylin',
        otherName: 'Burak',
        onWrite: (_) {},
        onLater: () {},
      ),
    ));

    // Beide Initialen-Avatare.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    // Titel (DE).
    expect(find.text('Es passt!'), findsOneWidget);
    // Drei Eisbrecher-Vorschläge sind sichtbar.
    expect(find.textContaining('Spielplatz'), findsOneWidget);
    // Aktionen.
    expect(find.text('Nachricht schreiben'), findsOneWidget);
    expect(find.text('Später'), findsOneWidget);
  });

  testWidgets('tapping an icebreaker then write passes the chosen text',
      (tester) async {
    String? chosen = 'UNSET';
    await tester.pumpWidget(_host(
      MatchCelebrationSheet(
        ownName: 'Aylin',
        otherName: 'Burak',
        onWrite: (text) => chosen = text,
        onLater: () {},
      ),
    ));

    await tester.tap(find.textContaining('Spielplatz'));
    await tester.pump();
    await tester.tap(find.text('Nachricht schreiben'));
    await tester.pump();

    expect(chosen, isNotNull);
    expect(chosen, contains('Spielplatz'));
  });

  testWidgets('write without selection passes null', (tester) async {
    String? chosen = 'UNSET';
    await tester.pumpWidget(_host(
      MatchCelebrationSheet(
        ownName: 'Aylin',
        otherName: 'Burak',
        onWrite: (text) => chosen = text,
        onLater: () {},
      ),
    ));
    await tester.tap(find.text('Nachricht schreiben'));
    await tester.pump();
    expect(chosen, isNull);
  });

  testWidgets('later triggers onLater', (tester) async {
    var later = false;
    await tester.pumpWidget(_host(
      MatchCelebrationSheet(
        ownName: 'Aylin',
        otherName: 'Burak',
        onWrite: (_) {},
        onLater: () => later = true,
      ),
    ));
    await tester.tap(find.text('Später'));
    await tester.pump();
    expect(later, isTrue);
  });
}
