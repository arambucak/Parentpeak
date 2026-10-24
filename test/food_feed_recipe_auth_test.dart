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

  Future<SharedRecipe?> create(
    GemeinsamSattBackendService api, {
    String? familyId,
  }) =>
      api.createRecipe(
        userId: 'owner',
        familyId: familyId,
        title: 'Family lunch',
        category: 'dinner',
        difficulty: 'leicht',
        servings: 4,
        ingredients: [
          {'name': 'Rice', 'quantity': '200', 'unit': 'g'},
        ],
        instructions: ['Cook rice'],
      );

  final recipe = {
    'id': 'recipe',
    'creatorUserId': 'owner',
    'title': 'Family lunch',
    'category': 'dinner',
    'difficulty': 'leicht',
    'servings': 4,
    'ingredients': jsonEncode([
      {'name': 'Rice', 'quantity': '200', 'unit': 'g'},
    ]),
    'instructions': jsonEncode(['Cook rice']),
  };

  test('create uses Firebase, preserves recipe content and omits absent family',
      () async {
    final api = service((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/food-feed/recipes');
      expect(request.headers['Authorization'], 'Bearer firebase-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['userId'], 'owner');
      expect(body.containsKey('familyId'), isFalse);
      expect(body['title'], 'Family lunch');
      expect(body['instructions'], ['Cook rice']);
      return http.Response(jsonEncode({'recipe': recipe}), 201);
    });
    final result = await create(api);
    expect(result?.id, 'recipe');
    expect(result?.creatorUserId, 'owner');
    expect(api.lastSyncError, isNull);
  });

  test('an explicit family claim is sent for backend ownership validation',
      () async {
    final api = service((request) async {
      expect(jsonDecode(request.body)['familyId'], 'own-family-id');
      return http.Response(jsonEncode({'recipe': recipe}), 201);
    });
    expect(await create(api, familyId: 'own-family-id'), isNotNull);
  });

  test('update and delete send only the Firebase token, never static fallback',
      () async {
    final methods = <String>[];
    final api = service((request) async {
      methods.add(request.method);
      expect(request.headers['Authorization'], 'Bearer firebase-token');
      expect(request.url.path, '/api/food-feed/recipes/recipe');
      expect(jsonDecode(request.body)['userId'], 'owner');
      if (request.method == 'DELETE') {
        expect(request.url.queryParameters['userId'], 'owner');
        return http.Response('{"success":true}', 200);
      }
      expect(jsonDecode(request.body)['title'], 'Changed');
      return http.Response(
          jsonEncode({
            'recipe': {...recipe, 'title': 'Changed'}
          }),
          200);
    });
    expect(
        (await api.updateRecipe(
                id: 'recipe', userId: 'owner', title: 'Changed'))
            ?.title,
        'Changed');
    expect(await api.deleteRecipe(id: 'recipe', userId: 'owner'), isTrue);
    expect(methods, ['PUT', 'DELETE']);
    expect(api.lastSyncError, isNull);
  });

  for (final missingToken in <String?>[null, '', '   ']) {
    test(
        'all CRUD operations block missing/blank Firebase token: $missingToken',
        () async {
      var requests = 0;
      final api = service((_) async {
        requests++;
        return http.Response('{}', 200);
      }, token: () async => missingToken);
      expect(await create(api), isNull);
      expect(api.lastSyncError, isNotEmpty);
      expect(await api.updateRecipe(id: 'recipe', userId: 'owner'), isNull);
      expect(api.lastSyncError, isNotEmpty);
      expect(await api.deleteRecipe(id: 'recipe', userId: 'owner'), isFalse);
      expect(api.lastSyncError, isNotEmpty);
      expect(requests, 0);
    });
  }

  test('token errors block all CRUD requests instead of using shared token',
      () async {
    var requests = 0;
    final api = service((_) async {
      requests++;
      return http.Response('{}', 200);
    }, token: () async => throw StateError('Token unavailable'));
    expect(await create(api), isNull);
    expect(await api.updateRecipe(id: 'recipe', userId: 'owner'), isNull);
    expect(await api.deleteRecipe(id: 'recipe', userId: 'owner'), isFalse);
    expect(requests, 0);
    expect(api.lastSyncError, isNotEmpty);
  });

  for (final status in [401, 403, 500, 503]) {
    test('CRUD HTTP $status never becomes local success', () async {
      final api = service(
          (_) async => http.Response('{"error":"Request rejected"}', status));
      expect(await create(api), isNull);
      expect(api.lastSyncError, contains('$status'));
      expect(await api.updateRecipe(id: 'recipe', userId: 'owner'), isNull);
      expect(api.lastSyncError, isNotEmpty);
      expect(await api.deleteRecipe(id: 'recipe', userId: 'owner'), isFalse);
      expect(api.lastSyncError, isNotEmpty);
    });
  }

  test('network errors never become local CRUD success', () async {
    final api = service((_) async => throw http.ClientException('Offline'));
    expect(await create(api), isNull);
    expect(await api.updateRecipe(id: 'recipe', userId: 'owner'), isNull);
    expect(await api.deleteRecipe(id: 'recipe', userId: 'owner'), isFalse);
    expect(api.lastSyncError, isNotEmpty);
  });

  test('public list and details work without resolving Firebase tokens',
      () async {
    final api = service((request) async {
      expect(request.method, 'GET');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response(
          jsonEncode(request.url.path.endsWith('/recipe')
              ? {'recipe': recipe}
              : {
                  'recipes': [recipe],
                  'total': 1,
                }),
          200);
    },
        token: () async =>
            throw StateError('Public reads must not request token'));
    final list = await api.fetchRecipes();
    expect(list['total'], 1);
    expect(await api.getRecipe('recipe'), isNotNull);
    expect(api.lastSyncError, isNull);
  });
}
