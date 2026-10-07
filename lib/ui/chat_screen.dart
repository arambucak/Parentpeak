import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/ui/widgets/chat_account_modal.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/models/ai_memory.dart';
import 'package:parentpeak/ui/ai_memory_settings_screen.dart';
import 'package:parentpeak/main.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  final PedagogicalChatBackend? chatBackend;
  final ChatAccountStore? accountStore;
  final AiMemoryService? memoryService;

  const ChatScreen({
    super.key,
    this.initialMessage,
    this.chatBackend,
    this.accountStore,
    this.memoryService,
  });

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
  static const Map<String, List<String>> _topicKeywords = {
    'Autonomiephase': [
      'trotz',
      'wutanfall',
      'grenze',
      'nein',
      'auto nomi',
      'rebellion',
      'eigensinn',
    ],
    'Schlaf': [
      'schlaf',
      'einschlafen',
      'durchschlafen',
      'nacht',
      'muede',
      'müde',
    ],
    'Konflikte': [
      'streit',
      'konflikt',
      'hauen',
      'beissen',
      'beißen',
      'schlag',
      'aggression',
    ],
    'Schule/Kita': [
      'kita',
      'schule',
      'lehrer',
      'lehrerin',
      'hausaufgaben',
      'lernblockade',
    ],
    'Medien': [
      'handy',
      'tablet',
      'medien',
      'bildschirm',
      'youtube',
      'handy sucht',
    ],
    'Bindung & Gefühle': [
      'bindung',
      'angst',
      'trauer',
      'wut',
      'frustration',
      'emotion',
      'gefühl',
    ],
    'Geschwister': ['geschwister', 'eifersucht', 'bruder', 'schwester', 'baby'],
    'Ernährung': ['essen', 'essstörung', 'picky', 'appetit', 'übergewicht'],
    'Krise': [
      'ich kann nicht mehr',
      'notfall',
      'gewalt',
      'kontrolle verlieren',
      'suizid',
      'depressiv',
    ],
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
  bool _termsAccepted = false;
  bool _termsLoading = true;
  bool _termsSaving = false;
  bool _initialMessageHandled = false;
  String? _termsErrorKey;
  late final ChatAiConsent _consent;
  late String _consentScope;
  late final ChatAccountStore _store;
  late final AiMemoryService _memoryService;
  late ChatAccountTicket _ticket;
  int _requestGeneration = 0;
  StreamIterator<String>? _replyIterator;
  bool _topicsLoading = true;
  bool _hasLegacy = false;
  String? _topicsErrorKey;
  // Land des Nutzers (aus Onboarding) für länderrichtige Notrufnummern im
  // Krisenfall. Default DE; wird in initState aus den Prefs geladen.
  String? _countryCode;
  // Aktives Kind-Profil für das KI-Gedächtnis. Nur gesetzt, wenn das Gedächtnis
  // AKTIVIERT ist und mindestens ein Kinderprofil existiert — sonst null
  // (kein Kontext, Datenschutz by default). Wird an streamReply übergeben,
  // damit der Server den bestätigten Familienkontext einspeisen kann.
  String? _activeChildProfileId;

  @override
  void initState() {
    super.initState();
    _consent = widget.chatBackend?.consent ?? ChatAiConsent.instance;
    _store =
        widget.accountStore ??
        widget.chatBackend?.accountStore ??
        ChatAccountStore.instance;
    _ticket = _store.ticket;
    _memoryService =
        widget.memoryService ?? AiMemoryService(accountStore: _store);
    _store.addListener(_onAccountChanged);
    _consentScope = _consent.scope;
    AuthService.instance.addListener(_onConsentScopeChanged);
    _loadTopicInsights();
    _checkTermsAcceptance();
    _loadCountryCode();
    _loadActiveChildProfile();
    _initializeGemini();
    _maybeSendInitialMessage();
  }

  bool _isCurrent(ChatAccountTicket ticket, [int? request]) {
    if (!mounted) return false;
    try {
      _store.require(ticket);
      return request == null || request == _requestGeneration;
    } on ChatAccountChanged {
      return false;
    }
  }

  void _invalidateReply() {
    _requestGeneration++;
    final iterator = _replyIterator;
    _replyIterator = null;
    if (iterator != null) unawaited(_cancelIterator(iterator));
    _isStreaming = false;
    _currentResponse = '';
  }

  Future<void> _cancelIterator(StreamIterator<String> iterator) async {
    final ticket = _ticket;
    final generation = _requestGeneration;
    try {
      await iterator.cancel();
    } catch (error) {
      debugPrint('Chat reply cancellation: $error');
      if (error is! ChatAccountChanged &&
          error is! AccountAiConsentRequiredException &&
          _isCurrent(ticket, generation)) {
        _showError('chat_request_failed');
      }
    }
  }

  void _onAccountChanged() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    _invalidateReply();
    _controller.clear();
    setState(() {
      _ticket = _store.ticket;
      _messages.clear();
      _assistantFeedbackByIndex.clear();
      _topicCounts.clear();
      _activeChildProfileId = null;
      _countryCode = null;
      _hasLegacy = false;
      _topicsLoading = true;
      _topicsErrorKey = null;
      _termsSaving = false;
      _termsAccepted = false;
      _termsLoading = true;
      _termsErrorKey = null;
      _consentScope = _consent.scope;
      _initialMessageHandled = true;
    });
    _checkTermsAcceptance();
    _loadTopicInsights();
    _loadCountryCode();
    _loadActiveChildProfile();
  }

  void _onConsentScopeChanged() {
    if (!mounted || _consent.scope == _consentScope) return;
    setState(() {
      _consentScope = _consent.scope;
      _termsAccepted = false;
      _termsLoading = true;
      _termsErrorKey = null;
      _initialMessageHandled = true;
    });
    _checkTermsAcceptance();
  }

  void _maybeSendInitialMessage() {
    final initial = widget.initialMessage;
    if (_initialMessageHandled ||
        initial == null ||
        initial.trim().isEmpty ||
        _termsLoading ||
        !_termsAccepted ||
        _chatBackend == null) {
      return;
    }
    _initialMessageHandled = true;
    final scope = _consentScope;
    final ticket = _ticket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrent(ticket) &&
          !_termsLoading &&
          _termsAccepted &&
          _consentScope == scope &&
          _consent.scope == scope) {
        _handleInitialMessage(initial);
      }
    });
  }

  Future<bool> _canSendWithConsent() async {
    if (!mounted || _termsLoading || !_termsAccepted) return false;
    final ticket = _ticket;
    try {
      await _consent.require(_consentScope);
      return _isCurrent(ticket);
    } catch (error) {
      debugPrint('Chat consent verification failed: $error');
      if (_isCurrent(ticket)) {
        setState(() {
          _termsAccepted = false;
          _termsErrorKey = 'chat_consent_load_failed';
        });
      }
      return false;
    }
  }

  Future<void> _loadCountryCode() async {
    final ticket = _ticket;
    final prefs = await SharedPreferences.getInstance();
    // Gleiche Quelle wie Kalender/Feiertage + Familien-Geld (Onboarding).
    final country = prefs.getString('holiday.country');
    if (_isCurrent(ticket) && country != null && country.trim().isNotEmpty) {
      setState(() => _countryCode = country.trim());
    }
  }

  /// Ermittelt das aktive Kind-Profil fürs KI-Gedächtnis. Läuft nur, wenn das
  /// Gedächtnis aktiviert ist; wählt bei einem Kind dieses, bei mehreren das
  /// zuletzt aktualisierte (Server liefert bereits updatedAt-absteigend).
  /// Eine null-ID sperrt serverseitiges Memory nicht; dessen Opt-in bleibt
  /// eine eigene Grenze. Ladefehler werden sichtbar behandelt.
  Future<void> _loadActiveChildProfile() async {
    final ticket = _ticket;
    final service = _memoryService;
    if (!service.isEnabled) return;
    try {
      final settings = await service.getSettings();
      if (!_isCurrent(ticket)) return;
      final children = settings.enabled
          ? await service.getChildren()
          : const <AiChildProfile>[];
      final activeId = AiMemoryService.resolveActiveChildId(
        memoryEnabled: settings.enabled,
        children: children,
      );
      if (_isCurrent(ticket)) {
        setState(() => _activeChildProfileId = activeId);
      }
    } catch (error) {
      debugPrint('Chat memory load failed: $error');
      if (_isCurrent(ticket)) {
        setState(() => _activeChildProfileId = null);
        _showError('chat_memory_load_failed');
      }
    }
  }

  Future<void> _checkTermsAcceptance() async {
    final scope = _consentScope;
    final ticket = _ticket;
    try {
      final accepted = await _consent.hasConsent();
      if (!_isCurrent(ticket) ||
          scope != _consentScope ||
          scope != _consent.scope) {
        return;
      }
      setState(() {
        _termsAccepted = accepted;
        _termsLoading = false;
        _termsErrorKey = null;
      });
      _maybeSendInitialMessage();
    } catch (error) {
      debugPrint('Chat consent load failed: $error');
      if (!_isCurrent(ticket) || scope != _consentScope) return;
      setState(() {
        _termsAccepted = false;
        _termsLoading = false;
        _termsErrorKey = 'chat_consent_load_failed';
      });
    }
  }

  Future<void> _acceptTerms() async {
    if (_termsSaving) return;
    final scope = _consentScope;
    final ticket = _ticket;
    setState(() {
      _termsSaving = true;
      _termsErrorKey = null;
    });
    try {
      await _consent.grant(scope);
      if (!_isCurrent(ticket) ||
          scope != _consentScope ||
          scope != _consent.scope) {
        return;
      }
      setState(() => _termsAccepted = true);
      _maybeSendInitialMessage();
    } catch (error) {
      debugPrint('Chat consent save failed: $error');
      if (_isCurrent(ticket) && scope == _consentScope) {
        setState(() => _termsErrorKey = 'chat_consent_save_failed');
      }
    } finally {
      if (_isCurrent(ticket)) setState(() => _termsSaving = false);
    }
  }

  Future<void> _loadTopicInsights() async {
    final ticket = _ticket;
    try {
      final counts = await _store.read(ticket);
      final legacy = await _store.hasLegacy(ticket);
      if (!_isCurrent(ticket)) return;
      setState(() {
        _topicCounts
          ..clear()
          ..addAll(counts);
        _hasLegacy = legacy;
        _topicsLoading = false;
        _topicsErrorKey = null;
      });
    } catch (error) {
      debugPrint('Chat topic load failed: $error');
      if (!_isCurrent(ticket)) return;
      setState(() {
        _topicsLoading = false;
        _topicsErrorKey = 'chat_topics_load_failed';
      });
    }
  }

  void _showError(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _claimLegacy() async {
    final ticket = _ticket;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => ChatAccountModal(
        store: _store,
        ticket: ticket,
        builder: (context) => AlertDialog(
          title: Text(context.tr('chat_legacy_title')),
          content: Text(context.tr('chat_legacy_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('chat_claim_action')),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !_isCurrent(ticket)) return;
    try {
      final counts = await _store.claim(ticket);
      if (!_isCurrent(ticket)) return;
      setState(() {
        _topicCounts
          ..clear()
          ..addAll(counts);
        _hasLegacy = false;
      });
    } catch (error) {
      debugPrint('Chat legacy claim failed: $error');
      if (_isCurrent(ticket)) _showError('chat_claim_failed');
    }
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

  Future<void> _trackTopic(String message, ChatAccountTicket ticket) async {
    final topic = _classifyTopic(message);
    final counts = await _store.increment(ticket, topic);
    if (_isCurrent(ticket)) {
      setState(
        () => _topicCounts
          ..clear()
          ..addAll(counts),
      );
    }
  }

  void _initializeGemini() {
    try {
      if (widget.chatBackend != null) {
        _chatBackend = widget.chatBackend;
      } else {
        _geminiService = GeminiAIService();
        _chatBackend = PedagogicalChatBackend(
          geminiService: _geminiService,
          consent: _consent,
          accountStore: _store,
        );
      }
      setState(() {
        _initError = null;
      });
      debugPrint(
        '✅ Gemini AI initialized with ${APIConfig.getGeminiModelName()}',
      );
    } catch (e) {
      setState(() {
        _initError = context.tr('chat_init_error', values: {'error': '$e'});
      });
      debugPrint('Gemini init error: $e');
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onAccountChanged);
    _invalidateReply();
    _messages.clear();
    _topicCounts.clear();
    _assistantFeedbackByIndex.clear();
    _activeChildProfileId = null;
    AuthService.instance.removeListener(_onConsentScopeChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Behandelt eine initiale Nachricht (z.B. vom Tages-Tipp).
  /// Bei ___TIP_EXPAND___ wird die User-Bubble durch eine freundliche
  /// Kontext-Nachricht ersetzt und der KI ein spezieller Prompt gesendet.
  Future<void> _handleInitialMessage(String raw) async {
    const tipPrefix = '___TIP_EXPAND___';
    if (!raw.startsWith(tipPrefix)) {
      await _sendMessage(raw);
      return;
    }
    if (_isStreaming || _chatBackend == null) return;
    final ticket = _ticket;
    final request = ++_requestGeneration;
    setState(() => _isStreaming = true);
    final tipText = raw.substring(tipPrefix.length).trim();
    try {
      if (!await _canSendWithConsent() || !_isCurrent(ticket, request)) return;
      int childAge = 3;
      try {
        final profile = await FamilyMatchProfile.load();
        if (!_isCurrent(ticket, request)) return;
        if (profile != null && profile.children.isNotEmpty) {
          childAge = (profile.children.first.ageMonths / 12).round().clamp(
            0,
            16,
          );
        }
      } catch (error) {
        debugPrint('Chat tip profile load failed: $error');
        if (!_isCurrent(ticket, request)) return;
        _showError('chat_memory_load_failed');
      }
      final smartPrompt =
          'KONTEXT: Das Kind des Elternteils ist $childAge Jahre alt.\n\n'
          'Der Elternteil hat diesen Tipp gelesen und will MEHR dazu wissen:\n'
          '"$tipText"\n\n'
          'Antworte SPEZIFISCH für ein $childAge-jähriges Kind:\n'
          '1. Warum ist das bei $childAge-Jährigen besonders relevant? (2 Sätze)\n'
          '2. 3 konkrete Alltagsbeispiele/Situationen\n'
          '3. 1 Übung die der Elternteil HEUTE ausprobieren kann\n\n'
          'Kurz, praktisch, kein Theorievortrag. Max 12 Zeilen.';

      if (!_isCurrent(ticket, request)) return;
      setState(() {
        _messages.add({
          'role': 'user',
          'content': context.tr('chat_tip_message', values: {'tip': tipText}),
          'timestamp': DateTime.now(),
        });
      });
      await _consumeReply(smartPrompt, ticket, request);
    } catch (error) {
      _handleRequestError(error, ticket, request);
    } finally {
      if (_isCurrent(ticket, request)) {
        setState(() {
          _isStreaming = false;
          _currentResponse = '';
        });
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming || _chatBackend == null) {
      return;
    }
    final ticket = _ticket;
    final request = ++_requestGeneration;
    setState(() => _isStreaming = true);
    try {
      if (!await _canSendWithConsent() || !_isCurrent(ticket, request)) return;
      await AIRateLimiter.initialize();
      if (!_isCurrent(ticket, request)) return;
      if (!AIRateLimiter.canMakeRequest()) {
        setState(
          () => _messages.add({
            'role': 'assistant',
            'content': AIRateLimiter.limitReachedMessage,
            'timestamp': DateTime.now(),
          }),
        );
        return;
      }
      if (_topicsLoading || _topicsErrorKey != null) {
        _showError('chat_topics_load_failed');
        return;
      }
      try {
        await _trackTopic(text, ticket);
      } catch (error) {
        debugPrint('Chat topic write failed: $error');
        if (_isCurrent(ticket, request)) _showError('chat_topics_save_failed');
        return;
      }
      if (!_isCurrent(ticket, request)) return;
      setState(() {
        _messages.add({
          'role': 'user',
          'content': text,
          'timestamp': DateTime.now(),
        });
        _currentResponse = '';
        _controller.clear();
      });
      await _consumeReply(text, ticket, request);
      if (_isCurrent(ticket, request)) await AIRateLimiter.recordRequest();
    } catch (error) {
      _handleRequestError(error, ticket, request);
    } finally {
      if (_isCurrent(ticket, request)) {
        setState(() {
          _isStreaming = false;
          _currentResponse = '';
        });
      }
    }
    _scrollToBottom();
  }

  Future<void> _consumeReply(
    String text,
    ChatAccountTicket ticket,
    int request,
  ) async {
    void guard() {
      _store.require(ticket);
      if (!_isCurrent(ticket, request)) throw const ChatAccountChanged();
    }

    guard();
    final iterator = StreamIterator(
      _chatBackend!.streamReply(
        history: _messages
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(),
        userMessage: text,
        languageCode: languageService.currentLanguage,
        countryCode: _countryCode,
        childProfileId: _activeChildProfileId,
        expectedScope: _consentScope,
        requireCurrentRequest: guard,
      ),
    );
    _replyIterator = iterator;
    try {
      while (await iterator.moveNext()) {
        guard();
        setState(() => _currentResponse += iterator.current);
        _scrollToBottom();
      }
      guard();
      setState(() {
        if (_currentResponse.isNotEmpty) {
          _messages.add({
            'role': 'assistant',
            'content': _currentResponse,
            'timestamp': DateTime.now(),
          });
        }
        _currentResponse = '';
      });
    } finally {
      if (identical(_replyIterator, iterator)) _replyIterator = null;
      unawaited(_cancelIterator(iterator));
    }
  }

  void _handleRequestError(
    Object error,
    ChatAccountTicket ticket,
    int request,
  ) {
    debugPrint('Chat request failed: $error');
    if (!_isCurrent(ticket, request)) return;
    if (error is AccountAiConsentRequiredException) {
      setState(() {
        _termsAccepted = false;
        _termsErrorKey = 'chat_consent_load_failed';
      });
    } else {
      _showError('chat_request_failed');
    }
  }

  void _scrollToBottom() {
    final ticket = _ticket;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isCurrent(ticket) && _scrollController.hasClients) {
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
    _invalidateReply();
    setState(() {
      _messages.clear();
      _assistantFeedbackByIndex.clear();
      _currentResponse = '';
      _isStreaming = false;
    });
  }

  Future<void> _confirmClearChat() async {
    final ticket = _ticket;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ChatAccountModal(
        store: _store,
        ticket: ticket,
        builder: (context) => AlertDialog(
          title: Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'delete_history_title',
            ),
          ),
          content: Text(context.tr('chat_delete_history_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'cancel',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'delete',
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && _isCurrent(ticket)) {
      _clearChat();
    }
  }

  void _setFeedback(int messageIndex, String value) {
    setState(() {
      _assistantFeedbackByIndex[messageIndex] = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'chat_feedback_saved',
            values: {'feedback': context.tr('chat_feedback_$value')},
          ),
        ),
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
          content: Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'chat_retry_missing_question',
            ),
          ),
        ),
      );
      return;
    }
    await _sendMessage(previousQuestion);
  }

  void _showTopicInsights() {
    final ticket = _ticket;
    final sorted = _topicCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ChatAccountModal(
        store: _store,
        ticket: ticket,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('chat_topic_analysis_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('chat_topic_analysis_privacy'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (sorted.isEmpty)
                  Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'no_questions_yet',
                    ),
                  )
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
                      try {
                        final counts = await _store.reset(ticket);
                        if (!_isCurrent(ticket)) return;
                        setState(
                          () => _topicCounts
                            ..clear()
                            ..addAll(counts),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (error) {
                        debugPrint('Chat topic reset failed: $error');
                        if (_isCurrent(ticket)) {
                          _showError('chat_topics_save_failed');
                        }
                      }
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(
                      AppStringsManager.getString(
                        languageService.currentLanguage,
                        'reset_counter',
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    final ticket = _ticket;
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
        onSelected: (_) {
          if (_isCurrent(ticket)) _setFeedback(index, feedbackId);
        },
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
              onPressed: _isStreaming
                  ? null
                  : () {
                      if (_isCurrent(ticket)) _retryAssistantFailure(index);
                    },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'try_again',
                ),
              ),
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
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
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
          ...topics.map(
            (t) => _buildTopicCard(t['emoji']!, t['label']!, t['q']!),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(String emoji, String label, String question) {
    final ticket = _ticket;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (_isCurrent(ticket)) _handleSuggestion(question);
          },
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
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: _kBrand.withValues(alpha: 0.5),
                ),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 17,
                color: Colors.white,
              ),
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
                    color: (isUser ? _kBrand : Colors.black).withValues(
                      alpha: isUser ? 0.20 : 0.05,
                    ),
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
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.55,
              color: _kBrand2,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              height: 1.55,
              color: _kInk,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
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
                  gradient: const LinearGradient(colors: [_kBrand, _kBrand2]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _kBrand.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 36,
                ),
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
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
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
              if (_termsErrorKey != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.tr(_termsErrorKey!),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              // Akzeptieren Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _termsSaving ? null : _acceptTerms,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.tr('chat_terms_accept'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
    ThemeData theme,
    String emoji,
    String title,
    String description,
  ) {
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
    final ticket = _ticket;
    if (_termsLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Nutzungsbedingungen beim ersten Mal zeigen
    if (!_termsLoading && !_termsAccepted) {
      return _buildTermsScreen(context);
    }

    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'ki_parenting_title',
            ),
          ),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  label: Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'try_again',
                    ),
                  ),
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
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Colors.white,
              ),
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
                Row(
                  children: [
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
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('tooltip_ai_memory'),
            onPressed: () async {
              final ticket = _ticket;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AiMemorySettingsScreen(service: _memoryService),
                ),
              );
              // Nach dem Verwalten das aktive Kind neu bestimmen (Gedächtnis
              // könnte gerade aktiviert oder ein Kind angelegt worden sein).
              if (_isCurrent(ticket)) await _loadActiveChildProfile();
            },
            icon: const Icon(Icons.psychology_outlined, color: _kBrand),
          ),
          IconButton(
            tooltip: context.tr('tooltip_topic_analysis'),
            onPressed: _showTopicInsights,
            icon: const Icon(Icons.insights_rounded, color: _kBrand),
          ),
          IconButton(
            tooltip: context.tr('tooltip_delete_chat'),
            onPressed: _messages.isEmpty ? null : _confirmClearChat,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: _messages.isEmpty ? Colors.grey[400] : _kBrand,
            ),
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
            if (_topicsErrorKey != null)
              ListTile(
                title: Text(context.tr(_topicsErrorKey!)),
                trailing: IconButton(
                  tooltip: context.tr('retry'),
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTopicInsights,
                ),
              ),
            if (_hasLegacy)
              ListTile(
                title: Text(context.tr('chat_legacy_title')),
                subtitle: Text(context.tr('chat_legacy_body')),
                trailing: TextButton(
                  onPressed: _ticket.scope == 'guest' ? null : _claimLegacy,
                  child: Text(context.tr('chat_claim_action')),
                ),
              ),
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
                          'chat_message_hint',
                        ),
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
                          borderSide: const BorderSide(
                            color: _kBrand,
                            width: 1.5,
                          ),
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
                      onSubmitted: (value) {
                        if (_isCurrent(ticket)) _sendMessage(value);
                      },
                      onChanged: (_) {
                        if (_isCurrent(ticket)) setState(() {});
                      },
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _kBrand,
                                ),
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
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 17,
            color: Colors.white,
          ),
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
                          color: _kBrand.withValues(
                            alpha: scale.clamp(0.4, 1.0),
                          ),
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
