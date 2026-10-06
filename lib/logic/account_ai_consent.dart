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
  }) : _scopeProvider = scopeProvider ?? _currentScope,
       _requiredException = requiredException ??
           (() => const AccountAiConsentRequiredException()),
       _persist = persist;

  final String storagePrefix;
  final String Function() _scopeProvider;
  final Exception Function() _requiredException;
  final Future<bool> Function(String key, bool value)? _persist;

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
    return scope == owner && prefs.getBool(_key(owner)) == true;
  }

  Future<void> grant(String expected) async {
    requireScope(expected);
    final prefs = await SharedPreferences.getInstance();
    requireScope(expected);
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
    requireScope(expected);
  }

  Future<void> require(String expected) async {
    requireScope(expected);
    if (!await hasConsent()) throw _requiredException();
    requireScope(expected);
  }
}
