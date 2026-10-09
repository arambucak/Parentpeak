import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friend_chat_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';
import 'package:parentpeak/services/block_report_service.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class MatchConversationScreen extends StatefulWidget {
  const MatchConversationScreen({
    super.key,
    required this.profileId,
    required this.profileName,
    this.isFriendChat = false,
    this.chatService,
    this.accountStore,
  });

  final String profileId;
  final String profileName;
  final bool isFriendChat;
  final FriendChatService? chatService;
  final ProfileAccountStore? accountStore;

  @override
  State<MatchConversationScreen> createState() =>
      _MatchConversationScreenState();
}

class _MatchConversationScreenState extends State<MatchConversationScreen> {
  final TextEditingController _controller = TextEditingController();

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  final ParentMatchingBackendService _service =
      BackendServiceFactory.createParentMatchingService();
  final List<_Msg> _messages = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _streamSub;
  bool _streamActive = false;
  bool _isLoading = true;
  late final ProfileAccountTicket _chatTicket;
  bool _chatAccountChanged = false;
  bool _chatReadDenied = false;
  bool _chatLoadFailed = false;
  ProfileAccountStore get _accountStore => widget.accountStore ?? ProfileAccountStore.instance;
  FriendChatService get _chatService => widget.chatService ?? FriendChatService.instance;

  /// Wenn gesetzt: Der Chat ist Nur-Lese. Der Text wird als ruhiger Hinweis
  /// statt des Eingabefelds angezeigt (Freundschaft entfernt oder blockiert).
  String? _chatDisabledReason;

  /// Schaltet den Chat auf Nur-Lese und setzt einen ruhigen, wertschaetzenden
  /// Hinweis (GfK-Ton, keine Schuldzuweisung). 'blocked' -> Zugriff endet,
  /// 'not_friends' -> Verlauf bleibt lesbar.
  void _applyChatDisabled(String? code) {
    final reason = code != 'not_friends'
        ? _t('chat_access_unavailable')
        : 'Ihr seid aktuell nicht mehr verbunden. Frühere Nachrichten kannst '
              'du weiter nachlesen.';
    if (!mounted) return;
    setState(() => _chatDisabledReason = reason);
  }

  /// Parst den Zeitstempel einer Nachricht aus der Server-Antwort.
  static DateTime? _parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  /// Uhrzeit im Format HH:mm (lokal).
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Datums-Trenner-Text: Heute / Gestern / TT.MM.JJJJ.
  String _formatDaySeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Heute';
    if (diff == 1) return 'Gestern';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  /// Ob vor der Nachricht an [index] ein Datums-Trenner stehen soll.
  bool _needsDaySeparator(int index) {
    final cur = _messages[index].createdAt;
    if (cur == null) return false;
    if (index == 0) return true;
    final prev = _messages[index - 1].createdAt;
    if (prev == null) return true;
    return cur.year != prev.year ||
        cur.month != prev.month ||
        cur.day != prev.day;
  }

  /// Nach dem Rendern ans Ende der Liste scrollen (neueste Nachricht sichtbar).
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

  String get _currentUserId {
    return _accountStore.userId ?? '';
  }

  String get _currentUserName {
    final value = AuthService.instance.currentUser?.displayName.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return 'Ich';
  }

  /// Stabile Identitaet des Gegenuebers fuer Melden/Blockieren/Sperren.
  /// Im Freund-Chat ist widget.profileId die roomId im Format 'uidA__uidB'
  /// -> die Gegenseite ist die Haelfte, die NICHT meine eigene UID ist. Im
  /// Match-Chat ist profileId bereits die echte Profil-/User-ID.
  String get _otherPartyId {
    if (!widget.isFriendChat) return widget.profileId;
    final roomId = widget.profileId;
    if (roomId.contains('__')) {
      final myUid = _currentUserId;
      final parts = roomId.split('__');
      for (final p in parts) {
        if (p.isNotEmpty && p != myUid) return p;
      }
    }
    return roomId;
  }

  @override
  void initState() {
    super.initState();
    _chatTicket = _accountStore.ticket;
    _accountStore.addListener(_checkChatAccount);
    _loadMessages();
    if (!widget.isFriendChat) _startLiveStream();
    // Auto-poll for new messages every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) _loadMessages();
    });
  }

  void _checkChatAccount() {
    if (!mounted || _accountStore.isCurrent(_chatTicket)) return;
    _pollTimer?.cancel();
    _streamSub?.cancel();
    setState(() {
      _chatAccountChanged = true;
      _messages.clear();
      _isLoading = false;
      _chatDisabledReason = _t('chat_access_unavailable');
    });
  }

  Timer? _pollTimer;

  void _startLiveStream() {
    _streamSub?.cancel();
    _streamSub = _service
        .streamMessages(profileId: widget.profileId, userId: _currentUserId)
        .listen(
          (event) {
            final type = (event['type'] ?? '').toString();
            if (type == 'ready' || type == 'ping') {
              if (mounted && !_streamActive) {
                setState(() => _streamActive = true);
              }
              return;
            }

            final item = event['item'];
            if (item is! Map) return;
            final content = (item['content'] ?? '').toString().trim();
            if (content.isEmpty) return;

            final id = (item['id'] ?? '').toString();
            final authorUserId = (item['authorUserId'] ?? '').toString();
            if (!mounted) return;

            if (_messages.any((msg) => msg.id == id && id.isNotEmpty)) {
              return;
            }

            setState(() {
              _streamActive = true;
              _messages.add(
                _Msg(
                  id: id,
                  text: content,
                  isMe: authorUserId == _currentUserId,
                  createdAt: _parseCreatedAt(item['createdAt']),
                ),
              );
            });
            _scrollToBottom();
          },
          onError: (_) {
            if (mounted) {
              setState(() => _streamActive = false);
            }
          },
          onDone: () {
            if (mounted) {
              setState(() => _streamActive = false);
            }
          },
        );
  }

  Future<void> _loadMessages() async {
    if (_chatAccountChanged || _chatReadDenied) return;
    if (widget.isFriendChat) {
      await _loadFriendMessages();
      return;
    }
    final items = await _service.fetchMessages(
      profileId: widget.profileId,
      userId: _currentUserId,
    );
    if (!mounted) return;
    setState(() {
      _chatLoadFailed = false;
      _messages
        ..clear()
        ..addAll(
          items.map((item) {
            final text = (item['content'] ?? '').toString();
            final id = (item['id'] ?? '').toString();
            final authorUserId = (item['authorUserId'] ?? '').toString();
            return _Msg(
              id: id,
              text: text,
              isMe: authorUserId == _currentUserId,
              createdAt: _parseCreatedAt(item['createdAt']),
            );
          }),
        );
      _isLoading = false;
    });
    _scrollToBottom(animate: false);
  }

  Future<void> _loadFriendMessages() async {
    try {
      final msgs = await _chatService.fetchMessages(
        widget.profileId,
        _chatTicket,
      );
      if (!mounted || _chatAccountChanged || _chatReadDenied) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(
            msgs.map(
              (m) => _Msg(
                id: (m['id'] ?? '').toString(),
                text: (m['content'] ?? '').toString(),
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
        _chatReadDenied = true;
        _messages.clear();
        _applyChatDisabled(error.serverCode);
        _pollTimer?.cancel();
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
      debugPrint('Friend chat load failed: $error');
      if (!mounted || _chatAccountChanged) return;
      _showError(_t('friend_chat_request_failed'));
      setState(() {
        _chatLoadFailed = true;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _accountStore.removeListener(_checkChatAccount);
    _pollTimer?.cancel();
    _streamSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_chatAccountChanged || _chatDisabledReason != null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Moderation check
    final moderationResult = ChatModerationService.instance.checkMessage(text);
    if (moderationResult != null) {
      _showError(moderationResult);
      return;
    }

    final optimistic = _Msg(
      id: 'optimistic-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isMe: true,
      createdAt: DateTime.now(),
      sending: true,
    );

    setState(() {
      _messages.add(optimistic);
      _controller.clear();
    });
    _scrollToBottom();

    final Map<String, dynamic>? sent;
    if (widget.isFriendChat) {
      sent = await _sendFriendMessage(text);
    } else {
      sent = await _service.sendMessage(
        profileId: widget.profileId,
        userId: _currentUserId,
        userName: _currentUserName,
        content: text,
      );
    }
    if (!mounted) return;

    if (sent == null) {
      setState(() => _messages.remove(optimistic));
      return;
    }

    await _loadMessages();
  }

  Future<Map<String, dynamic>?> _sendFriendMessage(String text) async {
    try {
      return await _chatService.sendMessage(
        widget.profileId,
        text,
        _currentUserName,
        _chatTicket,
      );
    } on ProfileAccountChanged {
      _checkChatAccount();
    } on SuspendedAccountException {
      if (mounted && !_chatAccountChanged) {
        await showAccountSuspendedNotice(context);
      }
    } on BackendApiException catch (error) {
      if (!mounted || _chatAccountChanged) return null;
      if (error.isForbidden) {
        _applyChatDisabled(error.serverCode);
        if (error.serverCode != 'not_friends') {
          _chatReadDenied = true;
          setState(() {
            _messages.clear();
            _isLoading = false;
          });
          _pollTimer?.cancel();
        }
      }
      _showError(
        _t(
          error.isForbidden
              ? 'chat_access_unavailable'
              : 'friend_chat_request_failed',
        ),
      );
    } catch (e) {
      debugPrint('Friend chat send failed: $e');
      if (mounted && !_chatAccountChanged) {
        _showError(_t('friend_chat_request_failed'));
      }
    }
    return null;
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${widget.profileName} blockieren?'),
        content: const Text(
          'Blockierte Personen können dir keine Nachrichten mehr senden und sehen dein Profil nicht. Du kannst die Blockierung jederzeit aufheben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await BlockReportService.instance.blockUser(
                _otherPartyId,
                widget.profileName,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                Navigator.pop(context); // Close chat
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.profileName} wurde blockiert.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: Text(_t('convo_block')),
          ),
        ],
      ),
    );
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _t('convo_report_user'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'conversation_report_reason',
                ).replaceAll('{name}', widget.profileName),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              _reportOption(ctx, 'Beleidigung / Hassrede', 'insult'),
              _reportOption(ctx, 'Spam / Werbung', 'spam'),
              _reportOption(ctx, 'Unangemessene Inhalte', 'inappropriate'),
              _reportOption(ctx, 'Betrug / Fake-Profil', 'fraud'),
              _reportOption(ctx, 'Sonstiges', 'other'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportOption(BuildContext ctx, String label, String reason) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      leading: const Icon(Icons.flag_outlined, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () async {
        Navigator.pop(ctx);
        final result = await BlockReportService.instance.reportContent(
          reporterUserId: _currentUserId,
          reportedUserId: _otherPartyId,
          contentType: 'profile',
          content: widget.profileName,
          reason: reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
    );
  }

  /// Ruhiger Nur-Lese-Hinweis anstelle des Eingabefelds (GfK-Ton).
  Widget _readOnlyNotice(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _chatDisabledReason ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sag Hallo!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schreib die erste Nachricht — ihr habt bestimmt etwas gemeinsam.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icebreaker(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 12)),
        onPressed: () {
          _controller.text = text;
          _send();
        },
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 8),
        action: msg.contains('Sitzung') || msg.contains('einloggen')
            ? SnackBarAction(
                label: 'Seite neu laden',
                textColor: Colors.white,
                onPressed: () => _loadMessages(),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.profileName.isNotEmpty
                    ? widget.profileName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _t('convo_parent_network'),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'block') _showBlockDialog();
              if (value == 'report') _showReportSheet();
              if (value == 'refresh') _loadMessages();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(_t('convo_refresh')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 8),
                    Text(_t('chat_report')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Text(_t('convo_block')),
                  ],
                ),
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
                : _chatLoadFailed
                ? Center(child: Text(_t(_chatReadDenied
                    ? 'chat_access_unavailable' : 'friend_chat_request_failed')))
                : _messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.isMe;
                      final showAvatar =
                          !isMe &&
                          (index == 0 || _messages[index - 1].isMe != msg.isMe);
                      final separator = _needsDaySeparator(index)
                          ? _formatDaySeparator(msg.createdAt!)
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Datums-Trenner (Heute / Gestern / Datum)
                          if (separator != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    separator,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: 6,
                              left: isMe ? 48 : 0,
                              right: isMe ? 0 : 48,
                            ),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe && showAvatar)
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    child: Text(
                                      widget.profileName.isNotEmpty
                                          ? widget.profileName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                else if (!isMe)
                                  const SizedBox(width: 28),
                                if (!isMe) const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? theme.colorScheme.primary
                                              : theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: Radius.circular(
                                              isMe ? 16 : 4,
                                            ),
                                            bottomRight: Radius.circular(
                                              isMe ? 4 : 16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          msg.text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isMe
                                                ? Colors.white
                                                : theme.colorScheme.onSurface,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      // Uhrzeit + 'gesendet'-Haekchen
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 3,
                                          left: 4,
                                          right: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (msg.createdAt != null)
                                              Text(
                                                _formatTime(msg.createdAt!),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            if (isMe) ...[
                                              const SizedBox(width: 3),
                                              Icon(
                                                msg.sending
                                                    ? Icons.access_time_rounded
                                                    : Icons.check_rounded,
                                                size: 12,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          // Suggestion chips when empty or few messages
          if (_messages.length < 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _icebreaker('Wie alt sind eure Kinder?'),
                    _icebreaker('Welcher Spielplatz in der Nähe?'),
                    _icebreaker('Treffen diese Woche?'),
                  ],
                ),
              ),
            ),
          // Input — oder Nur-Lese-Hinweis, wenn die Verbindung beendet wurde.
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _chatDisabledReason != null
                  ? _readOnlyNotice(theme)
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Nachricht schreiben...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                          child: IconButton(
                            onPressed: _send,
                            icon: const Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  const _Msg({
    required this.id,
    required this.text,
    required this.isMe,
    this.createdAt,
    this.sending = false,
  });

  final String id;
  final String text;
  final bool isMe;

  /// Sendezeitpunkt (fuer Uhrzeit-Anzeige + Datums-Trenner). Null bei aelteren
  /// Nachrichten ohne Zeitstempel.
  final DateTime? createdAt;

  /// true = optimistisch angezeigt, Server-Bestaetigung steht noch aus.
  final bool sending;
}
