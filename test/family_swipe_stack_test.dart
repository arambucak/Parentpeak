import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/ui/widgets/network/family_swipe_stack.dart';

const card = FamilySwipeCardData(
  id: 'family-1',
  name: 'Familie Sommer',
  city: 'Berlin',
  kids: '3 Jahre',
  bio: 'Wir sind gerne draussen.',
  tags: ['Deutsch', 'Spielplatz'],
  reasons: ['In deiner Stadt'],
  meta: '2 km',
);

void main() {
  for (final height in [420.0, 530.0, 640.0]) {
    testWidgets('card uses $height pixels without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 360,
                  child: FamilySwipeStack(
                    cards: const [card],
                    cardHeight: height,
                    likeLabel: 'Interessiert',
                    passLabel: 'Nicht jetzt',
                    onLike: (_) {},
                    onPass: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.onPanUpdate != null,
      );
      expect(tester.getSize(gesture).height, height);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('both decisions still work with a resized card', (tester) async {
    final liked = <String>[];
    final passed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FamilySwipeStack(
              cards: const [card],
              cardHeight: 530,
              likeLabel: 'Interessiert',
              passLabel: 'Nicht jetzt',
              onLike: (card) => liked.add(card.id),
              onPass: (card) => passed.add(card.id),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Interessiert'));
    await tester.pumpAndSettle();
    expect(liked, ['family-1']);
    await tester.tap(find.text('Nicht jetzt'));
    await tester.pumpAndSettle();
    expect(passed, ['family-1']);
    expect(tester.takeException(), isNull);
  });
}
