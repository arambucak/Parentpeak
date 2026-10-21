import 'package:parentpeak/logic/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountAiConsentRequiredException implements Exception {
  const AccountAiConsentRequiredException();

  @override
  String toString() => 'AI consent is required for the originating account.';
}

class AccountAiConsent {
  AccountAiConsent({
    required this.storagePrefix,
    String Function()? scopeProvider,
    Exception Function()? requiredException,
    Future<bool> Function(String key, bool value)? persist,
  })  : _scopeProvider = scopeProvider ?? _currentScope,
        _requiredException = requiredException ??
            (() => const AccountAiConsentRequiredException()),
        _persist = persist;

  final String storagePrefix;
  final String Function() _scopeProvider;
  final Exception Function() _requiredException;
  final Future<bool> Function(String key, bool value)? _persist;
  final Map<String, int> _revisions = {};
  final Set<String> _blocked = {};
  Future<void>? _writes;

  Future<void> _serialize(Future<void> Function() operation) {
    final result = (_writes ?? Future<void>.value()).then((_) => operation());
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }

    tail = result.then<void>((_) => release(),
        onError: (Object error, StackTrace stack) => release());
    _writes = tail;
    return result;
  }

  int revision(String owner) => _revisions[owner] ?? 0;

  void requireRevision(String owner, int expected) {
    requireScope(owner);
    if (_blocked.contains(owner) || revision(owner) != expected) {
      throw _requiredException();
    }
  }

  static String _currentScope() {
    final uid = AuthService.instance.currentUser?.uid;
    return uid == null ? 'guest' : 'account.${Uri.encodeComponent(uid)}';
  }

  String get scope => _scopeProvider();
  String _key(String owner) => '$storagePrefix.$owner';

  void requireScope(String expected) {
    if (scope != expected) throw _requiredException();
  }

  Future<bool> hasConsent() async {
    final owner = scope;
    final prefs = await SharedPreferences.getInstance();
    return scope == owner &&
        !_blocked.contains(owner) &&
        prefs.getBool(_key(owner)) == true;
  }

  Future<void> grant(String expected) {
    final requestRevision = revision(expected);
    return _serialize(() async {
      void guard() {
        requireScope(expected);
        if (revision(expected) != requestRevision) throw _requiredException();
      }

      guard();
      final prefs = await SharedPreferences.getInstance();
      guard();
      final persist = _persist;
      bool written;
      try {
        written = persist == null
            ? await prefs.setBool(_key(expected), true)
            : await persist(_key(expected), true);
      } catch (error) {
        await prefs.reload();
        rethrow;
      }
      if (!written) {
        await prefs.reload();
        throw StateError('Could not persist AI consent.');
      }
      guard();
      _blocked.remove(expected);
      _revisions[expected] = revision(expected) + 1;
    });
  }

  void block(String owner) {
    requireScope(owner);
    _blocked.add(owner);
    _revisions[owner] = revision(owner) + 1;
  }

  Future<void> revoke(String expected) {
    block(expected);
    return _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      requireScope(expected);
      final persist = _persist;
      bool written;
      try {
        written = persist == null
            ? await prefs.setBool(_key(expected), false)
            : await persist(_key(expected), false);
      } catch (_) {
        await prefs.reload();
        rethrow;
      }
      if (!written) {
        await prefs.reload();
        throw StateError('Could not revoke AI consent.');
      }
      requireScope(expected);
    });
  }

  Future<void> require(String expected) async {
    requireScope(expected);
    if (!await hasConsent()) throw _requiredException();
    requireScope(expected);
  }
}
