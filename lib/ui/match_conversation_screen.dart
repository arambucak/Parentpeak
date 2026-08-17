import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';

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
    // Prefer FirebaseAuth (always in sync) over AuthService wrapper
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (firebaseUid != null && firebaseUid.isNotEmpty) return firebaseUid;
    final value = AuthService.instance.currentUser?.uid.trim();
    if (value != null && value.isNotEmpty) return value;
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
    // Auto-poll for new messages every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) _loadMessages();
    });
  }

  Timer? _pollTimer;

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
      final headers = await _authHeaders();
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 401) {
        // Retry without auth — GET may not need it
        final retryResp = await http.get(uri, headers: {
          'Content-Type': 'application/json'
        }).timeout(const Duration(seconds: 10));
        if (!mounted) return;
        if (retryResp.statusCode >= 200 && retryResp.statusCode < 300) {
          final body = jsonDecode(retryResp.body) as Map<String, dynamic>;
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
          return;
        }
        _showError(
            'Sitzung abgelaufen — bitte Seite neu laden oder erneut einloggen.');
        setState(() => _isLoading = false);
        return;
      }
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
    _pollTimer?.cancel();
    _streamSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
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
        isMe: true);

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
      setState(() => _messages.remove(optimistic));
      return;
    }

    await _loadMessages();
  }

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    // currentUser can be null on web while Firebase restores the session
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
      // Fallback: use backend API token if Firebase session is lost
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

  Future<Map<String, dynamic>?> _sendFriendMessage(String text) async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null) {
      _showError('Backend-URL fehlt');
      return null;
    }
    try {
      final headers = await _authHeaders();
      final resp = await http
          .post(
            Uri.parse('$base/friend-chat/messages'),
            headers: headers,
            body: jsonEncode({
              'roomId': widget.profileId,
              'userId': _currentUserId,
              'userName': _currentUserName,
              'content': text,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['item'] as Map<String, dynamic>?;
      }
      if (resp.statusCode == 401) {
        // Retry once with forced token refresh
        final freshHeaders = await _authHeaders(forceRefresh: true);
        if (!freshHeaders.containsKey('Authorization')) {
          _showError(
              'Sitzung abgelaufen — bitte Seite neu laden oder erneut einloggen.');
          return null;
        }
        final retryResp = await http
            .post(
              Uri.parse('$base/friend-chat/messages'),
              headers: freshHeaders,
              body: jsonEncode({
                'roomId': widget.profileId,
                'userId': _currentUserId,
                'userName': _currentUserName,
                'content': text,
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (retryResp.statusCode == 201) {
          final body = jsonDecode(retryResp.body) as Map<String, dynamic>;
          return body['item'] as Map<String, dynamic>?;
        }
        _showError(
            'Sitzung abgelaufen — bitte Seite neu laden oder erneut einloggen.');
      } else {
        _showError('Fehler ${resp.statusCode}');
      }
      return null;
    } catch (e) {
      _showError('Netzwerkfehler: $e');
      return null;
    }
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
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.waving_hand_rounded,
                  size: 32, color: theme.colorScheme.primary),
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
        backgroundColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 8),
      action: msg.contains('Sitzung') || msg.contains('einloggen')
          ? SnackBarAction(
              label: 'Seite neu laden',
              textColor: Colors.white,
              onPressed: () => _loadMessages(),
            )
          : null,
    ));
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
                  Text(widget.profileName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('Eltern-Netzwerk',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.isMe;
                          final showAvatar = !isMe &&
                              (index == 0 ||
                                  _messages[index - 1].isMe != msg.isMe);

                          return Padding(
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
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft:
                                            Radius.circular(isMe ? 16 : 4),
                                        bottomRight:
                                            Radius.circular(isMe ? 4 : 16),
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
                                ),
                              ],
                            ),
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
          // Input
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
              child: Row(
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
                            horizontal: 18, vertical: 12),
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
                      icon: const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
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
  const _Msg({required this.id, required this.text, required this.isMe});

  final String id;
  final String text;
  final bool isMe;
}
