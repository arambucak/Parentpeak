import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/l10n/supported_languages.dart';

/// Regression: Im Türkischen ist der Chat-AppBar-Titel
/// ("Yapay Zeka Ebeveyn Danışmanlığı") fast doppelt so lang wie im Deutschen
/// ("KI Elternberatung"). Ohne Breitenbegrenzung lief er unter die drei
/// Action-Icons (Verlauf, neuer Chat, Menü). Der Titel muss daher flexibel
/// sein und bei Platzmangel mit Ellipsis kürzen – ohne RenderFlex-Overflow.

const _kBrand = Color(0xFF7C3AED);
const _kBrand2 = Color(0xFFA855F7);

/// Repliziert die title-/actions-Struktur der Chat-AppBar (chat_screen.dart).
AppBar _chatAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: Colors.white,
    foregroundColor: _kBrand,
    titleSpacing: 0,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kBrand, _kBrand2]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 20, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('ki_parenting_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1F2937)),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: Color(0xFF22C55E), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      context.tr('chat_always_here'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      IconButton(onPressed: () {}, icon: const Icon(Icons.forum_outlined)),
      IconButton(
          onPressed: () {}, icon: const Icon(Icons.add_comment_outlined)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
    ],
  );
}

void main() {
  // Schmale Geräte-Breite, auf der der lange TR-Titel sonst überläuft.
  const narrow = Size(390, 844); // iPhone-Portrait-Breite

  for (final language in ['de', 'en', 'tr', 'ku']) {
    testWidgets('Chat-AppBar-Titel läuft nicht über ($language)',
        (tester) async {
      tester.view.physicalSize = narrow;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(appBar: _chatAppBar(context)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kein RenderFlex-Overflow.
      expect(tester.takeException(), isNull);

      // Titel ist vorhanden und wird (bei Bedarf) mit Ellipsis gekürzt.
      final titleText =
          AppStringsManager.getString(language, 'ki_parenting_title');
      final titleFinder = find.text(titleText);
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expect(textWidget.maxLines, 1);
    });
  }
}
