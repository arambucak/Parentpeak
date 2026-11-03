import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/ui/widgets/network/family_avatar.dart';
import 'package:parentpeak/ui/widgets/network/info_chip.dart';
import 'package:parentpeak/ui/widgets/network/family_card.dart';
import 'package:parentpeak/ui/widgets/network/network_actions.dart';
import 'package:parentpeak/ui/widgets/network/network_banner.dart';
import 'package:parentpeak/ui/widgets/network/network_empty_state.dart';
import 'package:parentpeak/ui/widgets/network/safety_menu.dart';

/// Baut ein Widget in einem realistischen Rahmen auf: feste Größe 360×640,
/// optional doppelte Textskalierung und RTL (Arabisch), wie im Redesign-Plan
/// gefordert.
Widget _host(
  Widget child, {
  double textScale = 1.0,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F766E),
        brightness: brightness,
      ),
      useMaterial3: true,
    ),
    home: Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
        ),
      ),
    ),
  );
}

void main() {
  group('FamilyAvatar', () {
    testWidgets('zeigt die Initiale des Namens', (tester) async {
      await tester.pumpWidget(_host(const FamilyAvatar(name: 'Aylin')));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('Platzhalter bei leerem Namen, kein Crash', (tester) async {
      await tester.pumpWidget(_host(const FamilyAvatar(name: '')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('trägt ein Semantik-Label', (tester) async {
      await tester.pumpWidget(
        _host(const FamilyAvatar(name: 'Familie Aylin')),
      );
      expect(
        find.bySemanticsLabel('Familie Aylin'),
        findsOneWidget,
      );
    });

    testWidgets('rendert in allen drei Größen ohne Overflow', (tester) async {
      await tester.pumpWidget(
        _host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FamilyAvatar(name: 'A', size: FamilyAvatarSize.s),
              FamilyAvatar(name: 'B', size: FamilyAvatarSize.m),
              FamilyAvatar(name: 'C', size: FamilyAvatarSize.l),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('funktioniert im Dunkelmodus', (tester) async {
      await tester.pumpWidget(
        _host(const FamilyAvatar(name: 'Aylin'), brightness: Brightness.dark),
      );
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('InfoChip', () {
    testWidgets('zeigt das Label', (tester) async {
      await tester.pumpWidget(_host(const InfoChip(label: 'Deutsch')));
      expect(find.text('Deutsch'), findsOneWidget);
    });

    testWidgets('überlebt doppelte Textskalierung auf 360 breit', (tester) async {
      await tester.pumpWidget(
        _host(const InfoChip(label: 'Nachmittags'), textScale: 2.0),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FamilyCard', () {
    testWidgets('rendert sein Kind', (tester) async {
      await tester.pumpWidget(
        _host(const FamilyCard(child: Text('Inhalt'))),
      );
      expect(find.text('Inhalt'), findsOneWidget);
    });

    testWidgets('onTap wird ausgelöst', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(FamilyCard(onTap: () => tapped = true, child: const Text('X'))),
      );
      await tester.tap(find.text('X'));
      expect(tapped, isTrue);
    });
  });

  group('PrimaryAction / SecondaryAction', () {
    testWidgets('lösen onPressed aus und zeigen Label', (tester) async {
      var primary = false;
      var secondary = false;
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryAction(
                label: 'Interessiert',
                icon: Icons.favorite_rounded,
                onPressed: () => primary = true,
              ),
              SecondaryAction(
                label: 'Nicht jetzt',
                onPressed: () => secondary = true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Interessiert'));
      await tester.tap(find.text('Nicht jetzt'));
      expect(primary, isTrue);
      expect(secondary, isTrue);
    });

    testWidgets('halten Mindesthöhe 48 ein (RTL)', (tester) async {
      await tester.pumpWidget(
        _host(
          PrimaryAction(label: 'موافق', onPressed: () {}),
          direction: TextDirection.rtl,
        ),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('NetworkBanner', () {
    testWidgets('zeigt Nachricht und löst Aktion aus', (tester) async {
      var acted = false;
      await tester.pumpWidget(
        _host(
          NetworkBanner(
            message: 'Lege ein Profil an.',
            icon: Icons.info_outline,
            actionLabel: 'Profil anlegen',
            onAction: () => acted = true,
          ),
        ),
      );
      expect(find.text('Lege ein Profil an.'), findsOneWidget);
      await tester.tap(find.text('Profil anlegen'));
      expect(acted, isTrue);
    });

    testWidgets('Warnton rendert ohne Fehler', (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkBanner(
            message: 'Dein Profil ist pausiert.',
            tone: NetworkBannerTone.warning,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('NetworkEmptyState', () {
    testWidgets('zeigt Titel/Text und nutzt FilledButton für die Aktion',
        (tester) async {
      var acted = false;
      await tester.pumpWidget(
        _host(
          NetworkEmptyState(
            title: 'Keine Familien in der Nähe',
            description: 'Schau später wieder vorbei.',
            actionLabel: 'Familien einladen',
            onAction: () => acted = true,
          ),
        ),
      );
      expect(find.text('Keine Familien in der Nähe'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(acted, isTrue);
    });

    testWidgets('ohne Aktion kein Button', (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkEmptyState(
            title: 'Alle gesehen',
            description: 'Kein Druck.',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('SafetyMenu', () {
    testWidgets('öffnet Melden/Blockieren und Block löst Callback aus',
        (tester) async {
      var blocked = false;
      await tester.pumpWidget(
        _host(
          SafetyMenu(
            userId: 'u1',
            userName: 'Familie Aylin',
            onBlock: () => blocked = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Melden'), findsOneWidget);
      expect(find.text('Blockieren'), findsOneWidget);
      await tester.tap(find.text('Blockieren'));
      await tester.pumpAndSettle();
      expect(blocked, isTrue);
    });
  });
}
