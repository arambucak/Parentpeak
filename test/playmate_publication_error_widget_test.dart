import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/playmate_publication_failure.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/ui/widgets/playmate_publication_error.dart';

void main() {
  final failures = [
    PlaymatePublicationFailure.fromStatus(400),
    PlaymatePublicationFailure.fromStatus(401),
    PlaymatePublicationFailure.fromStatus(403),
    PlaymatePublicationFailure.fromStatus(429),
    PlaymatePublicationFailure.fromStatus(503),
    const PlaymatePublicationFailure(PlaymatePublicationFailureReason.network),
    const PlaymatePublicationFailure(PlaymatePublicationFailureReason.timeout),
    const PlaymatePublicationFailure(
      PlaymatePublicationFailureReason.invalidResponse,
    ),
    const PlaymatePublicationFailure(
      PlaymatePublicationFailureReason.missingUser,
    ),
  ];

  for (final language in ['de', 'ar']) {
    for (final failure in failures) {
      testWidgets(
        '$language ${failure.diagnosticCode} snackbar fits at 360x640 and 2x',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(360, 640);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                ),
                child: Directionality(
                  textDirection:
                      language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      playmatePublicationErrorSnackBar(
                        context,
                        language: language,
                        failure: failure,
                      ),
                    ),
                    child: const Text('Show'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Show'));
          await tester.pumpAndSettle();

          final message = AppStringsManager.getString(
            language,
            failure.messageKey,
          );
          final messageFinder = find.text(message);
          final codeFinder = find.textContaining(failure.diagnosticCode);
          expect(messageFinder, findsOneWidget);
          expect(codeFinder, findsOneWidget);
          final snackRect = tester.getRect(find.byType(SnackBar));
          expect(snackRect.left, greaterThanOrEqualTo(0));
          expect(snackRect.right, lessThanOrEqualTo(360));
          expect(snackRect.top, greaterThanOrEqualTo(0));
          expect(snackRect.bottom, lessThanOrEqualTo(640));
          for (final finder in [messageFinder, codeFinder]) {
            final rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(snackRect.left));
            expect(rect.right, lessThanOrEqualTo(snackRect.right));
            expect(rect.top, greaterThanOrEqualTo(snackRect.top));
            expect(rect.bottom, lessThanOrEqualTo(snackRect.bottom));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '$language suspended account notice and code fit at 360x640 and 2x',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 640);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final failure = PlaymatePublicationFailure.fromStatus(403);

        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('de'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAccountSuspendedNotice(
                    context,
                    diagnosticText: playmatePublicationDiagnosticText(
                      language: language,
                      failure: failure,
                    ),
                  ),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        final message = find.text(
          AppStringsManager.getString(language, 'account_suspended_message'),
        );
        final code = find.textContaining('HTTP 403');
        expect(message, findsOneWidget);
        expect(code, findsOneWidget);
        expect(
          Directionality.of(tester.element(code)),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        final dialogRect = tester.getRect(dialog);
        final codeRect = tester.getRect(code);
        expect(codeRect.left, greaterThanOrEqualTo(dialogRect.left));
        expect(codeRect.right, lessThanOrEqualTo(dialogRect.right));
        expect(codeRect.top, greaterThanOrEqualTo(dialogRect.top));
        expect(codeRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
        expect(tester.getRect(message).top, lessThan(dialogRect.bottom));
        await tester.drag(
          find.descendant(
            of: dialog,
            matching: find.byType(SingleChildScrollView),
          ),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(message).bottom,
          lessThanOrEqualTo(dialogRect.bottom),
        );
        expect(tester.getRect(code), codeRect);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
