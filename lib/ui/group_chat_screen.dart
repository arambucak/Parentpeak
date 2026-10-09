import 'dart:async';

import 'package:flutter/material.dart';

import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/friend_chat_service.dart';
import 'package:parentpeak/logic/friendship_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
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
    this.chatService,
    this.accountStore,
  });

  /// Format: 'group_<id>'.
  final String roomId;
  final String groupName;

  /// Optionales Gruppen-Foto. Fallback: Gruppen-Icon.
  final String? photoUrl;
  final FriendChatService? chatService;
  final ProfileAccountStore? accountStore;

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
  late final ProfileAccountTicket _chatTicket;
  bool _chatAccountChanged = false;
  bool _chatUnavailable = false;
  bool _chatLoadFailed = false;
  ProfileAccountStore get _accountStore =>
      widget.accountStore ?? ProfileAccountStore.instance;
  FriendChatService get _chatService =>
      widget.chatService ?? FriendChatService.instance;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  String get _groupId => widget.roomId.startsWith('group_')
      ? widget.roomId.substring('group_'.length)
      : widget.roomId;

  String get _currentUserId {
    return _accountStore.userId ?? '';
  }

  String get _currentUserName {
    final value = AuthService.instance.currentUser?.displayName.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Ich';
  }

  @override
  void initState() {
    super.initState();
    _chatTicket = _accountStore.ticket;
    _accountStore.addListener(_checkChatAccount);
    _loadMembers();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) _loadMessages();
    });
  }

  void _checkChatAccount() {
    if (!mounted || _accountStore.isCurrent(_chatTicket)) return;
    _pollTimer?.cancel();
    setState(() {
      _chatAccountChanged = true;
      _messages.clear();
      _members = [];
      _isLoading = false;
    });
    _showError(_t('chat_access_unavailable'));
  }

  @override
  void dispose() {
    _accountStore.removeListener(_checkChatAccount);
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _chatService.fetchMembers(
        _groupId,
        ticket: _chatTicket,
      );
      if (!mounted || _chatAccountChanged || _chatUnavailable) return;
      setState(() => _members = members);
    } on ProfileAccountChanged {
      _checkChatAccount();
    } on BackendApiException catch (error) {
      if (!mounted || _chatAccountChanged) return;
      if (error.isForbidden) {
        _pollTimer?.cancel();
        setState(() {
          _chatUnavailable = true;
          _isLoading = false;
          _messages.clear();
          _members = [];
        });
      }
      _showError(
        _t(
          error.isForbidden
              ? 'chat_access_unavailable'
              : 'friend_chat_request_failed',
        ),
      );
    } catch (error) {
      debugPrint('Group members load failed: $error');
      if (mounted && !_chatAccountChanged) {
        _showError(_t('friend_chat_request_failed'));
      }
    }
  }

  static DateTime? _parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<void> _loadMessages() async {
    if (_chatAccountChanged || _chatUnavailable) return;
    try {
      final msgs = await _chatService.fetchMessages(widget.roomId, _chatTicket);
      if (!mounted || _chatAccountChanged || _chatUnavailable) return;
      setState(() {
        _chatLoadFailed = false;
        _messages
          ..clear()
          ..addAll(
            msgs.map(
              (m) => _GroupMsg(
                id: (m['id'] ?? '').toString(),
                text: (m['content'] ?? '').toString(),
                authorUserId: (m['authorUserId'] ?? '').toString(),
                authorName: (m['authorName'] ?? 'Elternteil').toString(),
                isMe: m['authorUserId'] == _currentUserId,
                createdAt: _parseCreatedAt(m['createdAt']),
              ),
            ),
          );
        _isLoading = false;
      });
      _scrollToBottom(animate: false);
    } on ProfileAccountChanged {
      _checkChatAccount();
    } on BackendApiException catch (error) {
      if (!mounted || _chatAccountChanged) return;
      if (error.isForbidden) {
        _pollTimer?.cancel();
        _messages.clear();
        _members = [];
        _chatUnavailable = true;
      }
      _showError(
        _t(
          error.isForbidden
              ? 'chat_access_unavailable'
              : 'friend_chat_request_failed',
        ),
      );
      setState(() {
        _chatLoadFailed = true;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Group chat load failed: $error');
      if (mounted && !_chatAccountChanged) {
        _showError(_t('friend_chat_request_failed'));
        setState(() {
          _chatLoadFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_chatAccountChanged || _chatUnavailable) return;
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
    try {
      await _chatService.sendMessage(
        widget.roomId,
        text,
        _currentUserName,
        _chatTicket,
      );
      return true;
    } on ProfileAccountChanged {
      _checkChatAccount();
    } on BackendApiException catch (error) {
      if (mounted && !_chatAccountChanged) {
        if (error.isForbidden) {
          _pollTimer?.cancel();
          setState(() {
            _chatUnavailable = true;
            _isLoading = false;
            _messages.clear();
            _members = [];
          });
        }
        _showError(
          _t(
            error.isForbidden
                ? 'chat_access_unavailable'
                : 'friend_chat_request_failed',
          ),
        );
      }
    } catch (e) {
      debugPrint('Group send failed: $e');
      if (mounted && !_chatAccountChanged) {
        _showError(_t('friend_chat_request_failed'));
      }
    }
    return false;
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ..._members.map(
                (m) => ListTile(
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
                          backgroundColor: const Color(
                            0xFF7C3AED,
                          ).withValues(alpha: 0.1),
                          labelStyle: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
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
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final theme = Theme.of(sheetCtx);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 4,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('network_add_members'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_t('network_add_members')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (added == true && selected.isNotEmpty) {
      if (!_accountStore.isCurrent(_chatTicket)) return;
      final names = <String, String>{
        for (final f in FriendshipService.instance.friends)
          if (selected.contains(f.uid)) f.uid: f.name,
      };
      final ok = await _chatService.addMembers(
        groupId: _groupId,
        actingUserId: _currentUserId,
        memberUids: selected.toList(),
        memberNames: names,
      );
      if (!_accountStore.isCurrent(_chatTicket)) return;
      if (ok) await _loadMembers();
      if (mounted) {
        _showError(
          ok ? _t('network_members_added') : _t('network_members_add_failed'),
        );
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
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(_t('network_leave_group')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!_accountStore.isCurrent(_chatTicket)) return;
      final ok = await _chatService.leaveGroup(_groupId, _currentUserId);
      if (!mounted || !_accountStore.isCurrent(_chatTicket)) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        _showError(_t('friend_chat_request_failed'));
      }
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
          child: Row(
            children: [
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
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_members.isNotEmpty)
                      Text(
                        '${_members.length} ${_t('network_members')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
                value: 'members',
                child: Text(_t('network_members')),
              ),
              PopupMenuItem(
                value: 'add',
                child: Text(_t('network_add_members')),
              ),
              PopupMenuItem(
                value: 'leave',
                child: Text(_t('network_leave_group')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chatUnavailable || _chatLoadFailed
                ? Center(
                    child: Text(
                      _t(
                        _chatUnavailable
                            ? 'chat_access_unavailable'
                            : 'friend_chat_request_failed',
                      ),
                    ),
                  )
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
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_rounded,
              size: 48,
              color: Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 12),
            Text(
              _t('network_group_chat_empty'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
        mainAxisAlignment: m.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: align,
              children: [
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
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(ThemeData theme) {
    if (_chatAccountChanged || _chatUnavailable) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_t('chat_access_unavailable')),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
          ],
        ),
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
