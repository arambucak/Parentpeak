import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/models/ai_memory.dart';
import 'package:parentpeak/logic/chat_memory_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stub-Client, der die aufgerufenen Endpunkte/Bodies aufzeichnet und
/// vorbereitete JSON-Antworten liefert.
class _StubApiClient extends BackendApiClient {
  _StubApiClient() : super(baseUrl: 'https://example.invalid');

  final List<String> getPaths = [];
  final List<String> putPaths = [];
  final List<String> postPaths = [];
  final List<String> deletePaths = [];
  final List<Map<String, dynamic>> bodies = [];

  dynamic getResponse;
  Map<String, dynamic> putResponse = const {};
  Map<String, dynamic> postResponse = const {};

  @override
  BackendApiClient withRequestGuard(void Function() guard) {
    guard();
    return this;
  }

  @override
  Future<dynamic> getJson(String path) async {
    getPaths.add(path);
    return getResponse;
  }

  @override
  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    putPaths.add(path);
    bodies.add(body);
    return putResponse;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    postPaths.add(path);
    bodies.add(body);
    return postResponse;
  }

  @override
  Future<void> delete(String path) async {
    deletePaths.add(path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('AiMemoryService', () {
    test('getSettings liest /ai/settings und parst enabled', () async {
      await ChatMemoryConsent.instance.grant(ChatMemoryConsent.instance.scope);
      final client = _StubApiClient()
        ..getResponse = {
          'enabled': true,
          'consentVersion': ChatMemoryConsent.version,
        };
      final service = AiMemoryService(apiClient: client);

      final settings = await service.getSettings();

      expect(client.getPaths, ['/ai/settings']);
      expect(settings.enabled, isTrue);
    });

    test('setEnabled sendet PUT /ai/settings mit boolean', () async {
      final client = _StubApiClient()..putResponse = {'enabled': false};
      final service = AiMemoryService(apiClient: client);

      final result = await service.setEnabled(false);

      expect(client.putPaths, ['/ai/settings']);
      expect(client.bodies.single['enabled'], isFalse);
      expect(result.enabled, isFalse);
    });

    test('getChildren parst die items-Liste inkl. Memory', () async {
      final client = _StubApiClient()
        ..getResponse = {
          'items': [
            {
              'id': 'c1',
              'userId': 'u1',
              'name': 'Mia',
              'birthDate': '2022-05-01T00:00:00.000Z',
              'gender': 'w',
              'memoryItems': [
                {
                  'id': 'm1',
                  'childId': 'c1',
                  'category': 'topic',
                  'key': 'schlaf',
                  'value': 'braucht Einschlafbegleitung',
                  'status': 'confirmed',
                },
              ],
            },
          ],
        };
      final service = AiMemoryService(apiClient: client);

      final children = await service.getChildren();

      expect(client.getPaths, ['/ai/children']);
      expect(children, hasLength(1));
      expect(children.first.name, 'Mia');
      expect(children.first.memoryItems.single.key, 'schlaf');
    });

    test(
      'createChild sends neutral profile and retains display name locally',
      () async {
        await ChatMemoryConsent.instance.grant(
          ChatMemoryConsent.instance.scope,
        );
        final client = _StubApiClient()
          ..postResponse = {
            'item': {'id': 'c2', 'userId': 'u1', 'name': 'Ben'},
          };
        final service = AiMemoryService(apiClient: client);

        final child = await service.createChild(name: '  Ben  ');

        expect(client.postPaths, ['/ai/children']);
        expect(client.bodies.single['name'], '[CHILD_1]');
        expect(child.name, 'Ben');
        expect(child.id, 'c2');
      },
    );

    test('saveMemory sendet POST an das richtige Kind + Felder', () async {
      await ChatMemoryConsent.instance.grant(ChatMemoryConsent.instance.scope);
      final client = _StubApiClient()
        ..getResponse = {'items': []}
        ..postResponse = {
          'item': {
            'id': 'm9',
            'childId': 'c1',
            'category': 'topic',
            'key': 'schlaf',
            'value': 'Routine hilft',
            'status': 'confirmed',
          },
        };
      final service = AiMemoryService(apiClient: client);

      final item = await service.saveMemory(
        'c1',
        category: 'topic',
        key: 'schlaf',
        value: 'Routine hilft',
      );

      expect(client.postPaths, ['/ai/children/c1/memory']);
      expect(client.bodies.single['category'], 'topic');
      expect(client.bodies.single['status'], 'confirmed');
      expect(item.value, 'Routine hilft');
    });

    test('deleteChild und deleteMemory treffen die richtigen Pfade', () async {
      final client = _StubApiClient();
      final service = AiMemoryService(apiClient: client);

      await service.deleteChild('c1');
      await service.deleteMemory('c1', 'm1');

      expect(client.deletePaths, [
        '/ai/children/c1',
        '/ai/children/c1/memory/m1',
      ]);
    });
  });

  group('AiMemoryService.resolveActiveChildId (Chat-Auto-Auswahl)', () {
    AiChildProfile child(String id) =>
        AiChildProfile(id: id, userId: 'u1', name: 'K-$id');

    test('null, wenn das Gedächtnis AUS ist (auch mit Kindern)', () {
      final result = AiMemoryService.resolveActiveChildId(
        memoryEnabled: false,
        children: [child('c1')],
      );
      expect(result, isNull);
    });

    test('null, wenn keine Kinder vorhanden sind', () {
      final result = AiMemoryService.resolveActiveChildId(
        memoryEnabled: true,
        children: const [],
      );
      expect(result, isNull);
    });

    test('ein Kind -> dieses wird gewählt', () {
      final result = AiMemoryService.resolveActiveChildId(
        memoryEnabled: true,
        children: [child('c1')],
      );
      expect(result, 'c1');
    });

    test('mehrere Kinder -> erstes (zuletzt aktualisiertes) wird gewählt', () {
      final result = AiMemoryService.resolveActiveChildId(
        memoryEnabled: true,
        children: [child('neu'), child('alt')],
      );
      expect(result, 'neu');
    });

    test('überspringt Kinder mit leerer ID', () {
      final result = AiMemoryService.resolveActiveChildId(
        memoryEnabled: true,
        children: [child(''), child('c2')],
      );
      expect(result, 'c2');
    });
  });
}
