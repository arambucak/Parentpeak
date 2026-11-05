import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_thread_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String? uid;
  late ChatAccountStore account;
  late ChatThreadStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    account = ChatAccountStore(userIdProvider: () => uid);
    store = ChatThreadStore(accountStore: account);
  });
  tearDown(() => account.dispose());

  void change(String? next) {
    uid = next;
    account.synchronize();
  }

  ChatThread thread(String id, String title, {int msg = 1}) => ChatThread(
        id: id,
        title: title,
        createdAt: DateTime(2026, 11, 5, 10),
        updatedAt: DateTime(2026, 11, 5, 10, id.hashCode % 60),
        messages: [
          for (var i = 0; i < msg; i++)
            {'role': i.isEven ? 'user' : 'assistant', 'content': 'm$i von $id'}
        ],
      );

  test('upserts and loads multiple threads sorted by recency', () async {
    await store.upsertThread(account.ticket, thread('t1', 'Schlaf'));
    await store.upsertThread(account.ticket, thread('t2', 'Streit'));
    final threads = await store.loadThreads(account.ticket);
    expect(threads.length, 2);
    // sortiert nach updatedAt absteigend
    expect(threads.first.updatedAt.isAfter(threads.last.updatedAt) ||
        threads.first.updatedAt == threads.last.updatedAt, isTrue);
    expect(threads.map((t) => t.title), containsAll(['Schlaf', 'Streit']));
  });

  test('updating an existing thread does not create a duplicate', () async {
    await store.upsertThread(account.ticket, thread('t1', 'Schlaf'));
    final updated = thread('t1', 'Schlaf').copyWith(
      title: 'Einschlafen',
      updatedAt: DateTime(2026, 11, 5, 12),
    );
    await store.upsertThread(account.ticket, updated);
    final threads = await store.loadThreads(account.ticket);
    expect(threads.length, 1);
    expect(threads.single.title, 'Einschlafen');
  });

  test('deletes a thread by id', () async {
    await store.upsertThread(account.ticket, thread('t1', 'A'));
    await store.upsertThread(account.ticket, thread('t2', 'B'));
    await store.deleteThread(account.ticket, 't1');
    final threads = await store.loadThreads(account.ticket);
    expect(threads.map((t) => t.id), ['t2']);
  });

  test('threads are isolated per account', () async {
    await store.upsertThread(account.ticket, thread('t1', 'A von a'));
    change('b');
    expect(await store.loadThreads(account.ticket), isEmpty);
    await store.upsertThread(account.ticket, thread('tb', 'B von b'));
    expect((await store.loadThreads(account.ticket)).single.title, 'B von b');
    change('a');
    expect((await store.loadThreads(account.ticket)).single.title, 'A von a');
  });

  test('guest accounts persist nothing', () async {
    change(null);
    await store.upsertThread(account.ticket, thread('t1', 'A'));
    expect(await store.loadThreads(account.ticket), isEmpty);
  });

  test('migrates a legacy single history into one thread', () async {
    // Alten Phase-2a-Verlauf direkt in SharedPreferences legen.
    final legacy = jsonEncode([
      {'role': 'user', 'content': 'Mein Kind schläft nicht'},
      {'role': 'assistant', 'content': 'Das ist anstrengend.'},
    ]);
    SharedPreferences.setMockInitialValues({
      'chat.history.v1.account.a': legacy,
    });
    final threads = await store.loadThreads(account.ticket);
    expect(threads.length, 1);
    expect(threads.single.messages.length, 2);
    expect(threads.single.title, contains('Mein Kind schläft'));
    // Legacy-Key wurde entfernt → zweiter Load erzeugt keinen zweiten Thread.
    final again = await store.loadThreads(account.ticket);
    expect(again.length, 1);
  });

  test('deriveTitle uses first user message and skips internal markers', () {
    final title = ChatThreadStore.deriveTitle([
      {'role': 'user', 'content': '___TIP_EXPAND___xyz'},
      {'role': 'user', 'content': 'Wie gehe ich mit Wutanfällen um?'},
    ]);
    expect(title, 'Wie gehe ich mit Wutanfällen um?');
  });

  test('caps stored threads to the maximum', () async {
    for (var i = 0; i < ChatThreadStore.maxThreads + 10; i++) {
      await store.upsertThread(
        account.ticket,
        ChatThread(
          id: 't$i',
          title: 'T$i',
          createdAt: DateTime(2026, 11, 5, 0, i),
          updatedAt: DateTime(2026, 11, 5, 0, i),
          messages: [
            {'role': 'user', 'content': 'x$i'}
          ],
        ),
      );
    }
    final threads = await store.loadThreads(account.ticket);
    expect(threads.length, ChatThreadStore.maxThreads);
  });
}
