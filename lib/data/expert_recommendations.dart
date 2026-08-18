/// Eltern-Bibliothek — kuratierte Experten-Empfehlungen.
///
/// Podcasts, YouTube-Kanäle, Bücher — nach Kategorie und Sprache.
/// Links gehen auf Kanäle/Profile (nicht einzelne Folgen → veralten nicht).
/// Jede Empfehlung hat einen empathischen Satz der sagt WARUM das jetzt hilft.

enum ExpertContentType { podcast, youtube, book, article }

enum ExpertCategory {
  wutKonflikte,
  schlafen,
  geschwister,
  schuleLernen,
  ichAmLimit,
  spielenBindung,
}

class ExpertRecommendation {
  final String id;
  final String expertName;
  final String title;
  final ExpertContentType type;
  final ExpertCategory category;
  final String language; // 'de', 'en', 'tr', 'ku'
  final String url;
  final String whyItHelps; // 1 empathischer Satz
  final String? duration; // z.B. "Podcast · ca. 20 Min./Folge"
  final String? imageEmoji; // Fallback wenn kein Bild

  const ExpertRecommendation({
    required this.id,
    required this.expertName,
    required this.title,
    required this.type,
    required this.category,
    required this.language,
    required this.url,
    required this.whyItHelps,
    this.duration,
    this.imageEmoji,
  });
}

/// Alle kuratierten Empfehlungen.
class ExpertRecommendations {
  ExpertRecommendations._();

  static List<ExpertRecommendation> getByLanguage(String lang) {
    return all.where((r) => r.language == lang).toList();
  }

  static List<ExpertRecommendation> getByCategory(
      String lang, ExpertCategory category) {
    return all
        .where((r) => r.language == lang && r.category == category)
        .toList();
  }

  static String categoryLabel(ExpertCategory cat, String lang) {
    switch (cat) {
      case ExpertCategory.wutKonflikte:
        return lang == 'en'
            ? 'Anger & Conflicts'
            : lang == 'tr'
                ? 'Öfke & Çatışmalar'
                : lang == 'ku'
                    ? 'Hêrs & Nakokî'
                    : 'Wut & Konflikte';
      case ExpertCategory.schlafen:
        return lang == 'en'
            ? 'Sleep'
            : lang == 'tr'
                ? 'Uyku'
                : lang == 'ku'
                    ? 'Xew'
                    : 'Schlafen';
      case ExpertCategory.geschwister:
        return lang == 'en'
            ? 'Siblings'
            : lang == 'tr'
                ? 'Kardeşler'
                : lang == 'ku'
                    ? 'Xwişk û bira'
                    : 'Geschwister';
      case ExpertCategory.schuleLernen:
        return lang == 'en'
            ? 'School & Learning'
            : lang == 'tr'
                ? 'Okul & Öğrenme'
                : lang == 'ku'
                    ? 'Dibistan & Fêrbûn'
                    : 'Schule & Lernen';
      case ExpertCategory.ichAmLimit:
        return lang == 'en'
            ? "I'm at my limit"
            : lang == 'tr'
                ? 'Sınırımdayım'
                : lang == 'ku'
                    ? 'Ez di sînorê xwe de me'
                    : 'Ich am Limit';
      case ExpertCategory.spielenBindung:
        return lang == 'en'
            ? 'Play & Bonding'
            : lang == 'tr'
                ? 'Oyun & Bağlanma'
                : lang == 'ku'
                    ? 'Lîstik & Girêdan'
                    : 'Spielen & Bindung';
    }
  }

  static String categoryEmoji(ExpertCategory cat) {
    switch (cat) {
      case ExpertCategory.wutKonflikte:
        return '😤';
      case ExpertCategory.schlafen:
        return '😴';
      case ExpertCategory.geschwister:
        return '👫';
      case ExpertCategory.schuleLernen:
        return '🏫';
      case ExpertCategory.ichAmLimit:
        return '💔';
      case ExpertCategory.spielenBindung:
        return '🧸';
    }
  }

  static String typeLabel(ExpertContentType type) {
    switch (type) {
      case ExpertContentType.podcast:
        return '🎧 Podcast';
      case ExpertContentType.youtube:
        return '📺 YouTube';
      case ExpertContentType.book:
        return '📖 Buch';
      case ExpertContentType.article:
        return '📝 Artikel';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALLE EMPFEHLUNGEN
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<ExpertRecommendation> all = [
    // ─── DEUTSCH ────────────────────────────────────────────────────────────

    // Wut & Konflikte
    ExpertRecommendation(
      id: 'de_kathy_weber_podcast',
      expertName: 'Kathy Weber',
      title: 'FamilieVerstwordsehen — Der GfK-Podcast',
      type: ExpertContentType.podcast,
      category: ExpertCategory.wutKonflikte,
      language: 'de',
      url: 'https://kw-herzenssache.de/podcast/',
      whyItHelps:
          'Wenn du gerade denkst du machst alles falsch — Kathy nimmt dir in 20 Minuten dieses Gefühl. Ohne Vorwürfe, nur Verständnis.',
      duration: 'Podcast · ca. 20 Min./Folge',
      imageEmoji: '🎧',
    ),
    ExpertRecommendation(
      id: 'de_huether_youtube',
      expertName: 'Gerald Hüther',
      title: 'Vorträge über Potenzialentfaltung',
      type: ExpertContentType.youtube,
      category: ExpertCategory.wutKonflikte,
      language: 'de',
      url:
          'https://www.youtube.com/results?search_query=gerald+hüther+vortrag+kinder',
      whyItHelps:
          'Wenn du verstehen willst warum dein Kind so reagiert — Hüther erklärt die Hirnforschung dahinter. Ruhig, klar, ohne Fachjargon.',
      duration: 'YouTube · 8–45 Min.',
      imageEmoji: '📺',
    ),
    ExpertRecommendation(
      id: 'de_nora_imlau_buch',
      expertName: 'Nora Imlau',
      title: 'So viel Freude, so viel Wut',
      type: ExpertContentType.book,
      category: ExpertCategory.wutKonflikte,
      language: 'de',
      url: 'https://www.nora-imlau.de/',
      whyItHelps:
          'Dein Kind fühlt alles intensiver als andere? Nora Imlau versteht gefühlsstarke Kinder — und zeigt dir dass es kein Problem ist.',
      duration: 'Buch · 304 Seiten',
      imageEmoji: '📖',
    ),

    // Schlafen
    ExpertRecommendation(
      id: 'de_artgerecht_schlafen',
      expertName: 'Nicola Schmidt',
      title: 'artgerecht — Das andere Schlafbuch',
      type: ExpertContentType.book,
      category: ExpertCategory.schlafen,
      language: 'de',
      url: 'https://nicolaschmidt.de/buecher/',
      whyItHelps:
          'Wenn die Nächte endlos sind und alle sagen "lass es schreien" — Nicola Schmidt zeigt einen Weg ohne Tränen.',
      duration: 'Buch · 192 Seiten',
      imageEmoji: '📖',
    ),
    ExpertRecommendation(
      id: 'de_gewuenschtestes_wunschkind_podcast',
      expertName: 'Danielle Graf & Katja Seide',
      title: 'Das gewünschteste Wunschkind — Podcast',
      type: ExpertContentType.podcast,
      category: ExpertCategory.schlafen,
      language: 'de',
      url: 'https://podtail.com/de/podcast/das-gewunschteste-wunschkind/',
      whyItHelps:
          'Zwei Mütter die selbst durch alles durchgegangen sind. Ehrlich, warmherzig, ohne erhobenen Zeigefinger.',
      duration: 'Podcast · ca. 30 Min./Folge',
      imageEmoji: '🎧',
    ),

    // Geschwister
    ExpertRecommendation(
      id: 'de_jesper_juul_geschwister',
      expertName: 'Jesper Juul',
      title: 'Geschwister als Team (familylab)',
      type: ExpertContentType.youtube,
      category: ExpertCategory.geschwister,
      language: 'de',
      url: 'https://familylab.de/videos',
      whyItHelps:
          'Wenn deine Kinder sich ständig streiten und du nicht weißt ob du eingreifen sollst — Juul gibt klare, ruhige Orientierung.',
      duration: 'YouTube · 5–20 Min.',
      imageEmoji: '📺',
    ),
    ExpertRecommendation(
      id: 'de_nicola_schmidt_geschwister',
      expertName: 'Nicola Schmidt',
      title: 'Geschwister als Team (Buch)',
      type: ExpertContentType.book,
      category: ExpertCategory.geschwister,
      language: 'de',
      url: 'https://nicolaschmidt.de/buecher/',
      whyItHelps:
          'Streit gehört dazu — aber wie begleitest du ihn so, dass alle sich gesehen fühlen? Dieses Buch zeigt wie.',
      duration: 'Buch · 224 Seiten',
      imageEmoji: '📖',
    ),

    // Schule & Lernen
    ExpertRecommendation(
      id: 'de_huether_schule',
      expertName: 'Gerald Hüther',
      title: 'Jedes Kind ist hochbegabt',
      type: ExpertContentType.book,
      category: ExpertCategory.schuleLernen,
      language: 'de',
      url: 'https://www.gerald-huether.de/',
      whyItHelps:
          'Wenn du das Gefühl hast, die Schule bricht dein Kind — Hüther erinnert dich daran, dass Noten nicht alles sind.',
      duration: 'Buch · 256 Seiten',
      imageEmoji: '📖',
    ),

    // Ich am Limit
    ExpertRecommendation(
      id: 'de_kathy_weber_limit',
      expertName: 'Kathy Weber',
      title: 'Selbstempathie für Eltern',
      type: ExpertContentType.podcast,
      category: ExpertCategory.ichAmLimit,
      language: 'de',
      url: 'https://kw-herzenssache.de/podcast/',
      whyItHelps:
          'Du gibst jeden Tag alles und es fühlt sich trotzdem nie genug an? Kathy zeigt: Du darfst auch deine eigenen Bedürfnisse sehen.',
      duration: 'Podcast · ca. 20 Min.',
      imageEmoji: '🎧',
    ),
    ExpertRecommendation(
      id: 'de_nora_imlau_limit',
      expertName: 'Nora Imlau',
      title: 'In guten Händen — Eltern-Burnout',
      type: ExpertContentType.book,
      category: ExpertCategory.ichAmLimit,
      language: 'de',
      url: 'https://www.nora-imlau.de/',
      whyItHelps:
          'Wenn du merkst, du bist leer — dieses Buch sagt dir: Du bist nicht schuld. Und es zeigt einen Weg raus.',
      duration: 'Buch · 288 Seiten',
      imageEmoji: '📖',
    ),

    // Spielen & Bindung
    ExpertRecommendation(
      id: 'de_herbert_renz_polster',
      expertName: 'Herbert Renz-Polster',
      title: 'Kinder verstehen (Blog & Vorträge)',
      type: ExpertContentType.youtube,
      category: ExpertCategory.spielenBindung,
      language: 'de',
      url:
          'https://www.youtube.com/results?search_query=herbert+renz-polster+vortrag',
      whyItHelps:
          'Warum Kinder so sind wie sie sind — evolutionär erklärt, liebevoll erzählt. Danach siehst du dein Kind mit neuen Augen.',
      duration: 'YouTube · 15–60 Min.',
      imageEmoji: '📺',
    ),
    ExpertRecommendation(
      id: 'de_susanne_mierau',
      expertName: 'Susanne Mierau',
      title: 'Geborgen Wachsen — Blog & Podcast',
      type: ExpertContentType.podcast,
      category: ExpertCategory.spielenBindung,
      language: 'de',
      url: 'https://geborgen-wachsen.de/',
      whyItHelps:
          'Bindung im Alltag leben — nicht als Theorie, sondern als kleine Momente die du sofort umsetzen kannst.',
      duration: 'Blog + Podcast',
      imageEmoji: '🎧',
    ),

    // ─── ENGLISH ────────────────────────────────────────────────────────────

    // Wut & Konflikte
    ExpertRecommendation(
      id: 'en_janet_lansbury',
      expertName: 'Janet Lansbury',
      title: 'Unruffled — Respectful Parenting Podcast',
      type: ExpertContentType.podcast,
      category: ExpertCategory.wutKonflikte,
      language: 'en',
      url: 'https://www.janetlansbury.com/podcast/',
      whyItHelps:
          "When you feel like you're failing — Janet's calm voice reminds you that your child's big feelings are not your fault.",
      duration: 'Podcast · 10–20 min/episode',
      imageEmoji: '🎧',
    ),
    ExpertRecommendation(
      id: 'en_dr_becky',
      expertName: 'Dr. Becky Kennedy',
      title: 'Good Inside — Parenting Podcast & YouTube',
      type: ExpertContentType.youtube,
      category: ExpertCategory.wutKonflikte,
      language: 'en',
      url: 'https://www.youtube.com/@drbeckyatgoodinside',
      whyItHelps:
          "The most practical parenting advice on the internet. Short videos, real situations, no judgment.",
      duration: 'YouTube · 5–15 min',
      imageEmoji: '📺',
    ),
    ExpertRecommendation(
      id: 'en_daniel_siegel',
      expertName: 'Daniel J. Siegel',
      title: 'The Whole-Brain Child',
      type: ExpertContentType.book,
      category: ExpertCategory.wutKonflikte,
      language: 'en',
      url: 'https://www.drdansiegel.com/books/',
      whyItHelps:
          "Understanding why your child melts down — and 12 strategies that actually work. Science made simple.",
      duration: 'Book · 176 pages',
      imageEmoji: '📖',
    ),

    // Schlafen
    ExpertRecommendation(
      id: 'en_sarah_ockwell_smith',
      expertName: 'Sarah Ockwell-Smith',
      title: 'The Gentle Sleep Book',
      type: ExpertContentType.book,
      category: ExpertCategory.schlafen,
      language: 'en',
      url: 'https://sarahockwell-smith.com/books/',
      whyItHelps:
          "If everyone tells you to 'sleep train' but it feels wrong — this book gives you a gentler path.",
      duration: 'Book · 288 pages',
      imageEmoji: '📖',
    ),

    // Ich am Limit
    ExpertRecommendation(
      id: 'en_dr_becky_limit',
      expertName: 'Dr. Becky Kennedy',
      title: 'Good Inside (Book)',
      type: ExpertContentType.book,
      category: ExpertCategory.ichAmLimit,
      language: 'en',
      url: 'https://www.goodinside.com/',
      whyItHelps:
          "You are a good parent having a hard time. Not a bad parent. This book holds that truth for you.",
      duration: 'Book · 304 pages',
      imageEmoji: '📖',
    ),

    // Spielen & Bindung
    ExpertRecommendation(
      id: 'en_janet_lansbury_play',
      expertName: 'Janet Lansbury',
      title: 'Elevating Child Care (Blog)',
      type: ExpertContentType.article,
      category: ExpertCategory.spielenBindung,
      language: 'en',
      url: 'https://www.janetlansbury.com/',
      whyItHelps:
          "Simple, respectful ideas for play and connection. You don't need expensive toys — just presence.",
      duration: 'Blog articles · 5 min reads',
      imageEmoji: '📝',
    ),

    // ─── TÜRKÇE ─────────────────────────────────────────────────────────────

    ExpertRecommendation(
      id: 'tr_pedagog_tv',
      expertName: 'Pedagog TV',
      title: 'Çocuk Gelişimi ve Ebeveynlik',
      type: ExpertContentType.youtube,
      category: ExpertCategory.wutKonflikte,
      language: 'tr',
      url:
          'https://www.youtube.com/results?search_query=pedagog+tv+cocuk+gelisimi',
      whyItHelps:
          'Çocuğunuz öfkelendiğinde ne yapacağınızı bilmiyorsanız — bu kanal size sakin ve pratik yollar gösterir.',
      duration: 'YouTube · 10–30 dk.',
      imageEmoji: '📺',
    ),
    ExpertRecommendation(
      id: 'tr_cocuk_gelisimi',
      expertName: 'Doç. Dr. Özgür Bolat',
      title: 'Çocuk ve Ergen Psikolojisi',
      type: ExpertContentType.youtube,
      category: ExpertCategory.schuleLernen,
      language: 'tr',
      url:
          'https://www.youtube.com/results?search_query=cocuk+gelisimi+okul+stresi+pedagog',
      whyItHelps:
          'Okul stresi, sınav kaygısı, motivasyon — Türkçe, bilimsel ve anlaşılır anlatımla.',
      duration: 'YouTube · 10–20 dk.',
      imageEmoji: '📺',
    ),
    ExpertRecommendation(
      id: 'tr_anne_baba_okulu',
      expertName: 'Anne Baba Okulu',
      title: 'Bilinçli Ebeveynlik Podcast',
      type: ExpertContentType.podcast,
      category: ExpertCategory.ichAmLimit,
      language: 'tr',
      url: 'https://open.spotify.com/search/anne%20baba%20okulu',
      whyItHelps:
          'Tükendiğinizi hissettiğinizde — bu podcast size yalnız olmadığınızı hatırlatır.',
      duration: 'Podcast · ca. 25 dk.',
      imageEmoji: '🎧',
    ),

    // ─── KURDÎ ──────────────────────────────────────────────────────────────

    ExpertRecommendation(
      id: 'ku_gfk_kurdi',
      expertName: 'Parentpeak KI',
      title: 'Şêwirmendiya dêûbavan bi Kurdî',
      type: ExpertContentType.article,
      category: ExpertCategory.wutKonflikte,
      language: 'ku',
      url: 'https://parentpeak.de',
      whyItHelps:
          'Ji bo dêûbavên Kurd — şêwirmendiya me ya KI bi Kurdî dixebite. Tu dikari bi zimanê xwe pirsên xwe bipirsi.',
      duration: 'KI-Beratung · jederzeit',
      imageEmoji: '✨',
    ),
    ExpertRecommendation(
      id: 'ku_huether_kurdi_de',
      expertName: 'Gerald Hüther',
      title: 'Çima zarok wisa tevdigerin? (Almancî bi jêrnivîs)',
      type: ExpertContentType.youtube,
      category: ExpertCategory.spielenBindung,
      language: 'ku',
      url:
          'https://www.youtube.com/results?search_query=gerald+hüther+vortrag+kinder',
      whyItHelps:
          'Hüther bi almancî qala mezinbûna zarokan dike — bi jêrnivîsan hûn dikarin bişopînin. Aram, zelal û ji dil.',
      duration: 'YouTube · 8–45 dk. (Almancî)',
      imageEmoji: '📺',
    ),
  ];
}
