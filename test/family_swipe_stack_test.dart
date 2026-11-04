import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/widgets/network/family_illustration.dart';
import 'package:parentpeak/ui/widgets/network/family_swipe_stack.dart';

const card = FamilySwipeCardData(
  id: 'family-1',
  name: 'Familie Sommer',
  city: 'Berlin',
  kids: '3 Jahre',
  childCount: 1,
  familyForm: 'kernfamilie',
  bio: 'Wir sind gerne draussen.',
  tags: ['Deutsch', 'Spielplatz'],
  reasons: ['In deiner Stadt'],
  meta: '2 km',
);

class RecordingCanvas extends Fake implements Canvas {
  final heads = <int>[];
  final bodies = <Rect>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    heads.add(paint.color.toARGB32());
  }

  @override
  void drawPath(Path path, Paint paint) {
    bodies.add(path.getBounds());
  }
}

void main() {
  test('wizard family forms determine adults with a two-adult fallback', () {
    for (final form in [...MatchOptions.familyForms, '', 'custom', 'future']) {
      expect(
        FamilyIllustrationPainter(childCount: 1, familyForm: form).adultCount,
        form == 'alleinerziehend' ? 1 : 2,
        reason: form,
      );
    }
    expect(
      const FamilyIllustrationPainter(childCount: 1).adultCount,
      2,
    );
    expect(
      const FamilyIllustrationPainter(
        childCount: 1,
        familyForm: ' ALLEINERZIEHEND ',
      ).adultCount,
      1,
    );
  });

  for (final children in [0, 1, 3, 12]) {
    for (final form in ['kernfamilie', 'alleinerziehend']) {
      test('paints exactly $children children for $form without clipping', () {
        final canvas = RecordingCanvas();
        final painter = FamilyIllustrationPainter(
          childCount: children,
          familyForm: form,
        );
        painter.paint(canvas, const Size(280, 200));
        expect(
          canvas.heads.where(
            (color) => color == FamilyIllustrationPainter.childGreen.toARGB32(),
          ),
          hasLength(children),
        );
        expect(canvas.heads, hasLength(children + painter.adultCount));
        expect(canvas.bodies, hasLength(children + painter.adultCount));
        for (final bounds in canvas.bodies) {
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(280));
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(200));
        }
      });
    }
  }

  test('repaints when family composition changes', () {
    const original = FamilyIllustrationPainter(childCount: 1);
    expect(
      const FamilyIllustrationPainter(childCount: 3).shouldRepaint(original),
      isTrue,
    );
    expect(
      const FamilyIllustrationPainter(
        childCount: 1,
        familyForm: 'alleinerziehend',
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      const FamilyIllustrationPainter(
        childCount: 1,
        familyForm: 'patchwork',
      ).shouldRepaint(original),
      isFalse,
    );
  });

  testWidgets('card passes composition and keeps name larger than its initial',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilySwipeStack(
            cards: const [
              FamilySwipeCardData(
                id: 'single',
                name: 'Sommer',
                childCount: 3,
                familyForm: 'alleinerziehend',
              ),
            ],
            likeLabel: 'Interessiert',
            passLabel: 'Nicht jetzt',
            onLike: (_) {},
            onPass: (_) {},
          ),
        ),
      ),
    );
    final illustration =
        tester.widget<FamilyIllustration>(find.byType(FamilyIllustration));
    expect(illustration.childCount, 3);
    expect(illustration.familyForm, 'alleinerziehend');
    expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).radius, 14);
    final name = tester.widget<Text>(find.text('Sommer'));
    final initial = tester.widget<Text>(find.text('S'));
    expect(name.style!.fontSize, greaterThan(initial.style!.fontSize!));
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('full profile remains readable on a narrow card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 328,
              child: FamilySwipeStack(
                cards: const [
                  FamilySwipeCardData(
                    id: 'full',
                    name: 'Familie Sommer',
                    childCount: 3,
                    familyForm: 'kernfamilie',
                    city: 'Berlin',
                    kids: '3 Jahre · 5 Jahre · 8 Jahre',
                    bio: 'Wir sind gerne draussen und freuen uns auf '
                        'gemeinsame Spielplatz-Nachmittage.',
                    tags: ['Respekt', 'Empathie', 'Spielplatz', 'Ausfluege'],
                    reasons: ['In deiner Stadt', 'Aehnliche Interessen'],
                    meta: '2 km · Deutsch, Englisch, Franzoesisch',
                  ),
                ],
                cardHeight: 420,
                likeLabel: 'Interessiert',
                passLabel: 'Nicht jetzt',
                onLike: (_) {},
                onPass: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final details = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.primary == false,
    );
    await tester.drag(details, const Offset(0, -180));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: details, matching: find.byType(Scrollable)),
    );
    expect(scroll.position.pixels, greaterThan(0));
    expect(
      tester
          .getBottomLeft(
            find.text('2 km · Deutsch, Englisch, Franzoesisch'),
          )
          .dy,
      lessThanOrEqualTo(tester.getBottomLeft(details).dy),
    );
  });

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
    await tester.drag(
      find.byType(FamilyIllustration),
      const Offset(160, 0),
    );
    await tester.pumpAndSettle();
    expect(liked, ['family-1', 'family-1']);
    await tester.drag(
      find.byType(FamilyIllustration),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(passed, ['family-1', 'family-1']);
    expect(tester.takeException(), isNull);
  });
}
