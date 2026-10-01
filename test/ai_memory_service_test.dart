import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';

class _FakeApiClient extends BackendApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.invalid');

  final calls = <String>[];

  @override
  Future<dynamic> getJson(String path) async {
    calls.add('GET $path');
    if (path == '/ai/settings') return {'enabled': true};
    if (path == '/ai/children') {
      return {
        'items': [
          {
            'id': 'child-1',
            'userId': 'user-1',
            'name': 'Lina',
            'memoryItems': [
              {
                'id': 'memory-1',
                'childId': 'child-1',
                'category': 'medical_clarification',
                'key': 'Urologisch abgeklärt',
                'value': 'Ohne auffälligen Befund',
                'status': 'confirmed',
              },
            ],
          },
        ],
      };
    }
    return {'items': const []};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    calls.add('POST $path');
    return {
      'item': {
        'id': 'child-2',
        'userId': 'user-1',
        'name': body['name'],
      },
    };
  }

  @override
  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    calls.add('PUT $path');
    if (path == '/ai/settings') return {'enabled': body['enabled']};
    return {
      'item': {
        'id': 'child-1',
        'userId': 'user-1',
        'name': body['name'] ?? 'Lina',
      },
    };
  }

  @override
  Future<void> delete(String path) async {
    calls.add('DELETE $path');
  }
}

void main() {
  test('loads settings and child profiles from the AI memory API', () async {
    final api = _FakeApiClient();
    final service = AiMemoryService(apiClient: api);

    final settings = await service.getSettings();
    final children = await service.getChildren();

    expect(settings.enabled, isTrue);
    expect(children.single.name, 'Lina');
    expect(children.single.memoryItems.single.value, 'Ohne auffälligen Befund');
    expect(api.calls, contains('GET /ai/settings'));
    expect(api.calls, contains('GET /ai/children'));
  });

  test('sends child profile and memory mutations to scoped endpoints', () async {
    final api = _FakeApiClient();
    final service = AiMemoryService(apiClient: api);

    await service.setEnabled(true);
    await service.createChild(name: 'Mika');
    await service.saveMemory(
      'child-1',
      category: 'tried_strategy',
      key: 'Fester Toiletten-Rhythmus',
      value: 'Wurde ausprobiert',
    );
    await service.deleteMemory('child-1', 'memory-1');

    expect(api.calls, contains('PUT /ai/settings'));
    expect(api.calls, contains('POST /ai/children'));
    expect(api.calls, contains('POST /ai/children/child-1/memory'));
    expect(api.calls, contains('DELETE /ai/children/child-1/memory/memory-1'));
  });
}
