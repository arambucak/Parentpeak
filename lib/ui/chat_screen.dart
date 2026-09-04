import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
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

// ─── Markenfarben ─────────────────────────────────────────────────────────
const Color _kBrand = Color(0xFF8B5CF6); // Lila (Marke)
const Color _kBrand2 = Color(0xFF7C3AED); // Dunkleres Lila
const Color _kGreen = Color(0xFF16A34A); // Grün (Marke)
const Color _kBg = Color(0xFFF7F5FF); // Sanfter lila-weißer Hintergrund
const Color _kAiBubble = Colors.white;
const Color _kInk = Color(0xFF1F2937);

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
        _initError = context.tr('chat_init_error', values: {'error': '$e'});
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
          'content': context.tr('chat_tip_message', values: {'tip': tipText}),
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
        content: Text(context.tr('chat_delete_history_confirm')),
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
      SnackBar(
        content: Text(context.tr(
          'chat_feedback_saved',
          values: {'feedback': context.tr('chat_feedback_$value')},
        )),
      ),
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
        SnackBar(
          content: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'chat_retry_missing_question')),
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
                context.tr('chat_topic_analysis_title'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('chat_topic_analysis_privacy'),
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
                    title: Text(_topicLabel(entry.key)),
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

  String _topicLabel(String topicId) {
    const keys = {
      'Autonomiephase': 'chat_insight_autonomy',
      'Schlaf': 'chat_insight_sleep',
      'Konflikte': 'chat_insight_conflicts',
      'Schule/Kita': 'chat_insight_school',
      'Medien': 'chat_insight_media',
      'Bindung & Gefühle': 'chat_insight_attachment',
      'Geschwister': 'chat_insight_siblings',
      'Ernährung': 'chat_insight_nutrition',
      'Krise': 'chat_insight_crisis',
      'Sonstiges': 'chat_insight_other',
    };
    final key = keys[topicId];
    return key == null ? topicId : context.tr(key);
  }

  Widget _buildAssistantFeedbackRow(int index) {
    final selected = _assistantFeedbackByIndex[index];
    final content = _messages[index]['content']?.toString() ?? '';
    final showRetry = _isProviderUnavailableMessage(content);
    Widget chip(String feedbackId, IconData icon) {
      final isSelected = selected == feedbackId;
      return ChoiceChip(
        selected: isSelected,
        selectedColor: _kBrand.withValues(alpha: 0.14),
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
              context.tr('chat_feedback_$feedbackId'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        onSelected: (_) => _setFeedback(index, feedbackId),
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
          chip('helpful', Icons.thumb_up_alt_outlined),
          chip('not_helpful', Icons.thumb_down_alt_outlined),
          chip('dangerous', Icons.report_gmailerrorred_rounded),
          chip('inappropriate', Icons.rule_rounded),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // Zeitbasierte Begrüßung
    final hour = DateTime.now().hour;
    final greetingKey = hour < 11
      ? 'chat_greeting_morning'
        : hour < 17
        ? 'chat_greeting_day'
            : hour < 22
          ? 'chat_greeting_evening'
          : 'chat_greeting_night';

    final topics = [
      {
        'emoji': '😤',
      'label': context.tr('chat_topic_tantrum_label'),
      'q': context.tr('chat_topic_tantrum_question'),
      },
      {
        'emoji': '😴',
        'label': context.tr('chat_topic_sleep_label'),
        'q': context.tr('chat_topic_sleep_question'),
      },
      {
        'emoji': '📱',
        'label': context.tr('chat_topic_screen_label'),
        'q': context.tr('chat_topic_screen_question'),
      },
      {
        'emoji': '👫',
        'label': context.tr('chat_topic_siblings_label'),
        'q': context.tr('chat_topic_siblings_question'),
      },
      {
        'emoji': '💔',
        'label': context.tr('chat_topic_overwhelmed_label'),
        'q': context.tr('chat_topic_overwhelmed_question'),
      },
      {
        'emoji': '🎒',
        'label': context.tr('chat_topic_school_label'),
        'q': context.tr('chat_topic_school_question'),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Begrüßungs-Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kBrand.withValues(alpha: 0.10),
                  _kGreen.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kBrand, _kBrand2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  '${context.tr(greetingKey)} 💜',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('chat_welcome_message'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('chat_how_can_help'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          // Themen-Karten
          ...topics.map((t) => _buildTopicCard(
                t['emoji']!,
                t['label']!,
                t['q']!,
              )),
        ],
      ),
    );
  }

  Widget _buildTopicCard(String emoji, String label, String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _handleSuggestion(question),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBrand.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: 18, color: _kBrand.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kBrand, _kBrand2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 17, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [_kBrand, _kBrand2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : _kAiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? _kBrand : Colors.black)
                        .withValues(alpha: isUser ? 0.20 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      message['content'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : _buildFormattedText(message['content'] as String),
            ),
          ),
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
            height: 1.55,
            color: _kBrand2,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            height: 1.55,
            color: _kInk,
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
                    colors: [_kBrand, _kBrand2],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _kBrand.withValues(alpha: 0.25),
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
                context.tr('ki_parenting_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('chat_terms_intro'),
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
                      context.tr('chat_terms_no_diagnosis_title'),
                      context.tr('chat_terms_no_diagnosis_text'),
                    ),
                    const SizedBox(height: 16),
                    _buildTermsItem(
                      theme,
                      '\u{1F512}',
                      context.tr('chat_terms_privacy_title'),
                      context.tr('chat_terms_privacy_text'),
                    ),
                    const SizedBox(height: 16),
                    _buildTermsItem(
                      theme,
                      '\u{1F49C}',
                      context.tr('chat_terms_respect_title'),
                      context.tr('chat_terms_respect_text'),
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
                    backgroundColor: _kBrand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.tr('chat_terms_accept'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.tr('back_btn'),
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
              tooltip: context.tr('tooltip_topic_analysis'),
              onPressed: _showTopicInsights,
              icon: const Icon(Icons.analytics_outlined),
            ),
            IconButton(
              tooltip: context.tr('tooltip_delete_chat'),
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
                  context.tr('chat_retry_later'),
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
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kBrand,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kBrand, _kBrand2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('ki_parenting_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Row(children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.tr('chat_always_here'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ]),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('tooltip_topic_analysis'),
            onPressed: _showTopicInsights,
            icon: const Icon(Icons.insights_rounded, color: _kBrand),
          ),
          IconButton(
            tooltip: context.tr('tooltip_delete_chat'),
            onPressed: _messages.isEmpty ? null : _confirmClearChat,
            icon: Icon(Icons.delete_outline_rounded,
                color: _messages.isEmpty ? Colors.grey[400] : _kBrand),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBg, Color(0xFFFCFBFF)],
          ),
        ),
        child: Column(
          children: [
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
                          // Streaming: zeige die Live-Antwort oder Typing-Dots
                          if (_currentResponse.isNotEmpty) {
                            return _buildMessageBubble({
                              'role': 'assistant',
                              'content': _currentResponse,
                            });
                          }
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: _TypingIndicator(),
                          );
                        }
                      },
                    ),
            ),
            // Dezenter Sicherheitshinweis
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 11, color: Colors.grey[400]),
                  const SizedBox(width: 5),
                  Text(
                    context.tr('chat_privacy_footer'),
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEDE9FE), width: 1),
                ),
              ),
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isStreaming && _chatBackend != null,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: AppStringsManager.getString(
                          languageService.currentLanguage,
                          'chat_message_hint'),
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide:
                              const BorderSide(color: _kBrand, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: _kBg,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: _kInk,
                        fontWeight: FontWeight.w500,
                      ),
                      onSubmitted: (value) => _sendMessage(value),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isStreaming || _controller.text.trim().isEmpty
                        ? null
                        : () => _sendMessage(_controller.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient:
                            _isStreaming || _controller.text.trim().isEmpty
                                ? null
                                : const LinearGradient(
                                    colors: [_kBrand, _kBrand2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                        color: _isStreaming || _controller.text.trim().isEmpty
                            ? const Color(0xFFEDE9FE)
                            : null,
                        shape: BoxShape.circle,
                        boxShadow:
                            _isStreaming || _controller.text.trim().isEmpty
                                ? null
                                : [
                                    BoxShadow(
                                      color: _kBrand.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                      ),
                      child: _isStreaming
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_kBrand),
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              size: 22,
                              color: _controller.text.trim().isEmpty
                                  ? Colors.grey[400]
                                  : Colors.white,
                            ),
                    ),
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

// ─── Moderner Typing-Indikator (animierte Punkte) ──────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kBrand, _kBrand2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 17, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _kAiBubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_controller.value - i * 0.2) % 1.0;
                  final scale = t < 0.5 ? 0.6 + t * 0.8 : 1.4 - t * 0.8;
                  return Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    child: Transform.scale(
                      scale: scale.clamp(0.6, 1.0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              _kBrand.withValues(alpha: scale.clamp(0.4, 1.0)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
