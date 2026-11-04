import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/ui/auth/email_verification_dialog.dart';

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

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _failedText =
    'Die Bestätigungs-E-Mail konnte gerade nicht gesendet werden. Bitte versuche es erneut.';

void main() {
  testWidgets(
      'shows a friendly title, the address, three steps and both actions',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(EmailVerificationDialog(
      email: 'mama@example.com',
      emailSent: true,
      onDone: () {},
      resend: (_) async => true,
    )));

    expect(find.text('Schön, dass du da bist!'), findsOneWidget);
    expect(find.text('mama@example.com'), findsOneWidget);
    expect(find.text('Öffne die E-Mail von ParentPeak.'), findsOneWidget);
    expect(find.text('Tippe auf den Button in der E-Mail.'), findsOneWidget);
    expect(find.text('Komm zurück und melde dich an.'), findsOneWidget);
    expect(find.textContaining('Spam-Ordner'), findsOneWidget);
    // Normalfall: "Zum Login" ist die Hauptaktion, erneut senden die zweite.
    expect(find.widgetWithText(FilledButton, 'Zum Login'), findsOneWidget);
    expect(find.text('Link erneut senden'), findsOneWidget);
    expect(find.text(_failedText), findsNothing);
  });

  testWidgets('fits a small phone with a very long address without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(EmailVerificationDialog(
      email:
          'eine.sehr.lange.familien.adresse.fuer.den.test@beispiel-domain.example',
      emailSent: false,
      onDone: () {},
      resend: (_) async => true,
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Schön, dass du da bist!'), findsOneWidget);
  });

  testWidgets('"Zum Login" calls onDone', (tester) async {
    _tallScreen(tester);
    var done = false;
    await tester.pumpWidget(_host(EmailVerificationDialog(
      email: 'mama@example.com',
      emailSent: true,
      onDone: () => done = true,
      resend: (_) async => true,
    )));
    await tester.tap(find.text('Zum Login'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('resend passes the address and confirms success', (tester) async {
    _tallScreen(tester);
    String? sentTo;
    await tester.pumpWidget(_host(EmailVerificationDialog(
      email: 'mama@example.com',
      emailSent: true,
      onDone: () {},
      resend: (email) async {
        sentTo = email;
        return true;
      },
    )));
    await tester.tap(find.text('Link erneut senden'));
    await tester.pump();
    await tester.pump();
    expect(sentTo, 'mama@example.com');
    expect(find.text('✅ Neuer Link wurde gesendet.'), findsOneWidget);
    expect(find.text(_failedText), findsNothing);
  });

  testWidgets('a failing resend shows the delivery error', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(EmailVerificationDialog(
      email: 'mama@example.com',
      emailSent: true,
      onDone: () {},
      resend: (_) async => false,
    )));
    await tester.tap(find.text('Link erneut senden'));
    await tester.pump();
    await tester.pump();
    expect(find.text(_failedText), findsOneWidget);
    expect(find.text('✅ Neuer Link wurde gesendet.'), findsNothing);
  });

  testWidgets('when the first mail failed, resending becomes the main action',
      (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_host(EmailVerificationDialog(
      email: 'mama@example.com',
      emailSent: false,
      onDone: () {},
      resend: (_) async => true,
    )));
    expect(find.text(_failedText), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Link erneut senden'),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Zum Login'), findsOneWidget);

    // Nach erfolgreichem erneuten Versand rückt "Zum Login" wieder nach vorn.
    await tester.tap(find.text('Link erneut senden'));
    await tester.pump();
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Zum Login'), findsOneWidget);
    expect(find.text('✅ Neuer Link wurde gesendet.'), findsOneWidget);
  });
}
