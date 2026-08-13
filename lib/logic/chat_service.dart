import 'dart:async';
import 'dart:math';

/// KI-Pädagogik-Chat Service basierend auf Gewaltfreier Kommunikation (GfK)
/// nach Marshall Rosenberg
class ChatService {
  static const _gfkResponses = [
    // Empathische Begrüßungen
    'Hallo! Ich bin hier, um dich zu unterstützen. Was beschäftigt dich gerade?',
    'Schön, dass du da bist. Wie kann ich dir heute helfen?',
    
    // GfK-basierte Antworten für Gefühle und Bedürfnisse
    'Ich höre, dass du dich gerade {feeling} fühlst. Das ist völlig in Ordnung. Magst du mir mehr darüber erzählen?',
    'Es klingt, als ob dein Bedürfnis nach {need} gerade nicht erfüllt ist. Wie geht es dir damit?',
    'Danke, dass du das mit mir teilst. Deine Gefühle sind wichtig und berechtigt.',
    
    // Reflektierende Antworten
    'Wenn ich dich richtig verstehe, fühlst du dich {feeling}, weil dir {need} wichtig ist. Stimmt das?',
    'Es scheint, als würdest du dir {need} wünschen. Was würde dir in dieser Situation helfen?',
    
    // Lösungsorientierte Fragen
    'Was bräuchtest du, um dich in dieser Situation besser zu fühlen?',
    'Welche kleinen Schritte könnten dir jetzt helfen?',
    'Was hat dir in ähnlichen Situationen schon einmal geholfen?',
    
    // Validierung und Empowerment
    'Du machst einen wichtigen Schritt, indem du darüber sprichst.',
    'Es ist mutig, dass du deine Gefühle ausdrückst.',
    'Deine Bedürfnisse sind wichtig und verdienen Aufmerksamkeit.',
    
    // Pädagogische Perspektiven
    'In der Entwicklungspsychologie sehen wir, dass {insight}. Wie passt das zu deiner Erfahrung?',
    'Aus pädagogischer Sicht ist es wichtig zu verstehen, dass {perspective}.',
  ];

  static const _escalationKeywords = [
    'selbstmord',
    'suizid',
    'ich will sterben',
    'ich kann nicht mehr',
    'ich halte das nicht mehr aus',
    'ich koennte meinem kind etwas antun',
    'ich könnte meinem kind etwas antun',
    'ich möchte mein baby schuetteln',
    'ich möchte mein baby schütteln',
    'notfall',
    'akute gefahr',
    'kindeswohlgefaehrdung',
    'kindeswohlgefährdung',
    'selbstverletzung',
  ];

  static const _helpResources = {
    'de': {
      'crisis': [
        {
          'name': 'Telefonseelsorge',
          'phone': '0800 111 0 111 oder 0800 111 0 222',
          'available': '24/7 kostenlos',
          'description': 'Anonyme Beratung in Krisensituationen',
        },
        {
          'name': 'Nummer gegen Kummer (Kinder & Jugendliche)',
          'phone': '116 111',
          'available': 'Mo-Sa 14-20 Uhr',
          'description': 'Kostenlose Beratung für Kinder und Jugendliche',
        },
        {
          'name': 'Nummer gegen Kummer (Elterntelefon)',
          'phone': '0800 111 0 550',
          'available': 'Mo-Fr 9-17 Uhr, Di+Do bis 19 Uhr',
          'description': 'Beratung für Eltern',
        },
        {
          'name': 'Hilfetelefon Gewalt gegen Frauen',
          'phone': '08000 116 016',
          'available': '24/7 kostenlos',
          'description': 'Unterstützung bei häuslicher Gewalt',
        },
      ],
      'general': [
        {
          'name': 'Caritas Beratungsstellen',
          'description': 'Familienberatung, Erziehungsberatung',
          'contact': 'www.caritas.de',
        },
        {
          'name': 'Pro Familia',
          'description': 'Schwangerschaftsberatung, Sexualpädagogik',
          'contact': 'www.profamilia.de',
        },
        {
          'name': 'Jugendamt',
          'description': 'Erziehungshilfe, Familienunterstützung',
          'contact': 'Lokales Jugendamt kontaktieren',
        },
      ],
    },
  };

  final Random _random = Random();

  /// Sendet eine Nachricht und erhält eine KI-Antwort
  Future<String> sendMessage(String message) async {
    // Simuliere Verarbeitungszeit
    await Future.delayed(const Duration(milliseconds: 800));

    // Prüfe auf Eskalation
    if (_isEscalation(message)) {
      return _generateEscalationResponse();
    }

    // Extrahiere Gefühle und Bedürfnisse
    final feelings = _extractFeelings(message);
    final needs = _extractNeeds(message);

    // Generiere personalisierte GfK-basierte Antwort
    return _generateGfKResponse(message, feelings, needs);
  }

  /// Prüft, ob eine Nachricht Eskalations-Keywords enthält
  bool _isEscalation(String message) {
    final lowerMessage = message.toLowerCase();
    return _escalationKeywords
        .any((keyword) => lowerMessage.contains(keyword));
  }

  /// Generiert eine Eskalationsantwort mit Hilfsressourcen
  String _generateEscalationResponse() {
    final resources = _helpResources['de']!['crisis']!;
    final buffer = StringBuffer();
    
    buffer.writeln('Ich merke, dass du dich gerade in einer sehr schwierigen Situation befindest. Das tut mir leid.');
    buffer.writeln('\nEs ist wichtig, dass du dir jetzt professionelle Hilfe holst. Hier sind sofort erreichbare Anlaufstellen:\n');
    
    for (var resource in resources) {
      buffer.writeln('📞 ${resource['name']}');
      buffer.writeln('   ${resource['phone']}');
      buffer.writeln('   ${resource['available']}');
      buffer.writeln('   ${resource['description']}\n');
    }
    
    buffer.writeln('Bitte wende dich an eine dieser Stellen. Du bist nicht allein, und es gibt Menschen, die dir helfen können.');
    
    return buffer.toString();
  }

  /// Extrahiert Gefühle aus der Nachricht
  List<String> _extractFeelings(String message) {
    final feelings = <String>[];
    final lowerMessage = message.toLowerCase();
    
    final feelingKeywords = {
      'traurig': ['traurig', 'trauer', 'niedergeschlagen'],
      'wütend': ['wütend', 'wut', 'ärger', 'sauer', 'genervt'],
      'ängstlich': ['angst', 'ängstlich', 'sorge', 'befürchtung', 'unsicher'],
      'überfordert': ['überfordert', 'stress', 'gestresst', 'erschöpft'],
      'einsam': ['einsam', 'allein', 'isoliert'],
      'hilflos': ['hilflos', 'machtlos', 'ausgeliefert'],
      'frustriert': ['frustriert', 'enttäuscht', 'verzweifelt'],
    };
    
    for (var entry in feelingKeywords.entries) {
      if (entry.value.any((keyword) => lowerMessage.contains(keyword))) {
        feelings.add(entry.key);
      }
    }
    
    return feelings;
  }

  /// Extrahiert Bedürfnisse aus der Nachricht
  List<String> _extractNeeds(String message) {
    final needs = <String>[];
    final lowerMessage = message.toLowerCase();
    
    final needKeywords = {
      'Verständnis': ['verstehen', 'verständnis', 'zuhören'],
      'Sicherheit': ['sicher', 'geborgen', 'schutz'],
      'Ruhe': ['ruhe', 'pause', 'entspannung', 'erholung'],
      'Unterstützung': ['hilfe', 'unterstützung', 'begleitung'],
      'Autonomie': ['selbst', 'entscheidung', 'freiheit', 'kontrolle'],
      'Verbindung': ['verbindung', 'nähe', 'kontakt', 'gemeinschaft'],
      'Wertschätzung': ['wertschätzung', 'anerkennung', 'respekt'],
    };
    
    for (var entry in needKeywords.entries) {
      if (entry.value.any((keyword) => lowerMessage.contains(keyword))) {
        needs.add(entry.key);
      }
    }
    
    return needs;
  }

  /// Generiert eine personalisierte GfK-basierte Antwort
  String _generateGfKResponse(String message, List<String> feelings, List<String> needs) {
    // Wähle eine passende Antwort-Vorlage
    final templates = _gfkResponses.where((r) => r.contains('{')).toList();
    final simpleResponses = _gfkResponses.where((r) => !r.contains('{')).toList();
    
    String response;
    
    if (feelings.isNotEmpty || needs.isNotEmpty) {
      // Personalisierte Antwort mit erkannten Gefühlen/Bedürfnissen
      response = templates[_random.nextInt(templates.length)];
      
      if (feelings.isNotEmpty) {
        response = response.replaceAll('{feeling}', feelings.first);
      }
      if (needs.isNotEmpty) {
        response = response.replaceAll('{need}', needs.first);
      }
      
      // Entferne nicht ersetzte Platzhalter
      response = response.replaceAll(RegExp(r'\{[^}]+\}'), 'sicher und verstanden');
    } else {
      // Allgemeine empathische Antwort
      response = simpleResponses[_random.nextInt(simpleResponses.length)];
    }
    
    // Füge pädagogischen Kontext hinzu
    if (message.toLowerCase().contains('kind') || message.toLowerCase().contains('eltern')) {
      response += '\n\nAus pädagogischer Sicht: Beziehungen in Familien sind komplex. Es ist wichtig, die Bedürfnisse aller Beteiligten zu sehen und einen respektvollen Dialog zu führen.';
    }
    
    // Biete weitere Unterstützung an
    if (_random.nextBool()) {
      response += '\n\nMöchtest du mir mehr darüber erzählen, oder gibt es etwas Konkretes, bei dem ich dich unterstützen kann?';
    }
    
    return response;
  }

  /// Listet verfügbare allgemeine Hilfsressourcen auf
  List<Map<String, String>> getGeneralResources() {
    return List<Map<String, String>>.from(_helpResources['de']!['general']!);
  }
}
