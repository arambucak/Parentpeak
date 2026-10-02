import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/ui/widgets/user_avatar.dart';

/// Widget-Test für das im Kalender genutzte UserAvatar-Widget (Personen-Badge).
/// Ohne photoUrl rendert es die Initiale ohne Netzwerk-/Firebase-Zugriff.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('zeigt Initiale, wenn kein Foto vorhanden ist', (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: 'Eltern', radius: 10)));
    expect(find.text('E'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('zeigt Gruppen-Icon bei isGroup', (tester) async {
    await tester.pumpWidget(
        wrap(const UserAvatar(name: 'Team', radius: 12, isGroup: true)));
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
  });

  testWidgets('leerer Name fällt auf Platzhalter zurück', (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: '', radius: 10)));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('stabile Farbe für gleichen Namen', (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: 'Lena', radius: 10)));
    final a = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    await tester.pumpWidget(wrap(const UserAvatar(name: 'Lena', radius: 10)));
    final b = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(a.backgroundColor, b.backgroundColor);
  });
}
