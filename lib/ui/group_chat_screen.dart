import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/friend_chat_service.dart';
import 'package:parentpeak/logic/friendship_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';
import 'package:parentpeak/ui/widgets/user_avatar.dart';

/// Dedizierter Gruppen-Chat: zeigt Nachrichten mit Absendername + Avatar,
/// Mitgliederliste, Mitglieder einladen und Gruppe verlassen.
///
/// Nutzt dieselben Backend-Endpunkte wie der 1:1-Chat
/// (/friend-chat/messages mit roomId = 'group_<id>') plus /chat-groups/*.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.roomId,
    required this.groupName,
    this.photoUrl,
  });

  /// Format: 'group_<id>'.
  final String roomId;
  final String groupName;

  /// Optionales Gruppen-Foto. Fallback: Gruppen-Icon.
  final String? photoUrl;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_GroupMsg> _messages = [];
  List<GroupMember> _members = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  String get _groupId => widget.roomId.startsWith('group_')
      ? widget.roomId.substring('group_'.length)
      : widget.roomId;

  String get _currentUserId {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (firebaseUid != null && firebaseUid.isNotEmpty) return firebaseUid;
    final value = AuthService.instance.currentUser?.uid.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'local-parent-user';
  }

  String get _currentUserName {
    final value = AuthService.instance.currentUser?.displayName.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Ich';
  }

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) _loadMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final members = await FriendChatService.instance.fetchMembers(_groupId);
    if (!mounted) return;
    setState(() => _members = members);
  }

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
    if (user == null) {
      final apiToken = APIConfig.getBackendApiToken();
      if (apiToken != null && apiToken.isNotEmpty) {
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
        };
      }
      return {'Content-Type': 'application/json'};
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      return {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
    } catch (_) {
      return {'Content-Type': 'application/json'};
    }
  }

  static DateTime? _parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<void> _loadMessages() async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final uri = Uri.parse(
        '$base/friend-chat/messages?roomId=${Uri.encodeComponent(widget.roomId)}'
        '&userId=${Uri.encodeComponent(_currentUserId)}',
      );
      final headers = await _authHeaders();
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final msgs = List<Map<String, dynamic>>.from(body['messages'] ?? []);
        setState(() {
          _messages
            ..clear()
            ..addAll(msgs.map((m) => _GroupMsg(
                  id: (m['id'] ?? '').toString(),
                  text: (m['content'] ?? '').toString(),
                  authorUserId: (m['authorUserId'] ?? '').toString(),
                  authorName: (m['authorName'] ?? 'Elternteil').toString(),
                  isMe: m['authorUserId'] == _currentUserId,
                  createdAt: _parseCreatedAt(m['createdAt']),
                )));
          _isLoading = false;
        });
        _scrollToBottom(animate: false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final moderationResult = ChatModerationService.instance.checkMessage(text);
    if (moderationResult != null) {
      _showError(moderationResult);
      return;
    }

    final optimistic = _GroupMsg(
      id: 'optimistic-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      authorUserId: _currentUserId,
      authorName: _currentUserName,
      isMe: true,
      createdAt: DateTime.now(),
      sending: true,
    );
    setState(() {
      _messages.add(optimistic);
      _controller.clear();
    });
    _scrollToBottom();

    final ok = await _postMessage(text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _messages.remove(optimistic));
      return;
    }
    await _loadMessages();
  }

  Future<bool> _postMessage(String text) async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null) {
      _showError('Backend-URL fehlt');
      return false;
    }
    try {
      final headers = await _authHeaders();
      final resp = await http
          .post(
            Uri.parse('$base/friend-chat/messages'),
            headers: headers,
            body: jsonEncode({
              'roomId': widget.roomId,
              'userId': _currentUserId,
              'userName': _currentUserName,
              'content': text,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 201) return true;
      if (resp.statusCode == 401) {
        final freshHeaders = await _authHeaders(forceRefresh: true);
        final retry = await http
            .post(
              Uri.parse('$base/friend-chat/messages'),
              headers: freshHeaders,
              body: jsonEncode({
                'roomId': widget.roomId,
                'userId': _currentUserId,
                'userName': _currentUserName,
                'content': text,
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (retry.statusCode == 201) return true;
        _showError(
            'Sitzung abgelaufen — bitte Seite neu laden oder erneut einloggen.');
        return false;
      }
      if (resp.statusCode == 403) {
        _showError(_t('network_group_not_member'));
        return false;
      }
      _showError('Fehler ${resp.statusCode}');
      return false;
    } catch (e) {
      _showError('Netzwerkfehler: $e');
      return false;
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(target,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Mitglieder-Verwaltung ─────────────────────────────────────────────────

  void _showMembersSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_t('network_members')} (${_members.length})',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ..._members.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(name: m.memberName, radius: 20),
                    title: Text(
                      m.userId == _currentUserId
                          ? '${m.memberName} (${_t('network_you_label')})'
                          : m.memberName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: m.isOwner
                        ? Chip(
                            label: Text(_t('network_owner_label')),
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                const Color(0xFF7C3AED).withValues(alpha: 0.1),
                            labelStyle: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          )
                        : null,
                  )),
              const Divider(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _showAddMembersSheet();
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(_t('network_add_members')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5A4),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Freunde, die noch nicht in der Gruppe sind, hinzufügen.
  Future<void> _showAddMembersSheet() async {
    final memberIds = _members.map((m) => m.userId).toSet();
    final candidates = FriendshipService.instance.friends
        .where((f) => !memberIds.contains(f.uid))
        .toList();
    if (candidates.isEmpty) {
      _showError(_t('network_all_friends_in_group'));
      return;
    }
    final selected = <String>{};
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        final theme = Theme.of(sheetCtx);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_t('network_add_members'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: candidates.map((f) {
                  return CheckboxListTile(
                    value: selected.contains(f.uid),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: UserAvatar(name: f.name, radius: 20),
                    title: Text(f.name),
                    onChanged: (v) => setSheet(() {
                      if (v == true) {
                        selected.add(f.uid);
                      } else {
                        selected.remove(f.uid);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(sheetCtx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5A4),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_t('network_add_members')),
              ),
            ),
          ]),
        );
      }),
    );
    if (added == true && selected.isNotEmpty) {
      final names = <String, String>{
        for (final f in FriendshipService.instance.friends)
          if (selected.contains(f.uid)) f.uid: f.name,
      };
      final ok = await FriendChatService.instance.addMembers(
        groupId: _groupId,
        actingUserId: _currentUserId,
        memberUids: selected.toList(),
        memberNames: names,
      );
      if (ok) await _loadMembers();
      if (mounted) {
        _showError(ok
            ? _t('network_members_added')
            : _t('network_members_add_failed'));
      }
    }
  }

  Future<void> _confirmLeaveGroup() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_t('network_leave_group')),
        content: Text(_t('network_leave_group_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            child: Text(_t('network_leave_group')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FriendChatService.instance.leaveGroup(_groupId, _currentUserId);
      if (mounted) Navigator.pop(context);
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _showMembersSheet,
          child: Row(children: [
            UserAvatar(
              name: widget.groupName,
              photoUrl: widget.photoUrl,
              isGroup: true,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.groupName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (_members.isNotEmpty)
                    Text(
                      '${_members.length} ${_t('network_members')}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ]),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'members') _showMembersSheet();
              if (v == 'add') _showAddMembersSheet();
              if (v == 'leave') _confirmLeaveGroup();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'members', child: Text(_t('network_members'))),
              PopupMenuItem(
                  value: 'add', child: Text(_t('network_add_members'))),
              PopupMenuItem(
                  value: 'leave', child: Text(_t('network_leave_group'))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? _emptyState(theme)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(theme, _messages[i], i),
                    ),
        ),
        _composer(theme),
      ]),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.groups_rounded, size: 48, color: Color(0xFF8B5CF6)),
          const SizedBox(height: 12),
          Text(
            _t('network_group_chat_empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }

  /// Zeigt den Absendernamen über fremden Nachrichten, wenn sich der Autor
  /// zur vorigen Nachricht ändert (gruppiert aufeinanderfolgende Nachrichten).
  bool _showAuthorFor(int index) {
    final msg = _messages[index];
    if (msg.isMe) return false;
    if (index == 0) return true;
    return _messages[index - 1].authorUserId != msg.authorUserId;
  }

  Widget _bubble(ThemeData theme, _GroupMsg m, int index) {
    final showAuthor = _showAuthorFor(index);
    final align = m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = m.isMe
        ? const Color(0xFF7C3AED)
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = m.isMe ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            m.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.isMe) ...[
            Opacity(
              opacity: showAuthor ? 1 : 0,
              child: UserAvatar(name: m.authorName, radius: 14),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(crossAxisAlignment: align, children: [
              if (showAuthor)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    m.authorName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(m.isMe ? 16 : 4),
                    bottomRight: Radius.circular(m.isMe ? 4 : 16),
                  ),
                ),
                child: Text(m.text, style: TextStyle(color: textColor)),
              ),
              if (m.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    m.sending
                        ? _t('network_sending')
                        : '${m.createdAt!.hour.toString().padLeft(2, '0')}:${m.createdAt!.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _composer(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _t('network_message_hint'),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _send,
            backgroundColor: const Color(0xFF7C3AED),
            elevation: 0,
            child: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}

class _GroupMsg {
  _GroupMsg({
    required this.id,
    required this.text,
    required this.authorUserId,
    required this.authorName,
    required this.isMe,
    this.createdAt,
    this.sending = false,
  });

  final String id;
  final String text;
  final String authorUserId;
  final String authorName;
  final bool isMe;
  final DateTime? createdAt;
  final bool sending;
}
