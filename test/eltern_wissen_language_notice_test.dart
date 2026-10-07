import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/eltern_wissen_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/widgets/eltern_wissen_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> showKnowledge(
    WidgetTester tester,
    String language, {
    double textScale = 1,
  }) async {
    final previous = languageService.currentLanguage;
    await tester.runAsync(() => languageService.setLanguage(language));
    addTearDown(() => languageService.setLanguage(previous));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: ElternWissenWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'tr', 'ku', 'fr']) {
    testWidgets(
      'FAQ language notice stays present through search in $language',
      (tester) async {
        await showKnowledge(tester, language);
        final notice = AppStringsManager.getString(
          language,
          'knowledge_content_language_notice',
        );
        expect(find.text(notice), findsOneWidget);
        expect(
          find.text(
            AppStringsManager.getString(
              language,
              'knowledge_ui_language_notice',
            ),
          ),
          language == 'fr' ? findsOneWidget : findsNothing,
        );

        await tester.enterText(find.byType(TextField), 'schlafen');
        await tester.pumpAndSettle();
        expect(find.text(notice), findsOneWidget);
        expect(
          find.textContaining(
            ElternWissenService.instance.search('schlafen').first.question,
          ),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), 'zzzzzzzz');
        await tester.pumpAndSettle();
        expect(find.text(notice), findsOneWidget);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(find.text(notice), findsOneWidget);
      },
    );
  }

  testWidgets('German FAQ has no fallback notice', (tester) async {
    await showKnowledge(tester, 'de');
    expect(
      find.byKey(const ValueKey('knowledge-language-notice')),
      findsNothing,
    );
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('FAQ notice and topics fit large text at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showKnowledge(tester, 'tr', textScale: scale);
      expect(
        find.byKey(const ValueKey('knowledge-language-notice')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('FAQ notice updates when the language changes', (tester) async {
    await showKnowledge(tester, 'de');
    await tester.runAsync(() => languageService.setLanguage('en'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        AppStringsManager.getString('en', 'knowledge_content_language_notice'),
      ),
      findsOneWidget,
    );
    await tester.runAsync(() => languageService.setLanguage('de'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('knowledge-language-notice')),
      findsNothing,
    );
  });
}
