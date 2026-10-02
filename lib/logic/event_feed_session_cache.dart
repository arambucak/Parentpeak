class EventFeedValue<T> {
  const EventFeedValue(this.data, this.loadedAt);

  final T data;
  final DateTime loadedAt;
}

class _Entry<T> {
  EventFeedValue<T>? value;
  Future<EventFeedValue<T>>? pending;
}

class EventFeedSessionCache<T> {
  EventFeedSessionCache({required this.ttl, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _now;
  final Map<String, _Entry<T>> _entries = {};

  EventFeedValue<T>? peek(String key) => _entries[key]?.value;
  Future<EventFeedValue<T>>? pending(String key) => _entries[key]?.pending;

  void clear() => _entries.clear();

  Future<EventFeedValue<T>> load(
    String key,
    Future<T> Function() loader, {
    bool force = false,
  }) {
    final previous = _entries[key];
    if (!force && previous != null) {
      if (previous.pending != null) return previous.pending!;
      final value = previous.value;
      if (value != null && _now().difference(value.loadedAt) < ttl) {
        return Future.value(value);
      }
    }
    final entry = force || previous == null ? _Entry<T>() : previous;
    entry.value ??= previous?.value;
    _entries[key] = entry;
    if (_entries.length > 32) {
      _entries.remove(_entries.keys.first);
    }
    final pending = Future<T>.sync(loader).then((data) {
      final value = EventFeedValue(data, _now());
      if (identical(_entries[key], entry)) entry.value = value;
      return value;
    }).whenComplete(() {
      entry.pending = null;
    });
    entry.pending = pending;
    return pending;
  }
}
