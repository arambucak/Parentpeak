import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/ui/onboarding/onboarding_pages.dart';

/// Die Onboarding-Abschlussseite zeigt drei Orientierungs-Schritte (wie man die
/// App bedient), nicht mehr eine Häkchen-Feature-Liste. Diese Tests sichern:
/// (1) die drei Schritt-Titel sind sichtbar,
/// (2) keine abgeschnittenen/überlaufenden Texte in langen Sprachen auf
///     schmaler Breite und bei großer Systemschrift (das war der alte Bug).
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
          child: const OnboardingReadyPage(
            fadeAnimation: AlwaysStoppedAnimation<double>(1),
            slideAnimation: AlwaysStoppedAnimation<Offset>(Offset.zero),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the three orientation steps (de)', (tester) async {
    await tester.pumpWidget(_page('de', 1.0));
    await tester.pumpAndSettle();
    expect(
        find.text(
            AppStringsManager.getString('de', 'onboarding_step_home_title')),
        findsOneWidget);
    expect(
        find.text(
            AppStringsManager.getString('de', 'onboarding_step_grid_title')),
        findsOneWidget);
    expect(
        find.text(
            AppStringsManager.getString('de', 'onboarding_step_chat_title')),
        findsOneWidget);
    // Keine verwirrenden Erledigt-Häkchen mehr.
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  for (final language in ['de', 'tr', 'fr', 'ar']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow ($language, scale $scale)', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_page(language, scale));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Richtige Text-Richtung in RTL (Arabisch).
        expect(
          Directionality.of(tester.element(find.byType(Scaffold))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
  }
}
