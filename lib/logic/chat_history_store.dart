import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert den Verlauf der KI-Elternberatung lokal pro Konto, damit eine
/// Unterhaltung erhalten bleibt, wenn der Chat verlassen und wieder geöffnet
/// wird.
///
/// Designprinzipien:
///   • Kontobezogen: Der Speicher-Key enthält den Account-Scope
///     (`account.<uid>` bzw. `guest`). Beim Kontowechsel sieht ein Konto NIE
///     den Verlauf eines anderen.
///   • Ticket-geprüft: Jeder Lese-/Schreibvorgang verlangt das aktuelle
///     [ChatAccountTicket]; bei einem Wechsel mitten im Vorgang wird nichts
///     geschrieben (verhindert Datenlecks zwischen Konten).
///   • Datensparsam: Für nicht angemeldete Gäste wird NICHTS persistiert.
///   • Begrenzt: Nur die letzten [maxStoredMessages] Nachrichten werden
///     gespeichert, damit SharedPreferences schlank bleibt.
///
/// Es werden nur Rolle, Textinhalt, optionaler Kindname und Zeitstempel
/// gespeichert — keine flüchtigen UI-Felder.
class ChatHistoryStore {
  ChatHistoryStore({ChatAccountStore? accountStore})
      : _store = accountStore ?? ChatAccountStore.instance;

  static final ChatHistoryStore instance = ChatHistoryStore();

  final ChatAccountStore _store;

  static const String storagePrefix = 'chat.history.v1';

  /// Obergrenze gespeicherter Nachrichten (jüngste zuerst beibehalten).
  static const int maxStoredMessages = 60;

  String _key(String scope) => '$storagePrefix.$scope';

  /// Lädt den gespeicherten Verlauf für das Konto des [ticket].
  /// Gibt eine leere Liste zurück, wenn nichts gespeichert ist, der Scope ein
  /// Gast ist, oder der Inhalt nicht lesbar ist.
  Future<List<Map<String, dynamic>>> load(ChatAccountTicket ticket) async {
    _store.require(ticket);
    if (ticket.scope == 'guest') return <Map<String, dynamic>>[];
    final prefs = await SharedPreferences.getInstance();
    _store.require(ticket);
    final raw = prefs.getString(_key(ticket.scope));
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      final result = <Map<String, dynamic>>[];
      for (final entry in decoded) {
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
    } catch (error) {
      debugPrint('ChatHistoryStore.load: $error');
      return <Map<String, dynamic>>[];
    }
  }

  /// Speichert den Verlauf für das Konto des [ticket]. Für Gäste passiert
  /// nichts. Nur die letzten [maxStoredMessages] Einträge werden behalten.
  Future<void> save(
    ChatAccountTicket ticket,
    List<Map<String, dynamic>> messages,
  ) async {
    _store.require(ticket);
    if (ticket.scope == 'guest') return;
    final trimmed = messages.length > maxStoredMessages
        ? messages.sublist(messages.length - maxStoredMessages)
        : messages;
    final serializable = <Map<String, dynamic>>[];
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
      if (ts is DateTime) entry['timestamp'] = ts.toIso8601String();
      serializable.add(entry);
    }
    final prefs = await SharedPreferences.getInstance();
    // Nach dem await erneut prüfen: Konto darf sich nicht gewechselt haben.
    _store.require(ticket);
    if (serializable.isEmpty) {
      await prefs.remove(_key(ticket.scope));
      return;
    }
    await prefs.setString(_key(ticket.scope), jsonEncode(serializable));
  }

  /// Löscht den gespeicherten Verlauf für das Konto des [ticket].
  Future<void> clear(ChatAccountTicket ticket) async {
    _store.require(ticket);
    final prefs = await SharedPreferences.getInstance();
    _store.require(ticket);
    await prefs.remove(_key(ticket.scope));
  }
}
