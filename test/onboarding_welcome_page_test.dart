import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/ui/onboarding/onboarding_pages.dart';

/// Nach Option A (Prioritäten-Schritt entfernt) begrüßt die Willkommen-Seite
/// warm und verspricht NICHT mehr, erst herauszufinden, was der Familie hilft.
/// Diese Tests sichern:
/// (1) der modernisierte Untertitel ist sichtbar,
/// (2) keine Überläufe auf schmaler Breite und bei großer Systemschrift in
///     allen Launch-Sprachen inkl. RTL (Arabisch).
Widget _page(String language, double scale) {
  return MaterialApp(
    locale: Locale(language),
    supportedLocales: AppLanguages.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      AppLanguages.materialLocalizationsDelegate,
      AppLanguages.widgetsLocalizationsDelegate,
      AppLanguages.cupertinoLocalizationsDelegate,
    ],
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: const OnboardingWelcomePage(
            fadeAnimation: AlwaysStoppedAnimation<double>(1),
            slideAnimation: AlwaysStoppedAnimation<Offset>(Offset.zero),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the modernised welcome subtitle (de)', (tester) async {
    await tester.pumpWidget(_page('de', 1.0));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStringsManager.getString('de', 'onboarding_subtitle')),
      findsOneWidget,
    );
  });

  for (final language in ['de', 'en', 'tr', 'fr', 'es', 'it', 'ar', 'ku']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow ($language, scale $scale)', (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_page(language, scale));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(Scaffold))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
  }
}
