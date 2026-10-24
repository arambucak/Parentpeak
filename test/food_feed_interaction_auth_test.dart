import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/gemeinsam_satt_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    dotenv.loadFromString(
      envString:
          'BACKEND_BASE_URL=https://backend.example.test\nBACKEND_API_TOKEN=shared-token',
    );
  });
  tearDown(dotenv.clean);

  GemeinsamSattBackendService service(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
  }) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return GemeinsamSattBackendService(
      httpClient: client,
      firebaseTokenProvider: token ?? () async => 'firebase-token',
    );
  }

  final calls = <String, Future<Object?> Function(GemeinsamSattBackendService)>{
    'rate': (api) =>
        api.rateRecipe(recipeId: 'recipe', userId: 'owner', rating: 4),
    'comments': (api) => api.createOfferComment(
        recipeId: 'recipe', userId: 'owner', text: 'Thank you'),
    'reserve': (api) =>
        api.reserveOffer(recipeId: 'recipe', userId: 'owner', portions: 2),
    'cancel': (api) =>
        api.cancelOfferReservation(recipeId: 'recipe', userId: 'owner'),
    'complete': (api) =>
        api.completeOfferShare(recipeId: 'recipe', userId: 'owner'),
    'report': (api) => api.reportOffer(
        recipeId: 'recipe', userId: 'owner', reason: 'incorrect'),
    'reservations': (api) =>
        api.fetchOfferReservationSummary(recipeId: 'recipe', userId: 'owner'),
  };

  for (final entry in calls.entries) {
    test('${entry.key} sends Firebase and preserves actor/payload contract',
        () async {
      var requests = 0;
      final api = service((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        final suffix = entry.key == 'cancel' ? 'reserve' : entry.key;
        expect(request.url.path, '/api/food-feed/recipes/recipe/$suffix');
        final method = entry.key == 'cancel'
            ? 'DELETE'
            : entry.key == 'reservations'
                ? 'GET'
                : 'POST';
        expect(request.method, method);
        if (method != 'POST') {
          expect(request.url.queryParameters['userId'], 'owner');
        } else {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
              body[entry.key == 'report' ? 'reportedById' : 'userId'], 'owner');
          if (entry.key == 'rate') expect(body['rating'], 4);
          if (entry.key == 'reserve') expect(body['portions'], 2);
          if (entry.key == 'comments') expect(body['text'], 'Thank you');
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'rating': {'id': 'rating', 'rating': 4, 'userId': 'owner'},
            'comment': {'id': 'comment', 'userId': 'owner'},
            'reservedPortions': 2,
            'myReservation': {'userId': 'owner'},
          }),
          ['rate', 'comments', 'reserve', 'report'].contains(entry.key)
              ? 201
              : 200,
        );
      });
      expect(await entry.value(api), isNotNull);
      expect(requests, 1);
      expect(api.lastSyncError, isNull);
    });

    for (final token in <String?>[null, '', '   ', 'throws']) {
      test('${entry.key} blocks missing/broken Firebase ($token) before HTTP',
          () async {
        var requests = 0;
        final api = service((_) async {
          requests++;
          return http.Response('{}', 200);
        }, token: () async {
          if (token == 'throws') throw StateError('Token unavailable');
          return token;
        });
        final result = await entry.value(api);
        expect(result == null || result == false, isTrue);
        expect(api.lastSyncError, isNotEmpty);
        expect(requests, 0);
      });
    }
    for (final status in [401, 403, 500, 503]) {
      test('${entry.key} HTTP $status never becomes success', () async {
        final api =
            service((_) async => http.Response('{"error":"Rejected"}', status));
        final result = await entry.value(api);
        expect(result == null || result == false, isTrue);
        expect(api.lastSyncError, contains('$status'));
      });
    }
    test('${entry.key} network failure never becomes success', () async {
      final api = service((_) async => throw http.ClientException('Offline'));
      final result = await entry.value(api);
      expect(result == null || result == false, isTrue);
      expect(api.lastSyncError, isNotEmpty);
    });
  }

  test('personal read/cancel encode identity as one query value', () async {
    final api = service((request) async {
      expect(request.url.queryParameters, {'userId': 'owner&userId=other'});
      return http.Response('{"success":true,"reservedPortions":0}', 200);
    });
    expect(
        await api.cancelOfferReservation(
            recipeId: 'recipe', userId: 'owner&userId=other'),
        isTrue);
    expect(
        await api.fetchOfferReservationSummary(
            recipeId: 'recipe', userId: 'owner&userId=other'),
        isNotNull);
  });

  test('public comments do not resolve Firebase or use shared credentials',
      () async {
    final api = service((request) async {
      expect(request.method, 'GET');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('{"comments":[{"id":"comment"}]}', 200);
    },
        token: () async =>
            throw StateError('Public read must not resolve token'));
    expect(await api.fetchOfferComments(recipeId: 'recipe'), hasLength(1));
    expect(api.lastSyncError, isNull);
  });
}
