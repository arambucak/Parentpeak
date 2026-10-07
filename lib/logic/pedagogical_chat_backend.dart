import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/chat_provider_exception.dart';
import 'package:parentpeak/logic/chat_prompt_policy.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_memory_consent.dart';
import 'package:parentpeak/logic/privacy_sanitizer.dart';
import 'package:parentpeak/logic/chat_context_policy.dart';
import 'package:parentpeak/logic/crisis_support.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';

class PedagogicalChatBackend {
  PedagogicalChatBackend({
    GeminiAIService? geminiService,
    ChatAiConsent? consent,
    ChatAccountStore? accountStore,
  }) : _geminiService = geminiService,
       consent = consent ?? ChatAiConsent.instance,
       accountStore = accountStore ?? ChatAccountStore.instance;

  final GeminiAIService? _geminiService;
  final ChatAiConsent consent;
  final ChatAccountStore accountStore;

  static const List<String> _violentKeywords = [
    'schlagen',
    'hauen',
    'verletzen',
    'bestrafen',
    'demutigen',
    'toten',
    'umbringen',
    'suizid',
    'selbstmord',
    'missbrauch',
  ];

  static const List<String> _harmfulIntentKeywords = [
    'wie schlage ich',
    'wie haue ich',
    'wie bestrafe ich',
    'wie kann ich meinem kind wehtun',
    'ich will meinem kind wehtun',
    'ich will meinem kind etwas antun',
    'ich will meinem kind schaden',
    'ich will es verletzen',
    'ich will ihn verletzen',
    'ich will sie verletzen',
    'ich will schlagen',
    'anleitung fuer',
    'anleitung für',
    'tipps zum schlagen',
  ];

  static const List<String> _helpSeekingViolenceContextKeywords = [
    'gewaltfrei',
    'ohne gewalt',
    'deeskalation',
    'konflikt loesen',
    'konflikt lösen',
    'mein kind schlaegt',
    'mein kind schlägt',
    'meine kinder schlagen sich',
    'geschwisterkonflikt',
    'ich will nicht schlagen',
    'ich möchte nicht schreien',
    'ich möchte nicht schreien',
    'wie beruhige ich',
    'wie begleite ich',
  ];

  static const List<String> _nonViolentContextKeywords = [
    'gewaltfrei',
    'gewaltfreie',
    'gewaltfreien',
    'ohne gewalt',
    'gegen gewalt',
    'deeskalation',
  ];

  static const List<String> _acuteSafetyKeywords = [
    'suizid',
    'selbstmord',
    'ich will sterben',
    'ich will verschwinden',
    'ich koennte meinem kind etwas antun',
    'ich könnte meinem kind etwas antun',
    'ich will meinem kind etwas antun',
    'ich habe angst die kontrolle zu verlieren',
    'mein partner schlaegt das kind',
    'mein partner schlägt das kind',
    'notfall',
    'akute gefahr',
    'bedroht',
    'haufige gewalt',
    'häufige gewalt',
    'kindeswohlgefaehrdung',
    'kindeswohlgefährdung',
    'selbstverletzung',
    'fremdgefaehrdung',
    'fremdgefährdung',
  ];

  static const List<String> _emotionalOverloadKeywords = [
    'ich kann nicht mehr',
    'ich halte es nicht mehr aus',
    'ich bin ueberfordert',
    'ich bin überfordert',
    'ich bin erschoepft',
    'ich bin erschöpft',
    'ich bin am ende',
    'ich fuehle mich leer',
    'ich fühle mich leer',
  ];

  static const List<String> _diagnosisIntentKeywords = [
    'diagnose',
    'hat mein kind',
    'ist das adhs',
    'ist es adhs',
    'hat er adhs',
    'hat sie adhs',
    'hat mein kind autismus',
    'ist mein kind autistisch',
    'hat mein kind depression',
    'diagnosis',
    'does my child have',
    'is my child autistic',
    'çocuğum otistik mi',
    'teşhis',
    'teşxîs',
  ];

  static const List<String> _medicalTreatmentIntentKeywords = [
    'medikament',
    'dosis',
    'tablette',
    'rezept',
    'antibiotika',
    'therapieplan',
    'wie viel',
    'wie oft geben',
    'einnahme',
    'medication',
    'dosage',
    'medicine',
    'antibiotic',
    'ilaç',
    'reçete',
    'derman',
    'antîbiyotîk',
  ];

  static const List<String> _offTopicKeywords = [
    'bitcoin',
    'aktien',
    'programmieren',
    'flutter code',
    'hacking',
    'wahlen',
    'politik',
    'steuertrick',
  ];

  static const Map<String, List<String>> _topicModeKeywords = {
    'Trotz und Wut': [
      'trotz',
      'wutanfall',
      'ausrasten',
      'schreit',
      'schreien',
      'nein',
    ],
    'Geschwisterkonflikt': [
      'geschwister',
      'streit',
      'konflikt',
      'hauen',
      'beißen',
      'beissen',
    ],
    'Schlaf': ['schlaf', 'einschlafen', 'durchschlafen', 'nacht'],
    'Medien': ['medien', 'handy', 'tablet', 'youtube', 'bildschirm'],
    'Kita und Schule': ['kita', 'schule', 'lehrer', 'lehrerin', 'hausaufgaben'],
    'Lernen und Selbststaendigkeit': [
      'selbststaendig',
      'selbststandig',
      'selber machen',
      'allein anziehen',
      'aufraeumen',
      'aufraumen',
      'helfen im haushalt',
      'ueben',
      'uben',
      'lernen',
      'konzentration',
    ],
    'Spielen und Kreativitaet': [
      'spielen',
      'spiel',
      'malen',
      'basteln',
      'kreativ',
      'langeweile',
      'fantasie',
      'draussen spielen',
      'rollenspiel',
    ],
  };

  Stream<String> streamReply({
    required List<Map<String, dynamic>> history,
    required String userMessage,
    String languageCode = 'de',
    String? countryCode,
    String? childProfileId,
    String? expectedScope,
    void Function()? requireCurrentRequest,
  }) async* {
    final scope = expectedScope ?? consent.scope;
    final ticket = accountStore.ticket;
    final memoryConsent =
        _geminiService?.memoryConsent ?? ChatMemoryConsent.instance;
    final memoryOwner = memoryConsent.scope;
    final usingMemory =
        childProfileId != null && await memoryConsent.hasConsent();
    final memoryRevision = memoryConsent.revision(memoryOwner);
    void guard() {
      accountStore.require(ticket);
      consent.requireScope(scope);
      if (usingMemory) {
        memoryConsent.requireRevision(memoryOwner, memoryRevision);
      }
      requireCurrentRequest?.call();
    }

    final message = userMessage.trim();
    if (message.isEmpty) {
      return;
    }

    final lower = message.toLowerCase();

    // SICHERHEIT ZUERST: Krise/Überlastung mehrsprachig erkennen (DE/EN/TR/KU)
    // und mit lokalisierter, länderabhängiger Hilfe antworten — VOR jedem
    // KI-Call. Die alten deutschen Keyword-Listen bleiben als zusätzliche
    // Absicherung erhalten.
    if (CrisisSupport.isAcuteCrisis(message) ||
        _containsAny(lower, _acuteSafetyKeywords)) {
      yield CrisisSupport.crisisResponse(
        languageCode: languageCode,
        countryCode: countryCode,
      );
      return;
    }

    if (CrisisSupport.isEmotionalOverload(message) ||
        _containsAny(lower, _emotionalOverloadKeywords)) {
      yield CrisisSupport.emotionalSupportResponse(languageCode: languageCode);
      return;
    }

    if (_containsAny(lower, _diagnosisIntentKeywords)) {
      yield ChatPromptPolicy.text(languageCode, 'chat_boundary_diagnosis');
      return;
    }

    if (_containsAny(lower, _medicalTreatmentIntentKeywords)) {
      yield ChatPromptPolicy.medical(languageCode, countryCode);
      return;
    }

    if (_shouldBlockViolenceIntent(lower)) {
      yield ChatPromptPolicy.text(languageCode, 'chat_boundary_violence');
      return;
    }

    if (_containsAny(lower, _offTopicKeywords)) {
      yield ChatPromptPolicy.text(languageCode, 'chat_boundary_topic');
      return;
    }

    if (_geminiService == null) {
      yield _providerUnavailableResponse(languageCode);
      return;
    }

    final inputHistory = _prepareHistory(history);
    if (inputHistory.isNotEmpty &&
        inputHistory.last['role'] == 'user' &&
        inputHistory.last['content'] == message) {
      inputHistory.removeLast();
    }
    final safeConversation = PrivacySanitizer.sanitizeHistoryForAi([
      ...inputHistory,
      {'role': 'user', 'content': message},
    ]);
    final safeMessage = safeConversation.last['content']!;
    final preparedHistory = ChatContextPolicy.limitHistory(
      safeConversation.sublist(0, safeConversation.length - 1),
    );
    final topicMode = _classifyTopicMode(lower);
    final contextAnchors = _extractContextAnchors(safeMessage);
    final historyAnchors = _extractHistoryAnchors(preparedHistory);
    final needsFollowUpQuestion = _shouldAskSingleFollowUpQuestion(message);
    final coachingPrompt = ChatPromptPolicy.coaching(
      language: languageCode,
      message: safeMessage,
      topic: topicMode,
      needsFollowUp: needsFollowUpQuestion,
      context: contextAnchors,
      history: historyAnchors,
    );
    preparedHistory.add({'role': 'user', 'content': coachingPrompt});

    try {
      var response = await _chatWithConsent(
        preparedHistory,
        scope,
        guard,
        childProfileId: childProfileId,
        languageCode: languageCode,
      );

      if (_looksLikeDefensiveBoundaryResponse(response)) {
        final retryHistory = List<Map<String, String>>.from(preparedHistory)
          ..add({'role': 'assistant', 'content': response})
          ..add({
            'role': 'user',
            'content': ChatPromptPolicy.text(languageCode, 'chat_boundary_retry'),
          });
        final retryResponse = await _chatWithConsent(
          retryHistory,
          scope,
          guard,
          childProfileId: childProfileId,
          languageCode: languageCode,
        );
        if (retryResponse.trim().isNotEmpty) {
          response = retryResponse;
        }
      }

      if (languageCode == 'de' && !_preservesCriticalContext(response, contextAnchors)) {
        final retryHistory = List<Map<String, String>>.from(preparedHistory)
          ..add({'role': 'assistant', 'content': response})
          ..add({
            'role': 'user',
            'content': ChatPromptPolicy.text(languageCode, 'chat_context_retry', {'context': contextAnchors.join(', ')}),
          });
        final retryResponse = await _chatWithConsent(
          retryHistory,
          scope,
          guard,
          childProfileId: childProfileId,
          languageCode: languageCode,
        );
        if (retryResponse.trim().isNotEmpty) {
          response = retryResponse;
        }
      }

      if (_needsQualityRetry(response, languageCode, needsFollowUpQuestion)) {
        final retryHistory = List<Map<String, String>>.from(preparedHistory)
          ..add({'role': 'assistant', 'content': response})
          ..add({
            'role': 'user',
            'content': ChatPromptPolicy.quality(languageCode, topicMode, needsFollowUpQuestion),
          });
        final retryResponse = await _chatWithConsent(
          retryHistory,
          scope,
          guard,
          childProfileId: childProfileId,
          languageCode: languageCode,
        );
        if (retryResponse.trim().isNotEmpty) {
          response = retryResponse;
        }
      }

      if (_containsAny(response.toLowerCase(), _diagnosisIntentKeywords)) {
        yield ChatPromptPolicy.text(languageCode, 'chat_boundary_diagnosis');
        return;
      }
      if (_containsAny(
        response.toLowerCase(),
        _medicalTreatmentIntentKeywords,
      )) {
        yield ChatPromptPolicy.medical(languageCode, countryCode);
        return;
      }
      if (_shouldBlockViolenceIntent(response.toLowerCase())) {
        yield ChatPromptPolicy.text(languageCode, 'chat_boundary_violence');
        return;
      }

      if (_violatesCorePedagogicalValues(response.toLowerCase())) {
        final repaired = await _repairToPedagogicalResponse(
          preparedHistory: preparedHistory,
          originalResponse: response,
          topicMode: topicMode,
          childProfileId: childProfileId,
          expectedScope: scope,
          requestGuard: guard,
          languageCode: languageCode,
        );

        if (_violatesCorePedagogicalValues(repaired.toLowerCase())) {
          yield ChatPromptPolicy.fallback(topicMode, languageCode);
          return;
        }

        if (_looksLikeDefensiveBoundaryResponse(repaired)) {
          yield ChatPromptPolicy.fallback(topicMode, languageCode);
          return;
        }

        yield repaired;
        return;
      }

      yield response;
    } on ChatProviderException catch (error) {
      yield _providerUnavailableResponse(languageCode, issue: error.issue);
    }
  }

  Future<String> _chatWithConsent(
    List<Map<String, String>> history,
    String expectedScope,
    void Function() guard, {
    String? childProfileId,
    required String languageCode,
  }) async {
    await consent.require(expectedScope);
    guard();
    final String response;
    try {
      response = await _geminiService!.chatWithHistory(
        [
          ...ChatContextPolicy.limitHistory(
            history.sublist(0, history.length - 1),
          ),
          history.last,
        ],
        childProfileId: childProfileId,
        requestGuard: guard,
        languageCode: languageCode,
      );
    } on ChatProviderException {
      guard();
      await consent.require(expectedScope);
      guard();
      rethrow;
    }
    guard();
    await consent.require(expectedScope);
    guard();
    return response;
  }

  String _classifyTopicMode(String lowerInput) {
    for (final entry in _topicModeKeywords.entries) {
      if (_containsAny(lowerInput, entry.value)) {
        return entry.key;
      }
    }
    return 'Allgemeine Elternfrage';
  }

  bool _shouldAskSingleFollowUpQuestion(String message) {
    final compact = message.trim();
    if (compact.length < 24) {
      return true;
    }

    final lower = compact.toLowerCase();
    final hasAge =
        RegExp(
          r'\b\d{1,2}(?:\s+(?:vollendete|completed))?\s*(?:jahre?|monate?|years?|months?|yaş(?:ını)?|sal(?:ên)?|meh)(?![\p{L}\p{N}])',
          unicode: true,
        ).hasMatch(lower) ||
        lower.contains('kindergartenalter') ||
        lower.contains('grundschule');
    final hasTriggerContext =
        lower.contains('weil') ||
        lower.contains('wenn') ||
        lower.contains('situation') ||
        lower.contains('passiert') ||
        lower.contains('because') ||
        lower.contains('when') ||
        lower.contains('happens') ||
        lower.contains('çünkü') ||
        lower.contains('olduğunda') ||
        lower.contains('dema') ||
        lower.contains('rewş');

    return !hasAge || !hasTriggerContext;
  }

  List<String> _extractHistoryAnchors(List<Map<String, String>> history) {
    if (history.isEmpty) {
      return const [];
    }

    final anchors = <String>[];
    final recent = history.reversed.take(16).toList();
    final userTexts = recent
        .where((entry) => entry['role'] == 'user')
        .map((entry) => entry['content'] ?? '')
        .where((text) => text.trim().isNotEmpty)
        .toList();

    final joinedOriginal = userTexts.join(' \n ');
    final joinedLower = joinedOriginal.toLowerCase();

    final ageMatches = RegExp(r'\b\d{1,2}\s*(jahre?|jahr|monate?|monat)\b')
        .allMatches(joinedLower)
        .map((m) => m.group(0))
        .whereType<String>()
        .toList();
    if (ageMatches.isNotEmpty) {
      anchors.add(ageMatches.last);
    }

    const carryOverPatterns = [
      'einschlafen',
      'durchschlafen',
      'wutanfall',
      'autonomiephase',
      'geschwister',
      'kita',
      'schule',
      'grenze',
      'morgenroutine',
      'abendroutine',
    ];
    for (final pattern in carryOverPatterns) {
      if (joinedLower.contains(pattern)) {
        anchors.add(pattern);
      }
    }

    return anchors.toSet().take(5).toList();
  }

  List<String> _extractContextAnchors(String message) {
    final lower = message.toLowerCase();
    final anchors = <String>[];

    final ageMatch = RegExp(
      r'\b\d{1,2}\s*(jahre?|jahr|monate?|monat)\b',
    ).firstMatch(lower);
    if (ageMatch != null) {
      anchors.add(ageMatch.group(0)!);
    }

    const relationPatterns = [
      'mein kind',
      'mein sohn',
      'meine tochter',
      'unser kind',
    ];
    for (final pattern in relationPatterns) {
      if (lower.contains(pattern)) {
        anchors.add(pattern);
        break;
      }
    }

    const situationPatterns = [
      'abends',
      'nachts',
      'morgens',
      'einschlafen',
      'durchschlafen',
      'wutanfall',
      'konflikt',
      'streit',
      'kita',
      'schule',
    ];
    for (final pattern in situationPatterns) {
      if (lower.contains(pattern)) {
        anchors.add(pattern);
      }
    }

    return anchors.toSet().take(4).toList();
  }

  bool _preservesCriticalContext(String response, List<String> anchors) {
    if (anchors.isEmpty) {
      return true;
    }
    final lower = response.toLowerCase();
    var matches = 0;
    for (final anchor in anchors) {
      if (lower.contains(anchor.toLowerCase())) {
        matches++;
      }
    }
    final minMatches = anchors.length >= 3 ? 2 : 1;
    return matches >= minMatches;
  }

  bool _needsQualityRetry(String response, String language, bool needsFollowUp) {
    final lower = response.toLowerCase();
    if (response.trim().length < 140) {
      return true;
    }
    if (response.trim().length > 1400) {
      return true;
    }
    const genericMarkers = [
      'als ki',
      'ich kann dir leider nur',
      'es kommt darauf an',
      'das ist individuell',
      'ich bleibe bei gewaltfreier',
      'ich gebe daher keine ratschlaege',
      'ich gebe daher keine ratschläge',
      'keine ratschlaege zu',
      'keine ratschläge zu',
      'as an ai',
      'it depends',
      'bir yapay zekâ olarak',
      'wekî ai',
    ];
    final hasGeneric = _containsAny(lower, genericMarkers);
    final empathyMarkers = {
      'de': ['kann es sein', 'ich hoere heraus', 'ich höre heraus', 'das klingt'],
      'en': ['that sounds', 'it sounds', 'i hear', 'it may', 'it can feel'],
      'tr': ['görünüyor', 'duyuyorum', 'anlıyorum', 'olabilir', 'zor'],
      'ku': ['xuya', 'dijwar', 'dibe ku', 'fêm', 'dibihîzim'],
    };
    final hasEmpathySignal = _containsAny(lower, empathyMarkers[language] ?? empathyMarkers['en']!);
    final questionCount = RegExp(r'\?').allMatches(response).length;
    final tooManyQuestions = questionCount > (needsFollowUp ? 1 : 0);
    final paragraphs = response
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final hasOverlongParagraph = paragraphs.any((p) {
      final sentenceCount = RegExp(r'[.!?]+').allMatches(p).length;
      return sentenceCount > 4;
    });
    return hasGeneric ||
        !hasEmpathySignal ||
        tooManyQuestions ||
        hasOverlongParagraph;
  }

  bool _looksLikeDefensiveBoundaryResponse(String input) {
    final lower = input.toLowerCase();
    const markers = [
      'ich bleibe bei gewaltfreier',
      'ich gebe daher keine ratschlaege',
      'ich gebe daher keine ratschläge',
      'keine ratschlaege zu beschaemung',
      'keine ratschläge zu beschämung',
      'wenn du magst, formuliere ich dir stattdessen',
    ];
    return _containsAny(lower, markers);
  }

  bool _containsAny(String input, List<String> keywords) {
    for (final keyword in keywords) {
      if (input.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldBlockViolenceIntent(String input) {
    final hasViolenceTerms = _containsAny(input, _violentKeywords);
    if (!hasViolenceTerms) return false;

    final hasSafeContext =
        _containsAny(input, _nonViolentContextKeywords) ||
        _containsAny(input, _helpSeekingViolenceContextKeywords);
    if (hasSafeContext) return false;

    return _containsAny(input, _harmfulIntentKeywords);
  }

  bool _violatesCorePedagogicalValues(String responseLower) {
    const hardHarmfulPatterns = [
      'schrei dein kind an',
      'schrei ihn an',
      'schrei sie an',
      'droh ihm',
      'droh ihr',
      'mach ihm angst',
      'mach ihr angst',
      'bestrafe dein kind',
      'ignoriere dein kind',
      'demuetige',
      'demütige',
      'bloßstell',
      'blo\u00dfstell',
    ];
    return _containsAny(responseLower, hardHarmfulPatterns);
  }

  Future<String> _repairToPedagogicalResponse({
    required List<Map<String, String>> preparedHistory,
    required String originalResponse,
    required String topicMode,
    required String expectedScope,
    required void Function() requestGuard,
    required String languageCode,
    String? childProfileId,
  }) async {
    final retryHistory = List<Map<String, String>>.from(preparedHistory)
      ..add({'role': 'assistant', 'content': originalResponse})
      ..add({
        'role': 'user',
        'content': ChatPromptPolicy.text(languageCode, 'chat_repair_prompt', {
          'focus': ChatPromptPolicy.focus(topicMode, languageCode),
        }),
      });

    return _chatWithConsent(
      retryHistory,
      expectedScope,
      requestGuard,
      childProfileId: childProfileId,
      languageCode: languageCode,
    );
  }

  List<Map<String, String>> _prepareHistory(
    List<Map<String, dynamic>> history,
  ) {
    final prepared = <Map<String, String>>[];
    for (final item in history) {
      final role = item['role']?.toString();
      final content = item['content']?.toString();
      if (role == null || content == null || content.trim().isEmpty) {
        continue;
      }
      if (role != 'user' && role != 'assistant') {
        continue;
      }
      prepared.add({
        'role': role == 'assistant' ? 'assistant' : 'user',
        'content': content.trim(),
      });
    }
    return prepared;
  }

  // Hinweis: Krisen- und Überlastungs-Antworten sind in CrisisSupport
  // ausgelagert (mehrsprachig + länderabhängige Notrufnummern).

  String _providerUnavailableResponse(
    String languageCode, {
    ChatProviderIssue? issue,
  }) {
    final base = AppStringsManager.getString(
      languageCode,
      'chat_provider_unavailable',
    );
    if (issue == null) return base;
    final key = issue == ChatProviderIssue.unavailable
        ? 'chat_provider_unavailable_reason'
        : 'chat_provider_${issue.name}';
    return '$base\n\n${AppStringsManager.getString(languageCode, key)}';
  }
}
