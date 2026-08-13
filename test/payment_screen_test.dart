import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/payment_screen.dart';

MeetupEvent _buildEvent() {
  return MeetupEvent(
    id: 'evt_1',
    hosterId: 'user_1',
    title: 'Test Event',
    description: 'Beschreibung',
    category: EventCategory.socialGathering,
    ageGroups: const [AgeGroup.mixed],
    location: 'Berlin',
    latitude: 52.52,
    longitude: 13.405,
    eventDate: DateTime.now().add(const Duration(days: 1)),
    createdAt: DateTime.now(),
    maxParticipants: 10,
    photoUrl: '',
  );
}

void main() {
  testWidgets('PaymentScreen warns when Stripe key is missing',
      (WidgetTester tester) async {
    // Use a tall viewport so all widgets are visible without scrolling
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Override platform to Linux so isStripePaymentSheetSupportedPlatform()
    // returns false → _stripeAvailable = false → SnackBar warning is shown.
    // Must be reset in finally so the test framework invariant check passes.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentScreen(
            event: _buildEvent(),
            amount: 9.99,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Toggle terms checkbox
      await tester.tap(find.text('AGB & Datenschutz akzeptieren'));
      await tester.pump();

      // Tap the pay button — Stripe not supported on Linux → warning shown
      await tester.tap(find.text('Jetzt 9.99 € zahlen'));
      await tester.pump(); // process tap → _processPayment called → showSnackBar
      await tester.pump(); // rebuild scaffold to show SnackBar
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    expect(
      find.text(
        'Stripe ist aktuell nicht konfiguriert. Bitte wähle PayPal oder kontaktiere den Support.',
      ),
      findsOneWidget,
    );
  });
}
