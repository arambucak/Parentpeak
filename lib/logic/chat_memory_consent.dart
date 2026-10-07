import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMemoryConsentRequiredException implements Exception {
  const ChatMemoryConsentRequiredException();
}

class ChatMemoryConsent extends AccountAiConsent {
  ChatMemoryConsent({
    super.scopeProvider,
    Future<bool> Function(String key, bool value)? persist,
  }) : _persist = persist,
       super(
         storagePrefix: 'chat.memory_consent.v1',
         persist: persist,
         requiredException: () => const ChatMemoryConsentRequiredException(),
       );

  static const version = 'chat-memory-v1';
  static final instance = ChatMemoryConsent();
  final Map<String, int> _revisions = {};
  final Set<String> _blocked = {};
  final Future<bool> Function(String key, bool value)? _persist;

  int revision(String owner) => _revisions[owner] ?? 0;

  void requireRevision(String owner, int expected) {
    requireScope(owner);
    if (revision(owner) != expected) {
      throw const ChatMemoryConsentRequiredException();
    }
  }

  @override
  Future<void> grant(String expected) async {
    await super.grant(expected);
    _blocked.remove(expected);
    _revisions[expected] = revision(expected) + 1;
  }

  @override
  Future<bool> hasConsent() async {
    final owner = scope;
    if (_blocked.contains(owner)) return false;
    final granted = await super.hasConsent();
    return scope == owner && !_blocked.contains(owner) && granted;
  }

  void block(String owner) {
    requireScope(owner);
    _blocked.add(owner);
    _revisions[owner] = revision(owner) + 1;
  }

  Future<void> revoke(String owner) async {
    block(owner);
    final prefs = await SharedPreferences.getInstance();
    requireScope(owner);
    final key = '$storagePrefix.$owner';
    final persist = _persist;
    bool written;
    try {
      written = persist == null
          ? await prefs.setBool(key, false)
          : await persist(key, false);
    } catch (error) {
      await prefs.reload();
      rethrow;
    }
    if (!written) {
      await prefs.reload();
      throw StateError('Could not revoke Memory consent.');
    }
    requireScope(owner);
  }
}
