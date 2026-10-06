import 'package:parentpeak/logic/family_hub_store.dart';

class FamilyHubTodos {
  FamilyHubTodos({FamilyHubStore? store})
      : _store = store ?? FamilyHubStore.instance;
  final FamilyHubStore _store;
  static int _counter = 0;

  List<Map<String, dynamic>> _decode(Map<String, dynamic> data) {
    final raw = data[FamilyHubStore.todoKey] ?? [];
    if (raw is! List) throw const FormatException('Invalid todo list');
    return raw.map((entry) {
      if (entry is! Map<String, dynamic> ||
          entry['text'] is! String ||
          (entry['done'] != null && entry['done'] is! bool) ||
          (entry['id'] is! String && entry['id'] is! int)) {
        throw const FormatException('Invalid todo entry');
      }
      return Map<String, dynamic>.from(entry);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> load(String scope) async =>
      _decode(await _store.read(expectedScope: scope));

  Future<List<Map<String, dynamic>>> _mutate(
      String scope, void Function(List<Map<String, dynamic>>) mutation) async {
    final data = await _store.update((data) {
      final todos = _decode(data);
      mutation(todos);
      data[FamilyHubStore.todoKey] = todos;
      return data;
    }, expectedScope: scope);
    return _decode(data);
  }

  Future<List<Map<String, dynamic>>> add(String scope, String text) {
    if (text.trim().isEmpty) throw ArgumentError.value(text, 'text');
    final id = 'todo_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    return _mutate(scope, (todos) => todos.insert(0, {
      'id': id, 'text': text.trim(), 'done': false,
    }));
  }

  Future<List<Map<String, dynamic>>> toggle(String scope, Object id) =>
      _mutate(scope, (todos) {
        final index = todos.indexWhere((todo) => todo['id'] == id);
        if (index == -1) throw StateError('Unknown todo');
        todos[index]['done'] = todos[index]['done'] != true;
      });

  Future<List<Map<String, dynamic>>> remove(String scope, Object id) =>
      _mutate(scope, (todos) {
        if (!todos.any((todo) => todo['id'] == id)) throw StateError('Unknown todo');
        todos.removeWhere((todo) => todo['id'] == id);
      });
}
