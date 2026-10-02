import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/event_feed_session_cache.dart';

void main() {
  test('AI and community obey independent TTLs and cache verified data',
      () async {
    var now = DateTime(2026);
    final ai = EventFeedSessionCache<List<String>>(
      ttl: const Duration(minutes: 10),
      now: () => now,
    );
    final community = EventFeedSessionCache<List<String>>(
      ttl: const Duration(minutes: 1),
      now: () => now,
    );
    var aiCalls = 0;
    var communityCalls = 0;
    Future<List<String>> loadAi() async => ['ai-${++aiCalls}'];
    Future<List<String>> loadCommunity() async =>
        ['community-${++communityCalls}'];
    await ai.load('query', loadAi);
    await community.load('query', loadCommunity);
    now = now.add(const Duration(minutes: 2));
    expect((await ai.load('query', loadAi)).data, ['ai-1']);
    expect(
        (await community.load('query', loadCommunity)).data, ['community-2']);
    now = now.add(const Duration(minutes: 9));
    expect((await ai.load('query', loadAi)).data, ['ai-2']);
  });

  test('deduplicates pending loads and caches successful empty values',
      () async {
    final cache = EventFeedSessionCache<List<String>>(
      ttl: const Duration(minutes: 10),
    );
    final pending = Completer<List<String>>();
    var calls = 0;
    Future<List<String>> load() {
      calls++;
      return pending.future;
    }

    final first = cache.load('query', load);
    expect(identical(first, cache.load('query', load)), isTrue);
    pending.complete([]);
    await first;
    expect((await cache.load('query', load)).data, isEmpty);
    expect(calls, 1);
  });

  test('expired failure preserves verified data and its timestamp', () async {
    var now = DateTime(2026);
    final cache = EventFeedSessionCache<List<String>>(
      ttl: const Duration(minutes: 1),
      now: () => now,
    );
    final verified = await cache.load('query', () async => ['event']);
    now = now.add(const Duration(minutes: 2));
    await expectLater(
      cache.load('query', () async => throw StateError('offline')),
      throwsStateError,
    );
    expect(cache.peek('query'), same(verified));
    expect(cache.peek('other query'), isNull);
  });

  test('forced refresh and invalidation prevent old loads resurrecting data',
      () async {
    final cache = EventFeedSessionCache<List<String>>(
      ttl: const Duration(minutes: 1),
    );
    final old = Completer<List<String>>();
    final first = cache.load('query', () => old.future);
    await cache.load('query', () async => ['edited'], force: true);
    old.complete(['deleted']);
    await first;
    expect(cache.peek('query')!.data, ['edited']);
    cache.clear();
    expect(cache.peek('query'), isNull);
    expect((await cache.load('query', () async => [])).data, isEmpty);
  });
}
