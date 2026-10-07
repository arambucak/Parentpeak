import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatAccountChanged implements Exception {
  const ChatAccountChanged();
  @override
  String toString() => 'The originating chat session is no longer active.';
}

class ChatAccountTicket {
  const ChatAccountTicket(this.scope, this.generation);
  final String scope;
  final int generation;
}

class ChatAccountStore extends ChangeNotifier {
  ChatAccountStore({
    String? Function()? userIdProvider,
    Future<bool> Function(String key, String value)? persist,
  }) : _userIdProvider =
           userIdProvider ?? (() => AuthService.instance.currentUser?.uid),
       _persist = persist {
    _checkFirebaseIdentity = userIdProvider == null;
    _lastScope = scope;
    AuthService.instance.addListener(synchronize);
  }

  static final instance = ChatAccountStore();
  static const storageKey = 'chat.accounts.v1';
  static const legacyKey = 'ki_chat.topic_counts.v1';
  static Future<void>? _writes;
  final String? Function() _userIdProvider;
  final Future<bool> Function(String key, String value)? _persist;
  late String _lastScope;
  int _generation = 0;
  late final bool _checkFirebaseIdentity;

  String get scope {
    final uid = _userIdProvider();
    return uid == null ? 'guest' : 'account.${Uri.encodeComponent(uid)}';
  }

  void synchronize() {
    if (_lastScope == scope) return;
    _lastScope = scope;
    _generation++;
    notifyListeners();
  }

  ChatAccountTicket get ticket {
    synchronize();
    return ChatAccountTicket(scope, _generation);
  }

  void require(ChatAccountTicket ticket) {
    synchronize();
    if (ticket.scope != scope || ticket.generation != _generation ||
        (_checkFirebaseIdentity && Firebase.apps.isNotEmpty &&
         FirebaseAuth.instance.currentUser?.uid != _userIdProvider())) {
      throw const ChatAccountChanged();
    }
  }

  Map<String, int> _counts(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid chat topic counts');
    }
    final result = <String, int>{};
    for (final entry in value.entries) {
      final count = entry.value;
      if (entry.key.isEmpty || count is! int || count < 0 ||
          count > 9007199254740991) {
        throw const FormatException('Invalid chat topic count');
      }
      result[entry.key] = count;
    }
    return result;
  }

  Map<String, dynamic> _root(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    if (raw == null) return {'accounts': <String, dynamic>{}};
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> ||
        root['accounts'] is! Map<String, dynamic> ||
        (root['legacyOwner'] != null && root['legacyOwner'] is! String)) {
      throw const FormatException('Invalid chat owner envelope');
    }
    return root;
  }

  Map<String, int> _account(Map<String, dynamic> root, String scope) {
    final account = (root['accounts'] as Map<String, dynamic>)[scope];
    if (account == null) return {};
    if (account is! Map<String, dynamic> || account['owner'] != scope) {
      throw const FormatException('Invalid chat account owner');
    }
    return _counts(account['topics']);
  }

  Future<Map<String, int>> read(ChatAccountTicket ticket) async {
    require(ticket);
    final prefs = await SharedPreferences.getInstance();
    require(ticket);
    return _account(_root(prefs), ticket.scope);
  }

  Future<bool> hasLegacy(ChatAccountTicket ticket) async {
    require(ticket);
    final prefs = await SharedPreferences.getInstance();
    require(ticket);
    return _root(prefs)['legacyOwner'] == null &&
        prefs.containsKey(legacyKey);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = (_writes ?? Future<void>.value()).then((_) => operation());
    late final Future<void> tail;
    void release() {
      if (identical(_writes, tail)) _writes = null;
    }
    tail = result.then<void>(
      (_) => release(),
      onError: (Object error, StackTrace stack) => release(),
    );
    _writes = tail;
    return result;
  }

  Future<Map<String, int>> _change(
    ChatAccountTicket ticket,
    void Function(Map<String, int>, Map<String, dynamic>, SharedPreferences) change,
  ) => _serialize(() async {
    require(ticket);
    final prefs = await SharedPreferences.getInstance();
    require(ticket);
    final root = _root(prefs);
    final counts = _account(root, ticket.scope);
    change(counts, root, prefs);
    (root['accounts'] as Map<String, dynamic>)[ticket.scope] = {
      'owner': ticket.scope, 'topics': _counts(counts),
    };
    require(ticket);
    bool written;
    try {
      final raw = jsonEncode(root);
      final persist = _persist;
      written = await (persist == null
          ? prefs.setString(storageKey, raw)
          : persist(storageKey, raw));
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    if (!written) {
      await prefs.reload();
      throw StateError('Could not persist chat account data');
    }
    require(ticket);
    return counts;
  });

  Future<Map<String, int>> increment(ChatAccountTicket ticket, String topic) =>
      _change(ticket, (counts, root, prefs) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      });

  Future<Map<String, int>> reset(ChatAccountTicket ticket) =>
      _change(ticket, (counts, root, prefs) => counts.clear());

  Future<Map<String, int>> claim(ChatAccountTicket ticket) =>
      _change(ticket, (counts, root, prefs) {
        if (ticket.scope == 'guest') throw StateError('Sign in to claim chat data');
        final owner = root['legacyOwner'];
        if (owner == ticket.scope) return;
        if (owner != null) throw StateError('Legacy chat data already assigned');
        final raw = prefs.getString(legacyKey);
        if (raw == null) throw StateError('No legacy chat data');
        for (final entry in _counts(jsonDecode(raw)).entries) {
          counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
        }
        root['legacyOwner'] = ticket.scope;
      });

  @override
  void dispose() {
    AuthService.instance.removeListener(synchronize);
    super.dispose();
  }
}
