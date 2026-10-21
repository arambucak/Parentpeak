import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/payment_service.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/ui/payment_screen.dart';

class _SheetPayments extends PaymentService {
  _SheetPayments(BackendApiClient client) : super(apiClient: client);

  @override
  Future<Map<String, dynamic>> initiateStripePayment({
    required String eventId, required String hosterId, required double amount,
  }) async => {
    'id': 'order1', 'eventId': eventId, 'hosterId': hosterId,
    'amount': 12.5, 'currency': 'EUR',
    'stripePaymentIntentId': 'pi_order1', 'clientSecret': 'pi_order1_secret_not_proof',
  };
}

MeetupEvent _buildEvent() => MeetupEvent(
  id: 'evt_1', hosterId: 'recipient-host', title: 'Test Event',
  description: 'Beschreibung', category: EventCategory.socialGathering,
  ageGroups: const [AgeGroup.mixed], location: 'Berlin',
  latitude: 52.52, longitude: 13.405,
  eventDate: DateTime.now().add(const Duration(days: 1)),
  createdAt: DateTime.now(), maxParticipants: 10, photoUrl: '', price: 12.5,
);

void main() {
  testWidgets('PaymentScreen warns when Stripe is unavailable', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(MaterialApp(
        home: PaymentScreen(event: _buildEvent(), amount: 12.5)));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('AGB & Datenschutz akzeptieren'));
      await tester.pump();
      await tester.tap(find.text('Jetzt 12.50 € zahlen'));
      await tester.pump();
      await tester.pump();
      expect(find.text(
        'Stripe ist auf dieser Plattform nicht verfügbar oder nicht konfiguriert. Bitte kontaktiere den Support.'),
        findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final responseStatus in [200, 503]) {
    testWidgets('stored-event checkout response $responseStatus never creates or republishes events',
      (tester) async {
        dotenv.loadFromString(envString: 'STRIPE_PUBLISHABLE_KEY=pk_test_mock');
        addTearDown(dotenv.clean);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          tester.view.physicalSize = const Size(800, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          final paths = <String>[];
          final client = MockClient((request) async {
            paths.add('${request.method} ${request.url.path}');
            expect(request.headers['Authorization'], 'Bearer firebase-payer-token');
            if (request.method == 'POST') {
              expect(request.url.path, '/payments/confirm');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['eventId'], 'evt_1');
              expect(body['hosterId'], 'recipient-host');
              expect(body['amount'], 12.5);
              expect(body['providerTransactionRef'], 'pi_order1');
              expect(body.containsKey('providerVerified'), isFalse);
              expect(body.containsKey('status'), isFalse);
            } else {
              expect(request.url.path, '/payments/transactions/order1');
            }
            return http.Response(jsonEncode({
              'item': {
                'id': 'order1', 'eventId': 'evt_1', 'hosterId': 'recipient-host',
                'payerUid': 'firebase-payer', 'amount': 12.5, 'currency': 'EUR',
                'status': 'completed', 'paymentMethod': 'stripe',
              }, 'error': 'Provider unavailable',
            }), responseStatus);
          });
          addTearDown(client.close);
          await tester.pumpWidget(MaterialApp(home: PaymentScreen(
            event: _buildEvent(), amount: 12.5,
            paymentService: _SheetPayments(BackendApiClient(
              baseUrl: 'http://127.0.0.1:9', requireAuthToken: true,
              authTokenProvider: () async => 'firebase-payer-token', httpClient: client,
            )),
          )));
          await tester.pumpAndSettle();
          await tester.tap(find.text('AGB & Datenschutz akzeptieren'));
          await tester.pump();
          await tester.tap(find.text('Jetzt 12.50 € zahlen'));
          await tester.pumpAndSettle();
          if (responseStatus == 200) {
            expect(find.textContaining('wurde bestätigt!'), findsOneWidget);
            expect(paths, ['POST /payments/confirm', 'GET /payments/transactions/order1']);
          } else {
            expect(find.textContaining('Zahlungsfehler:'), findsOneWidget);
            expect(find.textContaining('wurde bestätigt!'), findsNothing);
            expect(paths, ['POST /payments/confirm']);
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
  }
}
