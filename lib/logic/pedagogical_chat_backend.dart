import 'package:flutter/foundation.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';

class PedagogicalChatBackend {
  PedagogicalChatBackend({GeminiAIService? geminiService})
      : _geminiService = geminiService;

  final GeminiAIService? _geminiService;

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
    'Schlaf': [
      'schlaf',
      'einschlafen',
      'durchschlafen',
      'nacht',
    ],
    'Medien': [
      'medien',
      'handy',
      'tablet',
      'youtube',
      'bildschirm',
    ],
    'Kita und Schule': [
      'kita',
      'schule',
      'lehrer',
      'lehrerin',
      'hausaufgaben',
    ],
  };

  Stream<String> streamReply({
    required List<Map<String, dynamic>> history,
    required String userMessage,
  }) async* {
    final message = userMessage.trim();
    if (message.isEmpty) {
      return;
    }

    final lower = message.toLowerCase();

    if (_containsAny(lower, _acuteSafetyKeywords)) {
      yield _crisisResponse();
      return;
    }

    if (_containsAny(lower, _emotionalOverloadKeywords)) {
      yield _emotionalSupportResponse(message);
      return;
    }

    if (_containsAny(lower, _diagnosisIntentKeywords)) {
      yield _diagnosisBoundaryResponse();
      return;
    }

    if (_containsAny(lower, _medicalTreatmentIntentKeywords)) {
      yield _medicalBoundaryResponse();
      return;
    }

    if (_shouldBlockViolenceIntent(lower)) {
      yield _violentBoundaryResponse();
      return;
    }

    if (_containsAny(lower, _offTopicKeywords)) {
      yield _offTopicResponse();
      return;
    }

    if (_geminiService == null) {
      yield _providerUnavailableResponse(
        rawError: 'Gemini service not initialized',
      );
      return;
    }

    final topicMode = _classifyTopicMode(lower);
    final contextAnchors = _extractContextAnchors(message);
    final preparedHistory = _prepareHistory(history);
    final historyAnchors = _extractHistoryAnchors(preparedHistory);
    final needsFollowUpQuestion = _shouldAskSingleFollowUpQuestion(message);
    final coachingPrompt = _buildCoachingPrompt(
      userMessage: message,
      topicMode: topicMode,
      needsFollowUpQuestion: needsFollowUpQuestion,
      contextAnchors: contextAnchors,
      historyAnchors: historyAnchors,
    );
    preparedHistory.add({'role': 'user', 'content': coachingPrompt});

    var response = await _geminiService!.chatWithHistory(preparedHistory);
    if (_looksLikeProviderError(response)) {
      yield _providerUnavailableResponse(rawError: response);
      return;
    }

    if (_looksLikeDefensiveBoundaryResponse(response)) {
      final retryHistory = List<Map<String, String>>.from(preparedHistory)
        ..add({'role': 'assistant', 'content': response})
        ..add({
          'role': 'user',
          'content': 'Bitte antworte nicht mit einer allgemeinen Grenzformel. '
              'Antworte stattdessen konkret, empathisch und loesungsorientiert für Eltern im Alltag.',
        });
      final retryResponse = await _geminiService!.chatWithHistory(retryHistory);
      if (!_looksLikeProviderError(retryResponse) &&
          retryResponse.trim().isNotEmpty) {
        response = retryResponse;
      }
    }

    if (!_preservesCriticalContext(response, contextAnchors)) {
      final retryHistory = List<Map<String, String>>.from(preparedHistory)
        ..add({'role': 'assistant', 'content': response})
        ..add({
          'role': 'user',
          'content': _contextRetentionRetryInstruction(contextAnchors),
        });
      final retryResponse = await _geminiService!.chatWithHistory(retryHistory);
      if (!_looksLikeProviderError(retryResponse) &&
          retryResponse.trim().isNotEmpty) {
        response = retryResponse;
      }
    }

    if (_needsQualityRetry(response)) {
      final retryHistory = List<Map<String, String>>.from(preparedHistory)
        ..add({'role': 'assistant', 'content': response})
        ..add({'role': 'user', 'content': _qualityRetryInstruction(topicMode)});
      final retryResponse = await _geminiService!.chatWithHistory(retryHistory);
      if (!_looksLikeProviderError(retryResponse) &&
          retryResponse.trim().isNotEmpty) {
        response = retryResponse;
      }
    }

    if (_containsAny(response.toLowerCase(), _diagnosisIntentKeywords)) {
      yield _diagnosisBoundaryResponse();
      return;
    }
    if (_containsAny(response.toLowerCase(), _medicalTreatmentIntentKeywords)) {
      yield _medicalBoundaryResponse();
      return;
    }
    if (_shouldBlockViolenceIntent(response.toLowerCase())) {
      yield _violentBoundaryResponse();
      return;
    }

    if (_violatesCorePedagogicalValues(response.toLowerCase())) {
      final repaired = await _repairToPedagogicalResponse(
        preparedHistory: preparedHistory,
        originalResponse: response,
        topicMode: topicMode,
      );

      if (_looksLikeProviderError(repaired)) {
        yield _providerUnavailableResponse(rawError: repaired);
        return;
      }

      if (_violatesCorePedagogicalValues(repaired.toLowerCase())) {
        yield _pedagogicalFallbackResponse(topicMode);
        return;
      }

      if (_looksLikeDefensiveBoundaryResponse(repaired)) {
        yield _pedagogicalFallbackResponse(topicMode);
        return;
      }

      yield repaired;
      return;
    }

    yield response;
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
    final hasAge = RegExp(r'\b\d{1,2}\b').hasMatch(lower) ||
        lower.contains('jahr') ||
        lower.contains('monate') ||
        lower.contains('kindergartenalter') ||
        lower.contains('grundschule');
    final hasTriggerContext = lower.contains('weil') ||
        lower.contains('wenn') ||
        lower.contains('situation') ||
        lower.contains('passiert');

    return !hasAge || !hasTriggerContext;
  }

  String _buildCoachingPrompt({
    required String userMessage,
    required String topicMode,
    required bool needsFollowUpQuestion,
    required List<String> contextAnchors,
    required List<String> historyAnchors,
  }) {
    final modeHint = _modeSpecificHint(topicMode);
    final followUpRule = needsFollowUpQuestion
        ? 'Stelle am Ende genau EINE kurze Rueckfrage, die den naechsten hilfreichen Schritt absichert.'
        : 'Stelle keine Rueckfrage, wenn die Lage für konkrete Schritte ausreicht.';
    final continuationRule = historyAnchors.isEmpty
        ? 'Wenn kein Verlaufskontext vorliegt, starte ohne Rueckblick und bleibe beim aktuellen Anliegen.'
        : 'Nutze den Verlauf aktiv und knüpfe natürlich an frühere Themen an (z. B. Name, Alter, Muster). Wenn es nach längerer Pause klingt, frage sanft nach dem aktuellen Stand.';

    return '''
Themenmodus: $topicMode

Nutzeranliegen:
$userMessage

  Du bist ein hochgradig empathischer, paedagogischer KI-Begleiter für Eltern nach GfK (Rosenberg), Hüther (Neurobiologie) und Juul (Familientherapie).
  Haltung: warm, wertfrei, entlastend, auf Augenhoehe.

HÜTHER-LINSE — wende sie bei jeder Antwort an:
- Frage dich zuerst: Ist das Verhalten des Kindes ein Ausdruck von unerfüllter VERBUNDENHEIT oder unerfüllter AUTONOMIE?
  → Verbundenheit: Kind braucht Nähe, Sicherheit, echte Zugehörigkeit
  → Autonomie: Kind will selbst entscheiden, entdecken, gestalten — das ist gesund
- Druck, Strafen, Belohnungen kurzfristig wirkungsvoll aber langfristig beziehungsschädigend → immer Beziehungsarbeit vorziehen
- Kinder lernen durch Nachahmung, nicht Belehrung → Eltern als Vorbild benennen
- Hindernisse nicht wegnehmen: Eltern ermutigen NEBEN dem Kind zu stehen statt alles zu lösen
- Begeisterung und emotionale Beteiligung sind die neurobiologische Grundbedingung für Lernen

Pflichtformat mit klaren Ueberschriften:
  1) Immer zuerst Empathie in 1-2 Saetzen.
     Gefühle/Bedürfnisse nur als Vermutung oder Frage formulieren, nie als absolute Behauptung.
  2) Hüther-Diagnose in einem Satz: Ist es ein Verbundenheits- oder Autonomie-Bedürfnis?
  3) Danach genau EIN GfK-Schritt im Fokus (Beobachtung ODER Gefühl ODER Bedürfnis ODER Bitte).
  4) Gib 1-2 kleine alltagstaugliche Optionen in Kann-Form, nicht in Muss-Form.
  5) Stelle genau EINE offene, behutsame Frage, passend zum gewählten GfK-Schritt.
  6) $followUpRule

Modus-Hinweis:
$modeHint

Wichtig:
- Kein Moralisieren.
- Keine leeren Floskeln.
- Kein abstrakter Theorieblock.
- Klar, waermend, handlungsfaehig.
- Kein Satz wie: "Ich bleibe bei ... ich gebe keine Ratschlaege ...".
- Schreibe so, dass Eltern sich verstanden, beruhigt und handlungsfaehig fühlen.
- Keine Formulierung mit "Du musst".
- Keine vorschnellen Erziehungsurteile.
  - Keine Sternchen, keine dekorativen Zeichen und kein Markdown (kein * oder **).
- Ruhiger, professioneller Sprachstil für Eltern.
  - Antwort kurz und verdaulich: keine Textwand, kurze Absaetze (max. 3-4 Saetze pro Absatz).
  - Emojis nur dezent und sparsam (0-2 pro Antwort).
- Uebernimm die wichtigsten Kontextinfos aus der Elternnachricht sichtbar in der Antwort.
- Wenn konkrete Details genannt wurden (z. B. Alter, Tageszeit, Situation), müssen sie in der Antwort auftauchen.
  - Wenn Eltern in "Wolfssprache" schreiben (Selbstvorwurf/Urteil), uebersetze empathisch in Gefühl und Bedürfnis statt zu belehren.
- Vermute Gefühle/Bedürfnisse immer als Frage oder vorsichtige Spiegelung, nie als Fakt.
- Empathie kommt immer vor Strategie.
- Ein GfK-Schritt pro Antwort, nicht alle vier gleichzeitig.
- Bullet Points sind erlaubt, wenn sie die Lesbarkeit auf dem Handy verbessern.
- $continuationRule

Kontextanker (nicht verlieren): ${contextAnchors.isEmpty ? 'keine' : contextAnchors.join(', ')}
Verlaufskontext (falls vorhanden): ${historyAnchors.isEmpty ? 'keiner' : historyAnchors.join(', ')}
''';
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

    final nameMatch = RegExp(
      r'(?:mein|unser)\s+(?:sohn|tochter|kind)\s+([A-ZÄÖÜ][a-zäöüß]{1,20})',
    ).firstMatch(joinedOriginal);
    if (nameMatch != null) {
      anchors.add(nameMatch.group(1)!);
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

    final ageMatch =
        RegExp(r'\b\d{1,2}\s*(jahre?|jahr|monate?|monat)\b').firstMatch(lower);
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

  String _contextRetentionRetryInstruction(List<String> anchors) {
    final anchorText = anchors.isEmpty ? 'keine' : anchors.join(', ');
    return 'Bitte antworte neu und verliere keine wichtigen Angaben der Eltern. '
        'Greife die genannten Kontextinfos sichtbar auf: $anchorText. '
        'Bleibe authentisch, empathisch und alltagsnah.';
  }

  String _modeSpecificHint(String topicMode) {
    switch (topicMode) {
      case 'Trotz und Wut':
        return 'Fokus auf Co-Regulation, klare Grenzen ohne Beschaemung und kurze Deeskalation im Moment.';
      case 'Geschwisterkonflikt':
        return 'Fokus auf Trennen ohne Strafe, Gefühle spiegeln, faire Wiederannaeherung und Wiedergutmachung.';
      case 'Schlaf':
        return 'Fokus auf realistische Entlastung, kleine Routinen und energiesparende Schritte für Eltern.';
      case 'Medien':
        return 'Fokus auf klare, vorab vereinbarte Grenzen plus kooperative Übergänge statt Machtkampf.';
      case 'Kita und Schule':
        return 'Fokus auf kindgerechte Begleitung, alltagsnahe Struktur und kooperative Kommunikation mit Fachkraeften.';
      default:
        return 'Fokus auf eine sofort umsetzbare, bindungsorientierte Entlastung für den Familienalltag.';
    }
  }

  bool _needsQualityRetry(String response) {
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
    ];
    final hasGeneric = _containsAny(lower, genericMarkers);
    final hasEmpathySignal = lower.contains('kann es sein') ||
        lower.contains('ich hoere heraus') ||
        lower.contains('das klingt');
    final questionCount = RegExp(r'\?').allMatches(response).length;
    final tooManyQuestions = questionCount > 2;
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

  String _qualityRetryInstruction(String topicMode) {
    return 'Bitte antworte jetzt deutlich konkreter und authentischer für den Modus "$topicMode": '
        '1) Empathie zuerst, 2) genau ein GfK-Schritt im Fokus, 3) 1-2 Optionen in Kann-Form, 4) genau eine offene Frage. '
        'Kurze mobile Lesbarkeit: max. 3-4 Saetze pro Absatz. '
        'Gefühle/Bedürfnisse als Vermutung formulieren. '
        'Keine Textwand, keine Grenzfloskeln, kein "Du musst".';
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

  bool _looksLikeProviderError(String input) {
    final lower = input.toLowerCase();
    const markers = [
      'fehler:',
      'not found for api version',
      'quota exceeded',
      'exceeded your current quota',
      'rate-limit',
      'rate limit',
      'resource has been exhausted',
      'generate_content_free_tier',
      'billing details',
      'api key',
      'permission_denied',
      'unauthenticated',
      'failed host lookup',
      'socketexception',
      'network is unreachable',
      'deadline exceeded',
      'timed out',
      '403',
      '401',
      '429',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldBlockViolenceIntent(String input) {
    final hasViolenceTerms = _containsAny(input, _violentKeywords);
    if (!hasViolenceTerms) return false;

    final hasSafeContext = _containsAny(input, _nonViolentContextKeywords) ||
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
  }) async {
    final retryHistory = List<Map<String, String>>.from(preparedHistory)
      ..add({'role': 'assistant', 'content': originalResponse})
      ..add({
        'role': 'user',
        'content':
            'Bitte formuliere die Antwort neu: rein gewaltfrei, bindungsorientiert und nach GfK. '
                'Kein Schimpfen, keine Drohung, keine Strafe. '
                'Gib stattdessen 3 konkrete alltagstaugliche Schritte plus 2 direkte Beispielsätze für Eltern. '
                'Themenmodus: $topicMode.',
      });

    return _geminiService!.chatWithHistory(retryHistory);
  }

  String _pedagogicalFallbackResponse(String topicMode) {
    switch (topicMode) {
      case 'Schlaf':
        return 'Das klingt sehr kraeftezehrend, besonders wenn es abends häufig eskaliert. '
            'Du koenntest heute drei kleine Dinge testen: '
            '1) 20 Minuten vor dem Schlafen Reize senken, '
            '2) eine klare Wahl anbieten (Buch oder Lied), '
            '3) eine ruhige Abschluss-Formulierung wiederholen. '
            'Moegliche Saetze: "Du willst noch wach bleiben, ich sehe das. Jetzt begleiten wir den Koerper in die Ruhe." '
            'und "Du darfst traurig sein, ich bleibe ruhig bei dir und halte die Grenze." '
            'Welche Szene ist bei euch am schwierigsten: der Übergang ins Bett oder das Liegenbleiben?';
      case 'Trotz und Wut':
        return 'Das ist eine intensive Situation, und deine Erschoepfung ist gut nachvollziehbar. '
            'Du koenntest jetzt zuerst Sicherheit herstellen, dann Gefühle spiegeln und erst danach eine Alternative anbieten. '
            'Moegliche Saetze: "Ich sehe deine Wut, ich lasse nicht zu, dass jemand verletzt wird." '
            'und "Du kannst stampfen oder ins Kissen druecken, ich bleibe bei dir." '
            'Was ist bei euch der häufigste Ausloeser direkt vor dem Wutanfall?';
      default:
        return 'Danke fürs Teilen - du bist damit nicht allein. '
            'Wir können gemeinsam eine gewaltfreie, paedagogisch passende Loesung erarbeiten. '
            'Wenn du magst, nenne Alter des Kindes, typische Situation und was du in dem Moment fuehlst. '
            'Dann formuliere ich mit dir die GFK-Schritte Beobachtung, Gefühl, Bedürfnis und Bitte konkret für euren Alltag.';
    }
  }

  List<Map<String, String>> _prepareHistory(
      List<Map<String, dynamic>> history) {
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

  String _offTopicResponse() {
    return 'Ich bin fur padagogische Elternberatung da. Wenn du magst, beschreibe deine Familien- oder Erziehungsfrage, dann unterstutze ich dich gern.';
  }

  String _violentBoundaryResponse() {
    return 'Ich kann keine gewaltfordernden oder verletzenden Anleitungen geben. '
        'Wenn du magst, helfe ich dir mit einem gewaltfreien Vorgehen nach Rosenberg: '
        '1) Beobachtung, 2) Gefuhl, 3) Bedurfnis, 4) konkrete Bitte.';
  }

  String _diagnosisBoundaryResponse() {
    return 'Ich kann keine Diagnose stellen oder bestaetigen, was ein Kind "hat". '
        'Ich kann dir aber paedagogische Orientierung geben, wie du dein Kind im Alltag stabil und bindungsorientiert begleiten kannst. '
        'Wenn du diagnostische Klaerung brauchst, wende dich bitte an Kinderarztpraxis oder Kinder- und Jugendpsychologie.';
  }

  String _medicalBoundaryResponse() {
    return 'Ich gebe keine medizinischen Empfehlungen oder Medikamentenhinweise. '
        'Bei gesundheitlichen Fragen nutze bitte aerztliche Beratung. '
        'Bei Unsicherheit ausserhalb der Sprechzeiten hilft in Deutschland der aerztliche Bereitschaftsdienst unter 116117.';
  }

  String _crisisResponse() {
    return 'Das klingt nach einer akuten Belastung. Du musst damit nicht allein bleiben. '
        'Dies ist eine KI-gestuetzte Orientierung und ersetzt keine professionelle Beratung. '
        'Bitte hole jetzt direkte menschliche Hilfe: '
        'Im Notfall 112, Telefonseelsorge 0800 111 0 111 oder 0800 111 0 222 (24/7), '
        'bei medizinischer Dringlichkeit 116117 und bei Kindeswohlgefaehrdung das zustaendige Jugendamt.';
  }

  String _emotionalSupportResponse(String message) {
    return 'Das klingt gerade richtig schwer. Du musst da nicht stark sein und du bist damit nicht allein. 🫶\n\n'
        'Wenn du magst, machen wir es ganz klein: einmal ausatmen, ein Glas Wasser, dann nur den naechsten schwierigen Moment anschauen.\n\n'
        'Was war direkt davor los - nur der Ablauf, ohne Bewertung?\n\n'
        'Hinweis: Ich bin eine unterstuetzende KI und kein Ersatz für therapeutische Beratung. Wenn du menschliche Hilfe möchtest, nenne ich dir gern passende Anlaufstellen.';
  }

  String _providerUnavailableResponse({String? rawError}) {
    final reason = _providerIssueReason(rawError);
    const base = 'Die KI-Beratung ist aktuell nicht verfügbar. '
        'Bitte versuche es gleich erneut.';

    final withReason =
        reason == null ? base : '$base\n\nMoeglicher Grund: $reason';

    if (kDebugMode && rawError != null && rawError.trim().isNotEmpty) {
      final compact = rawError.replaceAll(RegExp(r'\s+'), ' ').trim();
      final shortened =
          compact.length > 240 ? '${compact.substring(0, 240)}...' : compact;
      return '$withReason\n\nDebug: $shortened';
    }

    return withReason;
  }

  String? _providerIssueReason(String? rawError) {
    if (rawError == null || rawError.trim().isEmpty) {
      return null;
    }

    final lower = rawError.toLowerCase();

    if (lower.contains('api key') ||
        lower.contains('unauthenticated') ||
        lower.contains('401')) {
      return 'API-Schluessel ungueltig oder nicht autorisiert.';
    }

    if (lower.contains('quota exceeded') ||
        lower.contains('resource has been exhausted') ||
        lower.contains('429') ||
        lower.contains('rate limit')) {
      return 'Kontingent/Rate-Limit erreicht.';
    }

    if (lower.contains('permission_denied') || lower.contains('403')) {
      return 'Berechtigung für dieses Modell fehlt.';
    }

    if (lower.contains('not found for api version') ||
        lower.contains('model') && lower.contains('not found')) {
      return 'Konfiguriertes Modell ist nicht verfügbar.';
    }

    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return 'Netzwerkproblem oder Timeout.';
    }

    return 'Externer Dienst antwortet aktuell nicht stabil.';
  }
}
