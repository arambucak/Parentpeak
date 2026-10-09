import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/models/meal_plan.dart';
import 'package:parentpeak/services/meal_planner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ProfileAccountStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());

  BackendApiClient api(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
  }) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return BackendApiClient(
      baseUrl: 'https://backend.example',
      httpClient: client,
      authTokenProvider: token ?? () async => 'firebase-$uid',
      requireAuthToken: true,
    );
  }

  MealPlannerService service(BackendApiClient client) =>
      MealPlannerService(apiClient: client, accountStore: store);

  final meal = Meal(
    id: 'm1',
    title: 'Pasta',
    type: MealType.lunch,
    description: null,
    ingredients: const ['noodles'],
  );

  test('getWeekMealPlan uses own selector, Firebase token, no family claim', () async {
    late http.Request captured;
    final svc = service(api((request) async {
      captured = request;
      return http.Response('[]', 200);
    }));
    await svc.getWeekMealPlan(DateTime.utc(2026, 1, 1));
    expect(captured.headers['Authorization'], 'Bearer firebase-a');
    // own-Selector im Pfad, keine globale familyId.
    expect(captured.url.path, contains('/own/week'));
    expect(captured.url.queryParameters.containsKey('familyId'), isFalse);
  });

  test('getMealPlan uses own selector in path', () async {
    late http.Request captured;
    final svc = service(api((request) async {
      captured = request;
      return http.Response('{"date":"2026-01-01T00:00:00.000Z","meals":[]}', 200);
    }));
    await svc.getMealPlan(DateTime.utc(2026, 1, 1));
    expect(captured.url.path, contains('/own'));
    expect(captured.url.queryParameters.containsKey('date'), isTrue);
  });

  test('addMeal targets corrected /api/meals/ path', () async {
    late http.Request captured;
    final svc = service(api((request) async {
      captured = request;
      return http.Response(
        '{"id":"x","title":"Pasta","type":"lunch","ingredients":[]}',
        201,
      );
    }));
    await svc.addMeal('plan-1', meal);
    expect(captured.url.path, contains('/api/meals/plan-1'));
    final body = jsonDecode(captured.body) as Map;
    expect(body.containsKey('familyId'), isFalse);
    expect(body.containsKey('userId'), isFalse);
  });

  test('updateMeal and deleteMeal use /api/meals/ path', () async {
    final paths = <String>[];
    final svc = service(api((request) async {
      paths.add(request.url.path);
      return http.Response(
        '{"id":"x","title":"Pasta","type":"lunch","ingredients":[]}',
        200,
      );
    }));
    await svc.updateMeal('m1', meal);
    await svc.deleteMeal('m1');
    expect(paths.every((p) => p.contains('/api/meals/m1')), isTrue);
  });

  for (final status in [401, 403, 404, 503]) {
    test('error $status surfaces as exception, not silent empty', () async {
      final svc = service(api((_) async => http.Response('{"error":"x"}', status)));
      await expectLater(
        svc.getWeekMealPlan(DateTime.utc(2026, 1, 1)),
        throwsA(isA<BackendApiException>()
            .having((e) => e.statusCode, 'status', status)),
      );
    });
  }

  test('guest without session makes no HTTP call', () async {
    uid = null;
    store.synchronize();
    var count = 0;
    final svc = service(api((_) async {
      count++;
      return http.Response('[]', 200);
    }));
    await expectLater(
      svc.getWeekMealPlan(DateTime.utc(2026, 1, 1)),
      throwsStateError,
    );
    expect(count, 0);
  });

  test('missing token sends no anonymous request', () async {
    var count = 0;
    final svc = service(api((_) async {
      count++;
      return http.Response('[]', 200);
    }, token: () async => null));
    await expectLater(
      svc.getWeekMealPlan(DateTime.utc(2026, 1, 1)),
      throwsStateError,
    );
    expect(count, 0);
  });

  test('account switch mid-request discards result', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final svc = service(api((_) {
      started.complete();
      return response.future;
    }));
    final result = svc.getWeekMealPlan(DateTime.utc(2026, 1, 1));
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    uid = 'b';
    store.synchronize();
    response.complete(http.Response('[]', 200));
    await checked;
  });
}
