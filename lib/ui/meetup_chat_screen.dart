import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/logic/meetup_chat_service.dart';
import 'package:parentpeak/models/meetup_chat.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class MeetupChatScreen extends StatefulWidget {
  final MeetupEvent event;

  const MeetupChatScreen({super.key, required this.event});

  @override
  State<MeetupChatScreen> createState() => _MeetupChatScreenState();
}

class _MeetupChatScreenState extends State<MeetupChatScreen> {
  final _chatService = MeetupChatService();
  final _messageController = TextEditingController();

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  final _scrollController = ScrollController();

  List<MeetupChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasAccess = false;
  Timer? _refreshTimer;
  bool _requiresSignIn = false;

  String get _currentUserId => AuthService.instance.currentUser?.uid ?? '';
  String get _currentUserName =>
      AuthService.instance.currentUser?.displayName ?? 'Unbekannt';
  String get _currentUserAvatar => '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    // Lade Nachrichten alle 2 Sekunden (Polling)
    Future.delayed(const Duration(milliseconds: 500), _setupAutoRefresh);
  }

  Future<void> _bootstrap() async {
    if (_currentUserId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _requiresSignIn = true;
        _hasAccess = false;
        _isLoading = false;
      });
      return;
    }

    final access = await _chatService.hasAccessToChat(
      eventId: widget.event.id,
      userId: _currentUserId,
      hosterId: widget.event.hosterId,
    );
    if (!mounted) return;
    setState(() => _hasAccess = access);
    if (!access) {
      setState(() => _isLoading = false);
      return;
    }
    await _loadMessages();
  }

  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || !_hasAccess || _isSending) return;
      await _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(widget.event.id);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final messageText = _messageController.text;
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final message = await _chatService.sendMessage(
        eventId: widget.event.id,
        userId: _currentUserId,
        userName: _currentUserName,
        userAvatarUrl: _currentUserAvatar,
        content: messageText,
        isHost: _currentUserId == widget.event.hosterId,
      );

      setState(() {
        _messages.add(message);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      _messageController.text = messageText;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Senden: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _reportMessage(MeetupChatMessage message) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('chat_report_message')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_t('chat_inappropriate')),
              onTap: () => Navigator.pop(context, 'inappropriate'),
            ),
            ListTile(
              title: Text(_t('chat_spam')),
              onTap: () => Navigator.pop(context, 'spam'),
            ),
            ListTile(
              title: Text(_t('chat_safety_concern')),
              onTap: () => Navigator.pop(context, 'safety'),
            ),
            ListTile(
              title: Text(_t('chat_other')),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );

    if (reason != null && mounted) {
      try {
        await _chatService.reportMessage(
          eventId: widget.event.id,
          reportedMessageId: message.id,
          reporterId: _currentUserId,
          reason: reason,
          description: 'User-Report',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('chat_report_thanks'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  void _showMessageOptions(MeetupChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag),
              title: Text(_t('chat_report')),
              onTap: () {
                Navigator.pop(context);
                _reportMessage(message);
              },
            ),
            if (message.userId == _currentUserId)
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(_t('chat_delete')),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(MeetupChatMessage message) async {
    try {
      await _chatService.deleteMessage(widget.event.id, message.id);
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('common_delete_failed')
                .replaceAll('{error}', '$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.event.title),
            Text(
              'Chat (${_messages.length} Nachrichten)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(_t('chat_guidelines')),
                  content: const Text(
                    '• Sei respektvoll gegenüber anderen\n'
                    '• Kein Spam oder unangemessener Inhalt\n'
                    '• Teile keine persönlichen Informationen\n'
                    '• Nur bestätigte Teilnehmer können chatten',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_t('chat_understood')),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasAccess
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _requiresSignIn
                                    ? 'Bitte melde dich an, um den Chat zu nutzen.'
                                    : 'Chat nur für bestätigte Teilnehmer',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'Keine Nachrichten noch',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sei der Erste, der schreibt!',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) =>
                                _buildMessageBubble(_messages[index]),
                          ),
          ),
          // Input Area
          if (_hasAccess)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Nachricht...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    onPressed: (_messageController.text.isEmpty || _isSending)
                        ? null
                        : _sendMessage,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MeetupChatMessage message) {
    final isCurrentUser = message.userId == _currentUserId;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MessageAvatar(
                  name: message.userName,
                  avatarUrl: message.userAvatarUrl,
                ),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        message.userName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? Theme.of(context).primaryColor
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  if (message.isHost)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'HOST',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _MessageAvatar(
                  name: message.userName,
                  avatarUrl: message.userAvatarUrl,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 16,
      child: Text(initial),
    );
  }
}
