import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';

class MatchConversationScreen extends StatefulWidget {
  const MatchConversationScreen({
    super.key,
    required this.profileId,
    required this.profileName,
    this.isFriendChat = false,
  });

  final String profileId;
  final String profileName;
  final bool isFriendChat;

  @override
  State<MatchConversationScreen> createState() =>
      _MatchConversationScreenState();
}

class _MatchConversationScreenState extends State<MatchConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ParentMatchingBackendService _service =
      BackendServiceFactory.createParentMatchingService();
  final List<_Msg> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _streamSub;
  bool _streamActive = false;
  bool _isLoading = true;

  String get _currentUserId {
    final value = AuthService.instance.currentUser?.uid.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return 'local-parent-user';
  }

  String get _currentUserName {
    final value = AuthService.instance.currentUser?.displayName.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return 'Ich';
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    if (!widget.isFriendChat) _startLiveStream();
  }

  void _startLiveStream() {
    _streamSub?.cancel();
    _streamSub = _service
        .streamMessages(profileId: widget.profileId, userId: _currentUserId)
        .listen((event) {
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
        _messages.add(_Msg(
          id: id,
          text: content,
          isMe: authorUserId == _currentUserId,
        ));
      });
    }, onError: (_) {
      if (mounted) {
        setState(() => _streamActive = false);
      }
    }, onDone: () {
      if (mounted) {
        setState(() => _streamActive = false);
      }
    });
  }

  Future<void> _loadMessages() async {
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
      _messages
        ..clear()
        ..addAll(items.map((item) {
          final text = (item['content'] ?? '').toString();
          final id = (item['id'] ?? '').toString();
          final authorUserId = (item['authorUserId'] ?? '').toString();
          return _Msg(id: id, text: text, isMe: authorUserId == _currentUserId);
        }));
      _isLoading = false;
    });
  }

  Future<void> _loadFriendMessages() async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final uri = Uri.parse(
        '$base/friend-chat/messages?roomId=${Uri.encodeComponent(widget.profileId)}',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final msgs = List<Map<String, dynamic>>.from(body['messages'] ?? []);
        setState(() {
          _messages
            ..clear()
            ..addAll(msgs.map((m) => _Msg(
                  id: (m['id'] ?? '').toString(),
                  text: (m['content'] ?? '').toString(),
                  isMe: m['authorUserId'] == _currentUserId,
                )));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final optimistic = _Msg(id: 'optimistic-${DateTime.now().microsecondsSinceEpoch}', text: text, isMe: true);

    setState(() {
      _messages.add(optimistic);
      _controller.clear();
    });

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
      setState(() {
        _messages.remove(optimistic);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nachricht konnte nicht gesendet werden.'),
        ),
      );
      return;
    }

    await _loadMessages();
  }

  Future<Map<String, dynamic>?> _sendFriendMessage(String text) async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('$base/friend-chat/messages'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'roomId': widget.profileId,
              'userId': _currentUserId,
              'userName': _currentUserName,
              'content': text,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['item'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profileName),
        actions: [
          if (!widget.isFriendChat && !_streamActive)
            IconButton(
              tooltip: 'Live verbinden',
              onPressed: _startLiveStream,
              icon: const Icon(Icons.wifi_tethering_rounded),
            ),
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final align = msg.isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft;
                      final color = msg.isMe
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest;

                      return Align(
                        alignment: align,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg.text),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Nachricht schreiben...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _send(),
                    child: const Icon(Icons.send_rounded),
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
  const _Msg({required this.id, required this.text, required this.isMe});

  final String id;
  final String text;
  final bool isMe;
}
