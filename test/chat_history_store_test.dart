import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String? uid;
  late ChatAccountStore store;
  late ChatHistoryStore history;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ChatAccountStore(userIdProvider: () => uid);
    history = ChatHistoryStore(accountStore: store);
  });
  tearDown(() => store.dispose());

  void change(String? next) {
    uid = next;
    store.synchronize();
  }

  List<Map<String, dynamic>> sample() => [
        {'role': 'user', 'content': 'Mein Kind schläft schlecht'},
        {
          'role': 'assistant',
          'content': 'Das kann anstrengend sein.',
          'displayChildName': 'Lea',
          'timestamp': DateTime(2026, 11, 5, 21, 30),
        },
      ];

  test('saves and reloads the conversation for the same account', () async {
    await history.save(store.ticket, sample());
    final loaded = await history.load(store.ticket);
    expect(loaded.length, 2);
    expect(loaded[0]['role'], 'user');
    expect(loaded[0]['content'], 'Mein Kind schläft schlecht');
    expect(loaded[1]['role'], 'assistant');
    expect(loaded[1]['displayChildName'], 'Lea');
    expect(loaded[1]['timestamp'], isA<DateTime>());
  });

  test('history is isolated per account', () async {
    await history.save(store.ticket, sample());
    change('b');
    // Das andere Konto darf den Verlauf von Konto A nicht sehen.
    expect(await history.load(store.ticket), isEmpty);
    await history.save(store.ticket, [
      {'role': 'user', 'content': 'Anderes Konto'},
    ]);
    expect((await history.load(store.ticket)).single['content'], 'Anderes Konto');
    // Zurück zu A: dessen Verlauf ist weiterhin intakt.
    change('a');
    expect((await history.load(store.ticket)).length, 2);
  });

  test('guest accounts persist nothing', () async {
    change(null); // guest
    await history.save(store.ticket, sample());
    expect(await history.load(store.ticket), isEmpty);
  });

  test('clear removes the stored conversation', () async {
    await history.save(store.ticket, sample());
    expect(await history.load(store.ticket), isNotEmpty);
    await history.clear(store.ticket);
    expect(await history.load(store.ticket), isEmpty);
  });

  test('trims to the most recent messages', () async {
    final many = [
      for (var i = 0; i < ChatHistoryStore.maxStoredMessages + 15; i++)
        {'role': i.isEven ? 'user' : 'assistant', 'content': 'Nachricht $i'},
    ];
    await history.save(store.ticket, many);
    final loaded = await history.load(store.ticket);
    expect(loaded.length, ChatHistoryStore.maxStoredMessages);
    // Die jüngsten bleiben erhalten (letzte Nachricht ist die neueste).
    expect(loaded.last['content'],
        'Nachricht ${ChatHistoryStore.maxStoredMessages + 15 - 1}');
  });

  test('drops malformed entries on load', () async {
    await history.save(store.ticket, [
      {'role': 'user', 'content': 'gültig'},
      {'role': 'user', 'content': ''}, // leer → verworfen
      {'role': 'user'}, // kein content → verworfen
    ]);
    final loaded = await history.load(store.ticket);
    expect(loaded.length, 1);
    expect(loaded.single['content'], 'gültig');
  });
}
