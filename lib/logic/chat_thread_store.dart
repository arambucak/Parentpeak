import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein einzelnes Gespräch der KI-Elternberatung: eigener Verlauf, eigener
/// Titel, eigener Zeitstempel. Mehrere Threads pro Konto erlauben saubere
/// Themen-Trennung ("Einschlafen" getrennt von "Geschwisterstreit").
@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  /// Erster Nachrichtentext als Vorschau für die Übersichtsliste.
  String get preview {
    for (final m in messages) {
      final c = m['content'];
      if (c is String && c.trim().isNotEmpty) {
        final t = c.trim().replaceAll(RegExp(r'\s+'), ' ');
        return t.length > 80 ? '${t.substring(0, 80)}…' : t;
      }
    }
    return '';
  }

  ChatThread copyWith({
    String? title,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? messages,
  }) =>
      ChatThread(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages,
      };
}

/// Verwaltet mehrere Chat-Threads pro Konto, lokal und kontogetrennt.
///
/// Designprinzipien (wie [ChatHistoryStore], das er ablöst):
///   • Kontobezogen: Speicher-Key enthält den Account-Scope.
///   • Ticket-geprüft vor und nach jedem await (keine Lecks zwischen Konten).
///   • Datensparsam: Gäste werden nicht persistiert.
///   • Begrenzt: max. [maxThreads] Threads, je max. [maxMessagesPerThread]
///     Nachrichten.
///
/// Migration: Ein evtl. vorhandener Einzel-Verlauf aus `chat.history.v1`
/// (Phase 2a) wird beim ersten Laden automatisch in einen ersten Thread
/// überführt, damit kein Gespräch verloren geht.
class ChatThreadStore {
  ChatThreadStore({ChatAccountStore? accountStore})
      : _store = accountStore ?? ChatAccountStore.instance;

  static final ChatThreadStore instance = ChatThreadStore();

  final ChatAccountStore _store;

  static const String storagePrefix = 'chat.threads.v1';
  static const String legacyHistoryPrefix = 'chat.history.v1';
  static const int maxThreads = 50;
  static const int maxMessagesPerThread = 60;

  String _key(String scope) => '$storagePrefix.$scope';
  String _legacyKey(String scope) => '$legacyHistoryPrefix.$scope';

  /// Lädt alle Threads des Kontos, nach letzter Aktivität absteigend sortiert.
  Future<List<ChatThread>> loadThreads(ChatAccountTicket ticket) async {
    _store.require(ticket);
    if (ticket.scope == 'guest') return <ChatThread>[];
    final prefs = await SharedPreferences.getInstance();
    _store.require(ticket);

    final raw = prefs.getString(_key(ticket.scope));
    if (raw == null || raw.isEmpty) {
      // Migration aus dem Einzel-Verlauf (Phase 2a), falls vorhanden.
      final migrated = await _migrateLegacy(ticket, prefs);
      return migrated;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ChatThread>[];
      final threads = <ChatThread>[];
      for (final entry in decoded) {
        final thread = _threadFromJson(entry);
        if (thread != null) threads.add(thread);
      }
      threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return threads;
    } catch (error) {
      debugPrint('ChatThreadStore.loadThreads: $error');
      return <ChatThread>[];
    }
  }

  /// Speichert die vollständige Thread-Liste des Kontos (jüngste zuerst,
  /// begrenzt auf [maxThreads]).
  Future<void> saveThreads(
    ChatAccountTicket ticket,
    List<ChatThread> threads,
  ) async {
    _store.require(ticket);
    if (ticket.scope == 'guest') return;
    final sorted = [...threads]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final capped = sorted.length > maxThreads
        ? sorted.sublist(0, maxThreads)
        : sorted;
    final serializable = [
      for (final t in capped)
        {
          'id': t.id,
          'title': t.title,
          'createdAt': t.createdAt.toIso8601String(),
          'updatedAt': t.updatedAt.toIso8601String(),
          'messages': _serializeMessages(t.messages),
        }
    ];
    final prefs = await SharedPreferences.getInstance();
    _store.require(ticket);
    if (serializable.isEmpty) {
      await prefs.remove(_key(ticket.scope));
      return;
    }
    await prefs.setString(_key(ticket.scope), jsonEncode(serializable));
  }

  /// Fügt einen Thread hinzu oder aktualisiert ihn (per id) und speichert.
  Future<void> upsertThread(
    ChatAccountTicket ticket,
    ChatThread thread,
  ) async {
    final threads = await loadThreads(ticket);
    final idx = threads.indexWhere((t) => t.id == thread.id);
    if (idx >= 0) {
      threads[idx] = thread;
    } else {
      threads.add(thread);
    }
    await saveThreads(ticket, threads);
  }

  /// Löscht einen Thread per id.
  Future<void> deleteThread(ChatAccountTicket ticket, String id) async {
    final threads = await loadThreads(ticket);
    threads.removeWhere((t) => t.id == id);
    await saveThreads(ticket, threads);
  }

  /// Löscht alle Threads des Kontos.
  Future<void> clearAll(ChatAccountTicket ticket) async {
    _store.require(ticket);
    final prefs = await SharedPreferences.getInstance();
    _store.require(ticket);
    await prefs.remove(_key(ticket.scope));
  }

  /// Erzeugt eine neue, eindeutige Thread-ID.
  String newThreadId() =>
      'thread_${DateTime.now().microsecondsSinceEpoch}_${_store.ticket.generation}';

  // ─── intern ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _serializeMessages(
      List<Map<String, dynamic>> messages) {
    final trimmed = messages.length > maxMessagesPerThread
        ? messages.sublist(messages.length - maxMessagesPerThread)
        : messages;
    final out = <Map<String, dynamic>>[];
    for (final message in trimmed) {
      final role = message['role'];
      final content = message['content'];
      if (role is! String || content is! String || content.isEmpty) continue;
      final entry = <String, dynamic>{'role': role, 'content': content};
      final childName = message['displayChildName'];
      if (childName is String && childName.isNotEmpty) {
        entry['displayChildName'] = childName;
      }
      final ts = message['timestamp'];
      if (ts is DateTime) {
        entry['timestamp'] = ts.toIso8601String();
      } else if (ts is String) {
        entry['timestamp'] = ts;
      }
      out.add(entry);
    }
    return out;
  }

  List<Map<String, dynamic>> _messagesFromJson(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    final result = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final role = entry['role'];
      final content = entry['content'];
      if (role is! String || content is! String || content.isEmpty) continue;
      final message = <String, dynamic>{'role': role, 'content': content};
      final childName = entry['displayChildName'];
      if (childName is String && childName.isNotEmpty) {
        message['displayChildName'] = childName;
      }
      final ts = entry['timestamp'];
      if (ts is String) {
        final parsed = DateTime.tryParse(ts);
        if (parsed != null) message['timestamp'] = parsed;
      }
      result.add(message);
    }
    return result;
  }

  ChatThread? _threadFromJson(dynamic entry) {
    if (entry is! Map) return null;
    final id = entry['id'];
    final title = entry['title'];
    if (id is! String || id.isEmpty) return null;
    final created = DateTime.tryParse(entry['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final updated =
        DateTime.tryParse(entry['updatedAt']?.toString() ?? '') ?? created;
    final messages = _messagesFromJson(entry['messages']);
    return ChatThread(
      id: id,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'Gespräch',
      createdAt: created,
      updatedAt: updated,
      messages: messages,
    );
  }

  /// Überführt einen alten Einzel-Verlauf (Phase 2a) in einen ersten Thread
  /// und entfernt den Altschlüssel. Still bei Fehlern.
  Future<List<ChatThread>> _migrateLegacy(
    ChatAccountTicket ticket,
    SharedPreferences prefs,
  ) async {
    final legacyRaw = prefs.getString(_legacyKey(ticket.scope));
    if (legacyRaw == null || legacyRaw.isEmpty) return <ChatThread>[];
    try {
      final messages = _messagesFromJson(jsonDecode(legacyRaw));
      if (messages.isEmpty) {
        await prefs.remove(_legacyKey(ticket.scope));
        return <ChatThread>[];
      }
      final now = DateTime.now();
      final thread = ChatThread(
        id: 'thread_legacy_${now.microsecondsSinceEpoch}',
        title: deriveTitle(messages),
        createdAt: now,
        updatedAt: now,
        messages: messages,
      );
      await saveThreads(ticket, [thread]);
      await prefs.remove(_legacyKey(ticket.scope));
      return [thread];
    } catch (error) {
      debugPrint('ChatThreadStore._migrateLegacy: $error');
      return <ChatThread>[];
    }
  }

  /// Leitet einen kurzen, lesbaren Titel aus der ersten Nutzernachricht ab.
  static String deriveTitle(List<Map<String, dynamic>> messages) {
    for (final m in messages) {
      if (m['role'] != 'user') continue;
      final c = m['content'];
      if (c is String && c.trim().isNotEmpty) {
        var t = c.trim().replaceAll(RegExp(r'\s+'), ' ');
        // Interne Tipp-Marker nicht als Titel verwenden.
        if (t.startsWith('___')) continue;
        if (t.length > 42) t = '${t.substring(0, 42)}…';
        return t;
      }
    }
    return 'Neues Gespräch';
  }
}
