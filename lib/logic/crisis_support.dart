/// Mehrsprachige Krisen-/Notfall-Erkennung und -Antworten für die
/// KI-Elternberatung.
///
/// SICHERHEITSKRITISCH: Äußert ein Elternteil Suizidgedanken, Kindeswohl-
/// gefährdung oder akute Überlastung, MUSS die App — in jeder unterstützten
/// Sprache — vor jeder KI-Antwort auf echte, menschliche Hilfe verweisen.
/// Diese Logik läuft deshalb bewusst VOR dem KI-Call und ist von Gemini
/// unabhängig.
///
/// Erkennung ist mehrsprachig (DE/EN/TR/KU + generische Signale), die Antwort
/// wird lokalisiert ausgegeben und nennt länderabhängige Notrufnummern.
class CrisisSupport {
  const CrisisSupport._();

  /// Normalisiert Text für den Keyword-Abgleich: lowercase, Umlaute/diakritische
  /// Zeichen vereinheitlichen, Mehrfach-Whitespace zusammenfassen.
  static String normalize(String input) {
    var text = input.toLowerCase();
    const replacements = {
      'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss',
      'â': 'a', 'î': 'i', 'û': 'u', 'ê': 'e', 'ô': 'o',
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ş': 's', 'é': 'e', 'è': 'e',
    };
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Akute Gefahr: Suizid, Selbst-/Fremdverletzung, Kindeswohlgefährdung,
  /// Kontrollverlust gegenüber dem Kind. Priorität 1 — verweist auf Notruf.
  static const List<String> acuteKeywords = [
    // Deutsch
    'suizid', 'selbstmord', 'ich will sterben', 'ich will nicht mehr leben',
    'nicht mehr leben', 'mich umbringen', 'mir das leben nehmen',
    'ich will verschwinden', 'ich sehe keinen ausweg', 'keinen ausweg mehr',
    'ich konnte meinem kind etwas antun', 'meinem kind etwas antun',
    'ich will meinem kind etwas antun', 'die kontrolle verlieren',
    'kontrolle zu verlieren', 'mein partner schlagt das kind',
    'kindeswohlgefahrdung', 'selbstverletzung', 'fremdgefahrdung',
    'akute gefahr', 'bringe mich um', 'bring mich um',
    // Englisch
    'suicide', 'kill myself', 'end my life', 'want to die', "don't want to live",
    'do not want to live', 'hurt my child', 'harm my child', 'harm myself',
    'self harm', 'self-harm', 'losing control', 'lose control',
    'no way out', 'end it all',
    // Türkisch
    'intihar', 'kendimi oldurmek', 'olmek istiyorum', 'yasamak istemiyorum',
    'cocuguma zarar', 'kendime zarar', 'kontrolu kaybetmek',
    // Kurdisch (Kurmancî)
    'xwekustin', 'ez dixwazim bimirim', 'nahatejiyane', 'ziyana zarok',
    'zirare bide zarok', 'kontrol winda',
  ];

  /// Emotionale Überlastung ohne akute Gefahr ("ich kann nicht mehr").
  /// Priorität 2 — sanfte Unterstützung, KEINE Notruf-Eskalation.
  static const List<String> overloadKeywords = [
    // Deutsch
    'ich kann nicht mehr', 'ich halte es nicht mehr aus', 'ich bin uberfordert',
    'ich bin erschopft', 'ich bin am ende', 'ich fuhle mich leer',
    'ich bin vollig fertig', 'ich bin ausgebrannt',
    // Englisch
    "i can't anymore", 'i cant anymore', "i can't take it", 'i cant take it',
    'i am overwhelmed', "i'm overwhelmed", 'i am exhausted', "i'm exhausted",
    'i am burned out', 'at my limit', 'at the end of my rope',
    // Türkisch
    'artik yapamiyorum', 'dayanamiyorum', 'cok yorgunum', 'tukendim',
    'bittim artik', 'bunaldim',
    // Kurdisch
    'ez edi nikarim', 'gelek westiyayi', 'ez betal bum', 'ez westiyam',
  ];

  /// Prüft, ob der Text ein akutes Krisensignal enthält (mehrsprachig).
  static bool isAcuteCrisis(String message) =>
      _containsAny(normalize(message), acuteKeywords);

  /// Prüft, ob der Text auf emotionale Überlastung (ohne akute Gefahr) deutet.
  static bool isEmotionalOverload(String message) =>
      _containsAny(normalize(message), overloadKeywords);

  static bool _containsAny(String normalized, List<String> keywords) {
    for (final keyword in keywords) {
      if (normalized.contains(normalize(keyword))) return true;
    }
    return false;
  }

  /// Länderabhängige Notrufzeile. [countryCode] z.B. 'DE','AT','CH','TR','GB'.
  /// Fällt auf die europäische 112 + lokalen Hinweis zurück.
  static String emergencyLine(String? countryCode) {
    switch ((countryCode ?? '').toUpperCase()) {
      case 'DE':
        return 'Notruf 112 · Telefonseelsorge 0800 111 0 111 oder 0800 111 0 222 (24/7) · '
            'ärztlicher Bereitschaftsdienst 116 117 · bei Kindeswohlgefährdung das Jugendamt';
      case 'AT':
        return 'Notruf 112/144 · Telefonseelsorge 142 (24/7) · Rat auf Draht 147 (für Sorgen rund ums Kind)';
      case 'CH':
        return 'Notruf 112/144 · Dargebotene Hand 143 (24/7) · Pro Juventute Elternberatung 058 261 61 61';
      case 'TR':
        return 'Acil 112 · psikolojik destek için 182 (Sağlık Bakanlığı) · çocuk ihmali/istismarı için 183 (ALO 183)';
      case 'GB':
        return 'Emergency 999 (or 112) · Samaritans 116 123 (free, 24/7) · NSPCC 0808 800 5000 for concerns about a child';
      default:
        return 'In the EU dial 112 for emergencies. Please also contact a local crisis or child-protection helpline right now.';
    }
  }

  /// Lokalisierte Krisen-Antwort (akute Gefahr) inkl. länderabhängiger Nummern.
  /// Für nicht abgedeckte Sprachen wird Englisch verwendet.
  static String crisisResponse({
    required String languageCode,
    String? countryCode,
  }) {
    final line = emergencyLine(countryCode);
    switch (languageCode) {
      case 'de':
        return 'Das klingt nach einer akuten Belastung. Du musst damit nicht allein bleiben. '
            'Dies ist eine KI-gestützte Orientierung und ersetzt keine professionelle Beratung. '
            'Bitte hole dir jetzt direkte menschliche Hilfe:\n$line';
      case 'tr':
        return 'Bu acil bir yük gibi görünüyor. Bununla yalnız kalmak zorunda değilsin. '
            'Bu yapay zekâ destekli bir yönlendirmedir ve profesyonel danışmanlığın yerini tutmaz. '
            'Lütfen şimdi doğrudan insani yardım al:\n$line';
      case 'ku':
      case 'ckb':
        return 'Ev wekî barek giran a lezgîn xuya dike. Tu ne tenê yî. '
            'Ev rêberiyeke bi alîkariya AI ye û şûna şêwirmendiya pispor nagire. '
            'Ji kerema xwe niha alîkariya mirovî ya rasterast bistîne:\n$line';
      default:
        return 'This sounds like an acute crisis, and you don\'t have to face it alone. '
            'This is AI-assisted guidance and does not replace professional support. '
            'Please reach out for real human help right now:\n$line';
    }
  }

  /// Lokalisierte, sanfte Antwort bei emotionaler Überlastung (ohne Notruf-
  /// Eskalation). Für nicht abgedeckte Sprachen wird Englisch verwendet.
  static String emotionalSupportResponse({required String languageCode}) {
    switch (languageCode) {
      case 'de':
        return 'Das klingt gerade richtig schwer. Du musst nicht stark sein und bist damit nicht allein. 🫶\n\n'
            'Lass es uns ganz klein machen: einmal tief ausatmen, ein Glas Wasser, dann nur den nächsten schwierigen Moment anschauen.\n\n'
            'Was war direkt davor los — nur der Ablauf, ohne Bewertung?\n\n'
            'Hinweis: Ich bin eine unterstützende KI und kein Ersatz für therapeutische Beratung. Wenn du menschliche Hilfe möchtest, nenne ich dir gern passende Anlaufstellen.';
      case 'tr':
        return 'Şu an gerçekten zor görünüyor. Güçlü olmak zorunda değilsin ve yalnız değilsin. 🫶\n\n'
            'Küçük adımlarla ilerleyelim: bir kez derin nefes ver, bir bardak su iç, sonra sadece bir sonraki zor ana bak.\n\n'
            'Hemen öncesinde ne oldu — sadece akış, yargılamadan?\n\n'
            'Not: Ben destekleyici bir yapay zekâyım, terapötik danışmanlığın yerini tutmam. İnsani yardım istersen uygun başvuru yerlerini söyleyebilirim.';
      case 'ku':
      case 'ckb':
        return 'Niha bi rastî dijwar xuya dike. Ne hewce ye tu bihêz bî û tu ne tenê yî. 🫶\n\n'
            'Ka em wê biçûk bikin: carekê kûr bêhna xwe berde, îskanek av, paşê tenê li kêliya dijwar a bê binêre.\n\n'
            'Berî wê çi qewimî — tenê rêzik, bêyî darizandin?\n\n'
            'Têbînî: Ez AI-yeke piştgir im, ne şûna şêwirmendiya terapîstî. Heke tu alîkariya mirovî bixwazî, ez dikarim navnîşanan pêşniyar bikim.';
      default:
        return 'That sounds really hard right now. You don\'t have to be strong, and you\'re not alone. 🫶\n\n'
            'Let\'s make it small: breathe out once, have a glass of water, then look only at the next difficult moment.\n\n'
            'What happened just before — only the sequence, without judgement?\n\n'
            'Note: I\'m a supportive AI, not a replacement for therapeutic help. If you\'d like human support, I can point you to the right places.';
    }
  }
}
