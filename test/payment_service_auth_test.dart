import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/payment_service.dart';

Map<String, dynamic> _transaction({String status = 'pending'}) => {
  'id': 'order-payment-auth',
  'eventId': 'event1',
  'hosterId': 'recipient-host',
  'payerUid': 'firebase-payer',
  'amount': 12.5,
  'currency': 'EUR',
  'status': status,
  'paymentMethod': 'stripe',
  'stripePaymentIntentId': 'pi_order1',
};

PaymentService _service(
  Future<http.Response> Function(http.Request) handle, {
  Future<String?> Function()? tokenProvider,
}) => PaymentService(
  apiClient: BackendApiClient(
    baseUrl: 'http://127.0.0.1:9',
    requireAuthToken: true,
    authToken: 'shared-token-must-not-be-used',
    authTokenProvider: tokenProvider ?? () async => 'firebase-payer-token',
    httpClient: MockClient(handle),
  ),
);

Future<dynamic> _confirm(PaymentService service) => service.confirmPayment(
  eventId: 'event1',
  hosterId: 'recipient-host',
  amount: 12.5,
  paymentMethod: 'stripe',
  stripePaymentIntentId: 'pi_order1',
  providerTransactionRef: 'pi_order1',
  initialStatus: 'completed',
  providerVerified: true,
);

void main() {
  setUp(() => dotenv.loadFromString(envString: 'BACKEND_BASE_URL=http://127.0.0.1:9'));
  tearDown(dotenv.clean);

  test('confirmation uses payer token, not recipient identity or client proof', () async {
    final service = _service((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/payments/confirm');
      expect(request.headers['Authorization'], 'Bearer firebase-payer-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['hosterId'], 'recipient-host');
      expect(body['stripePaymentIntentId'], 'pi_order1');
      expect(body['providerTransactionRef'], 'pi_order1');
      for (final field in ['userId', 'payerUid', 'payerId', 'status', 'providerVerified', 'verified', 'clientSecret']) {
        expect(body.containsKey(field), isFalse, reason: field);
      }
      return http.Response(jsonEncode({'item': _transaction()}), 200);
    });
    final transaction = await _confirm(service);
    expect(transaction.hosterId, 'recipient-host');
    expect(transaction.status, 'pending');
    expect(service.lastSyncError, isNull);
  });

  test('completion is accepted only from backend response', () async {
    final service = _service((_) async => http.Response(
      jsonEncode({'item': _transaction(status: 'completed')}), 200));
    expect((await _confirm(service)).status, 'completed');
  });

  for (final status in [401, 403, 409, 503]) {
    test('failed confirmation $status is surfaced without payment success', () async {
      final service = _service((_) async => http.Response(
        jsonEncode({'error': 'Provider proof rejected'}), status));
      await expectLater(_confirm(service), throwsStateError);
      expect(service.lastSyncError, contains('$status'));
    });
  }

  test('missing Firebase session fails before any request', () async {
    var calls = 0;
    final service = _service((_) async {
      calls++;
      return http.Response(jsonEncode({'item': _transaction()}), 200);
    }, tokenProvider: () async => null);
    await expectLater(_confirm(service), throwsStateError);
    expect(calls, 0);
    expect(service.lastSyncError, contains('Firebase session required'));
  });

  test('missing backend status remains pending', () async {
    final raw = _transaction()..remove('status');
    final service = _service((_) async => http.Response(jsonEncode({'item': raw}), 200));
    expect((await _confirm(service)).status, 'pending');
  });

  test('refund succeeds only for confirmed server refunded status', () async {
    for (final status in ['pending', 'completed', 'refunded']) {
      final service = _service((request) async {
        expect(request.url.path, '/payments/transactions/order-payment-auth/refund');
        expect(request.headers['Authorization'], 'Bearer firebase-payer-token');
        return http.Response(jsonEncode({'item': _transaction(status: status)}), 200);
      });
      expect(await service.refundPayment('order-payment-auth'), status == 'refunded');
    }
    expect(await _service((_) async => http.Response('unavailable', 503))
      .refundPayment('order-payment-auth'), isFalse);
  });

  test('failed backend reads do not fall back to cached success', () async {
    final service = _service((_) async => http.Response('unavailable', 503));
    await expectLater(service.getTransaction('order-payment-auth'), throwsStateError);
    await expectLater(service.getHostTransactions('recipient-host'), throwsStateError);
  });

  test('PayPal unavailable response is an explicit failure', () async {
    final service = _service((request) async {
      expect(request.url.path, '/payments/paypal/initiate');
      return http.Response(jsonEncode({'error': 'Unsupported provider'}), 503);
    });
    await expectLater(service.initiatePayPalPayment(
      eventId: 'event1', hosterId: 'recipient-host', amount: 12.5), throwsStateError);
  });
}
