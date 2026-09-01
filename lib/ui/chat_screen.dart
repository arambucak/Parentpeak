import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;

  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String _insightsStorageKey = 'ki_chat.topic_counts.v1';
  static const Map<String, List<String>> _topicKeywords = {
    'Autonomiephase': [
      'trotz',
      'wutanfall',
      'grenze',
      'nein',
      'auto nomi',
      'rebellion',
      'eigensinn'
    ],
    'Schlaf': [
      'schlaf',
      'einschlafen',
      'durchschlafen',
      'nacht',
      'muede',
      'müde'
    ],
    'Konflikte': [
      'streit',
      'konflikt',
      'hauen',
      'beissen',
      'beißen',
      'schlag',
      'aggression'
    ],
    'Schule/Kita': [
      'kita',
      'schule',
      'lehrer',
      'lehrerin',
      'hausaufgaben',
      'lernblockade'
    ],
    'Medien': [
      'handy',
      'tablet',
      'medien',
      'bildschirm',
      'youtube',
      'handy sucht'
    ],
    'Bindung & Gefühle': [
      'bindung',
      'angst',
      'trauer',
      'wut',
      'frustration',
      'emotion',
      'gefühl'
    ],
    'Geschwister': ['geschwister', 'eifersucht', 'bruder', 'schwester', 'baby'],
    'Ernährung': ['essen', 'essstörung', 'picky', 'appetit', 'übergewicht'],
    'Krise': [
      'ich kann nicht mehr',
      'notfall',
      'gewalt',
      'kontrolle verlieren',
      'suizid',
      'depressiv'
    ]
  };

  GeminiAIService? _geminiService;
  PedagogicalChatBackend? _chatBackend;
  final List<Map<String, dynamic>> _messages = [];
  final Map<int, String> _assistantFeedbackByIndex = {};
  final Map<String, int> _topicCounts = {};
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;
  String? _initError;
  String _currentResponse = '';
  bool _termsAccepted = true; // wird in initState geladen
  bool _termsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopicInsights();
    _checkTermsAcceptance();
    _initializeGemini();
    // Wenn mit initialMessage geöffnet, automatisch senden
    if (widget.initialMessage != null &&
        widget.initialMessage!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_termsAccepted && _chatBackend != null) {
          _handleInitialMessage(widget.initialMessage!);
        }
      });
    }
  }

  Future<void> _checkTermsAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('chat.terms_accepted') ?? false;
    if (mounted) {
      setState(() {
        _termsAccepted = accepted;
        _termsLoading = false;
      });
    }
  }

  Future<void> _acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat.terms_accepted', true);
    if (mounted) {
      setState(() => _termsAccepted = true);
    }
  }

  Future<void> _loadTopicInsights() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_insightsStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _topicCounts
            ..clear()
            ..addAll(decoded.map((k, v) => MapEntry(k, (v as num).toInt())));
        });
      }
    } catch (e) {
      debugPrint(
          'ChatScreen._loadTopicInsights(): ignoring corrupted local analytics data: $e');
      // Ignore corrupted local analytics data.
    }
  }

  Future<void> _persistTopicInsights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_insightsStorageKey, jsonEncode(_topicCounts));
  }

  String _classifyTopic(String input) {
    final lower = input.toLowerCase();
    for (final entry in _topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return 'Sonstiges';
  }

  Future<void> _trackTopic(String message) async {
    final topic = _classifyTopic(message);
    setState(() {
      _topicCounts[topic] = (_topicCounts[topic] ?? 0) + 1;
    });
    await _persistTopicInsights();
  }

  void _initializeGemini() {
    try {
      _geminiService = GeminiAIService();
      _chatBackend = PedagogicalChatBackend(geminiService: _geminiService);
      setState(() {
        _initError = null;
      });
      debugPrint(
          '✅ Gemini AI initialized with ${APIConfig.getGeminiModelName()}');
    } catch (e) {
      setState(() {
        _initError = 'Fehler: $e';
      });
      debugPrint('Gemini init error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Behandelt eine initiale Nachricht (z.B. vom Tages-Tipp).
  /// Bei ___TIP_EXPAND___ wird die User-Bubble durch eine freundliche
  /// Kontext-Nachricht ersetzt und der KI ein spezieller Prompt gesendet.
  Future<void> _handleInitialMessage(String raw) async {
    if (_isStreaming || _chatBackend == null) return;

    const tipPrefix = '___TIP_EXPAND___';
    if (raw.startsWith(tipPrefix)) {
      final tipText = raw.substring(tipPrefix.length).trim();

      // Zeige eine freundliche System-Nachricht statt dem technischen Prompt
      setState(() {
        _messages.add({
          'role': 'user',
          'content': '\u{1F4A1} Tipp: "$tipText"',
          'timestamp': DateTime.now(),
        });
        _isStreaming = true;
        _currentResponse = '';
      });

      _scrollToBottom();

      // Sende einen smarten Prompt an die KI mit Kind-Alter-Kontext
      int childAge = 3;
      try {
        final profile = await FamilyMatchProfile.load();
        if (profile != null && profile.children.isNotEmpty) {
          childAge =
              (profile.children.first.ageMonths / 12).round().clamp(0, 16);
        }
      } catch (_) {}

      final smartPrompt =
          'KONTEXT: Das Kind des Elternteils ist $childAge Jahre alt.\n\n'
          'Der Elternteil hat diesen Tipp gelesen und will MEHR dazu wissen:\n'
          '"$tipText"\n\n'
          'Antworte SPEZIFISCH für ein $childAge-jähriges Kind:\n'
          '1. Warum ist das bei $childAge-Jährigen besonders relevant? (2 Sätze)\n'
          '2. 3 konkrete Alltagsbeispiele/Situationen\n'
          '3. 1 Übung die der Elternteil HEUTE ausprobieren kann\n\n'
          'Kurz, praktisch, kein Theorievortrag. Max 12 Zeilen.';

      try {
        final stream = _chatBackend!.streamReply(
          history: _messages,
          userMessage: smartPrompt,
        );

        await for (final chunk in stream) {
          if (mounted) {
            setState(() {
              _currentResponse += chunk;
            });
            _scrollToBottom();
          }
        }

        if (mounted) {
          setState(() {
            if (_currentResponse.isNotEmpty) {
              _messages.add({
                'role': 'assistant',
                'content': _currentResponse,
                'timestamp': DateTime.now(),
              });
            }
            _isStreaming = false;
            _currentResponse = '';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isStreaming = false);
        }
      }
      _scrollToBottom();
      return;
    }

    // Normale Nachricht
    _sendMessage(raw);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming || _chatBackend == null) {
      return;
    }

    // Rate limit check
    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': AIRateLimiter.limitReachedMessage,
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();
      return;
    }

    await _trackTopic(text);

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'timestamp': DateTime.now(),
      });
      _isStreaming = true;
      _currentResponse = '';
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final stream = _chatBackend!.streamReply(
        history: _messages,
        userMessage: text,
      );

      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            _currentResponse += chunk;
          });
          _scrollToBottom();
        }
      }

      if (mounted) {
        setState(() {
          if (_currentResponse.isNotEmpty) {
            _messages.add({
              'role': 'assistant',
              'content': _currentResponse,
              'timestamp': DateTime.now(),
            });
          }
          _isStreaming = false;
          _currentResponse = '';
        });
        // Record successful AI request for rate limiting
        await AIRateLimiter.recordRequest();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStreaming = false);
      }
      debugPrint('Error calling Gemini: $e');
    }

    _scrollToBottom();
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

  void _handleSuggestion(String suggestion) {
    _sendMessage(suggestion);
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _assistantFeedbackByIndex.clear();
      _currentResponse = '';
      _isStreaming = false;
    });
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'delete_history_title')),
        content: const Text(
          'Möchtest du den aktuellen Chatverlauf wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _clearChat();
    }
  }

  void _setFeedback(int messageIndex, String value) {
    setState(() {
      _assistantFeedbackByIndex[messageIndex] = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Feedback gespeichert: $value')),
    );
  }

  bool _isProviderUnavailableMessage(String content) {
    final lower = content.toLowerCase();
    return lower.contains('ki-beratung ist aktuell nicht verfügbar') ||
        lower.contains('moeglicher grund:') ||
        lower.contains('debug:');
  }

  String? _findPreviousUserMessage(int assistantIndex) {
    for (var i = assistantIndex - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (msg['role'] == 'user') {
        final content = msg['content']?.toString();
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      }
    }
    return null;
  }

  Future<void> _retryAssistantFailure(int assistantIndex) async {
    if (_isStreaming) {
      return;
    }
    final previousQuestion = _findPreviousUserMessage(assistantIndex);
    if (previousQuestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine vorherige Frage für erneuten Versuch gefunden.'),
        ),
      );
      return;
    }
    await _sendMessage(previousQuestion);
  }

  void _showTopicInsights() {
    final sorted = _topicCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MVP Themenauswertung',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Datensparsam: Es werden nur Themenzähler gespeichert, keine Rohtexte.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (sorted.isEmpty)
                Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'no_questions_yet'))
              else
                ...sorted.map(
                  (entry) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.analytics_outlined),
                    title: Text(entry.key),
                    trailing: Text('${entry.value}'),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    setState(_topicCounts.clear);
                    await _persistTopicInsights();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'reset_counter')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8543A).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  size: 18, color: Color(0xFFE8543A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sicher & transparent',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Keine Diagnosen, keine Therapie. Deine Fragen bleiben privat.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF516072),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantFeedbackRow(int index) {
    final selected = _assistantFeedbackByIndex[index];
    final content = _messages[index]['content']?.toString() ?? '';
    final showRetry = _isProviderUnavailableMessage(content);
    Widget chip(String label, IconData icon) {
      final isSelected = selected == label;
      return ChoiceChip(
        selected: isSelected,
        selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.16),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: const Color(0xFFB8C4D6).withValues(alpha: 0.9),
            width: 1.1,
          ),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        onSelected: (_) => _setFeedback(index, label),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 8, bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (showRetry)
            OutlinedButton.icon(
              onPressed:
                  _isStreaming ? null : () => _retryAssistantFailure(index),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'try_again')),
            ),
          chip('hilfreich', Icons.thumb_up_alt_outlined),
          chip('nicht hilfreich', Icons.thumb_down_alt_outlined),
          chip('gefaehrlich', Icons.report_gmailerrorred_rounded),
          chip('unpassend', Icons.rule_rounded),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                size: 40,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Wie kann ich dir helfen?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2A3A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Kind hängt nur am Handy'),
                _buildSuggestionChip('Mein Kind ist außer sich'),
                _buildSuggestionChip('Mein Kind hört nicht'),
                _buildSuggestionChip('Ich bin total erschöpft'),
                _buildSuggestionChip('Kind braucht mehr Freiheit'),
                _buildSuggestionChip('Strafe oder Konsequenz?'),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Keine Diagnosen · Keine Therapie · Privat',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFADB8C4),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSuggestion(label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F7FD),
            border: Border.all(
              color: const Color(0xFFB8CDE0),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 0.1,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F4E79),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF0284C7),
              child: Icon(
                Icons.psychology_alt_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isUser ? const Color(0xFF0284C7) : const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 8),
                  bottomRight: Radius.circular(isUser ? 8 : 22),
                ),
                border: !isUser
                    ? Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: (isUser
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF1A2A3A))
                        .withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      message['content'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        letterSpacing: 0.15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : _buildFormattedText(message['content'] as String),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE8543A),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text) {
    // Konvertiert **bold** zu echtem Bold-Text und rendert sauber
    final spans = <InlineSpan>[];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      if (i % 2 == 1) {
        // Bold-Teil (zwischen **)
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF0F172A),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF1A2A3A),
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildTermsScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                'KI-Elternberatung',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bevor du startest, lies bitte kurz durch:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Bedingungen
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTermsItem(
                      theme,
                      '\u{1F6E1}\u{FE0F}',
                      'Keine Diagnosen',
                      'Die KI stellt keine medizinischen oder psychologischen Diagnosen. Bei ernsthaften Sorgen wende dich an Fachpersonal.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsItem(
                      theme,
                      '\u{1F512}',
                      'Deine Daten bleiben privat',
                      'Gespräche werden lokal auf deinem Gerät gespeichert. Wir teilen keine Inhalte mit Dritten.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsItem(
                      theme,
                      '\u{1F49C}',
                      'Respektvoll & wertschätzend',
                      'Die KI urteilt nie über dich oder dein Kind. Sie begleitet — ohne Schuldzuweisung, ohne Druck.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Akzeptieren Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _acceptTerms,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Verstanden, los geht\u{0027}s',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Zurück',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsItem(
      ThemeData theme, String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nutzungsbedingungen beim ersten Mal zeigen
    if (!_termsLoading && !_termsAccepted) {
      return _buildTermsScreen(context);
    }

    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'ki_parenting_title')),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Themenauswertung',
              onPressed: _showTopicInsights,
              icon: const Icon(Icons.analytics_outlined),
            ),
            IconButton(
              tooltip: 'Chat loeschen',
              onPressed: _messages.isEmpty ? null : _confirmClearChat,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Du kannst es später erneut versuchen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: _initializeGemini,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'try_again')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology_alt_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'KI Elternberatung',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Immer für dich da • GfK-orientiert',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Themenauswertung',
            onPressed: _showTopicInsights,
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Chat löschen',
            onPressed: _messages.isEmpty ? null : _confirmClearChat,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6FBFF),
              Color(0xFFF8FAFD),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildSafetyBanner(),
            Expanded(
              child: _messages.isEmpty && !_isStreaming
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isStreaming ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _messages.length) {
                          final message = _messages[index];
                          final isAssistant = message['role'] == 'assistant';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMessageBubble(message),
                              if (isAssistant)
                                _buildAssistantFeedbackRow(index),
                            ],
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: 0.2),
                                      child: Icon(
                                        Icons.psychology,
                                        size: 18,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Schreibt...',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    minHeight: 4,
                                    backgroundColor: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE0E6ED),
                    width: 1,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 10,
                bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isStreaming && _chatBackend != null,
                      decoration: InputDecoration(
                        hintText: 'Erzähle mir, was dich bewegt...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8A9AB0),
                          fontSize: 15,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Icon(
                            Icons.edit_rounded,
                            color: Color(0xFF0284C7),
                            size: 20,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E6ED),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E6ED),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF0284C7),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFD),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        letterSpacing: 0.15,
                        color: Color(0xFF1A2A3A),
                        fontWeight: FontWeight.w500,
                      ),
                      onSubmitted: (value) {
                        _sendMessage(value);
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    backgroundColor: _isStreaming || _controller.text.isEmpty
                        ? const Color(0xFFE0E6ED)
                        : const Color(0xFF0284C7),
                    foregroundColor: _isStreaming || _controller.text.isEmpty
                        ? const Color(0xFF8A9AB0)
                        : Colors.white,
                    onPressed: _isStreaming || _controller.text.isEmpty
                        ? null
                        : () => _sendMessage(_controller.text),
                    child: _isStreaming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0284C7),
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
