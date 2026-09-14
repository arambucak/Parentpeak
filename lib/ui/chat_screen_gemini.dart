import 'package:flutter/material.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';

class ChatScreenGemini extends StatefulWidget {
  const ChatScreenGemini({super.key});

  @override
  State<ChatScreenGemini> createState() => _ChatScreenGeminiState();
}

class _ChatScreenGeminiState extends State<ChatScreenGemini> {
  late GeminiAIService _geminiService;
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  void _initializeGemini() {
    try {
      _geminiService = GeminiAIService();
    } catch (e) {
      _showError('Fehler bei Initialisierung', e.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    // Nutzer-Nachricht hinzufügen
    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': DateTime.now(),
        'isStreaming': false,
      });
      _controller.clear();
      _isStreaming = true;
    });
    _scrollToBottom();

    // KI-Antwortnachricht (Placeholder) hinzufügen
    final aiMessageIndex = _messages.length;
    setState(() {
      _messages.add({
        'text': '',
        'isUser': false,
        'time': DateTime.now(),
        'isStreaming': true,
      });
    });

    try {
      // Stream die Antwort
      final stream = _geminiService.chatWithStreaming(text);

      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            if (_messages.length > aiMessageIndex) {
              _messages[aiMessageIndex]['text'] += chunk;
            }
          });
          _scrollToBottom();
        }
      }

      // Streaming beendet
      if (mounted) {
        setState(() {
          if (_messages.length > aiMessageIndex) {
            _messages[aiMessageIndex]['isStreaming'] = false;
          }
          _isStreaming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.length > aiMessageIndex) {
            _messages[aiMessageIndex]['text'] =
                'Fehler: Konnte die Antwort nicht verarbeiten. Fehler: $e';
            _messages[aiMessageIndex]['isStreaming'] = false;
          }
          _isStreaming = false;
        });
      }
    }
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Eltern-Assistent (Gemini AI)'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Chat-Bereich
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(context, _messages[index], theme),
                  ),
          ),

          // Input-Bereich
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Stelle eine Frage...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    enabled: !_isStreaming,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: (_isStreaming || _controller.text.trim().isEmpty)
                      ? null
                      : _sendMessage,
                  child: _isStreaming
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7)
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.psychology_rounded,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'Eltern-Assistent (Gemini AI)',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fragen zu Erziehung, Freizeitgestaltung & Sicherheit',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Vorschlag-Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSuggestionChip(
                  'Tipps für Trotzphase',
                  () {
                    _controller.text = 'Wie gehe ich mit der Trotzphase um?';
                    _sendMessage();
                  },
                ),
                _buildSuggestionChip(
                  'Schlafenszeit-Routine',
                  () {
                    _controller.text =
                        'Wie etabliere ich eine gute Schlafenszeit-Routine?';
                    _sendMessage();
                  },
                ),
                _buildSuggestionChip(
                  'Sicherheits-Tipps',
                  () {
                    _controller.text =
                        'Welche Sicherheits-Tipps gibt es für Treffen?';
                    _sendMessage();
                  },
                ),
                _buildSuggestionChip(
                  'Freizeitaktivitäten',
                  () {
                    _controller.text =
                        'Welche Aktivitäten sind für 5-jährige geeignet?';
                    _sendMessage();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    Map<String, dynamic> message,
    ThemeData theme,
  ) {
    final isUser = message['isUser'] as bool;
    final text = message['text'] as String;
    final isStreaming = message['isStreaming'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.psychology_rounded, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.isEmpty && isStreaming ? 'Denke...' : text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        height: 4,
                        width: 20,
                        child: LinearProgressIndicator(
                          backgroundColor: (isUser
                                  ? Colors.white
                                  : Colors.grey[300])!
                              .withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUser ? Colors.white : Colors.grey[600]!,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.person, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
