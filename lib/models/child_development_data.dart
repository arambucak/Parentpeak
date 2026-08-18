import 'package:flutter/material.dart';

/// Kind-Profil für die Entwicklungseinschätzung.
class ChildProfile {
  final String name;
  final DateTime birthDate;
  final String careType; // 'kita', 'tagesmutter', 'zuhause', 'andere'

  const ChildProfile({
    required this.name,
    required this.birthDate,
    required this.careType,
  });

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  }

  String get ageLabel {
    final months = ageInMonths;
    if (months < 12) return '$months Monate';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return '$years Jahre';
    return '$years Jahre, $remainingMonths Monate';
  }

  String get ageGroupId {
    final months = ageInMonths;
    if (months < 12) return '0-12m';
    if (months < 24) return '1-2y';
    if (months < 36) return '2-3y';
    if (months < 48) return '3-4y';
    if (months < 72) return '4-6y';
    if (months < 120) return '6-10y';
    if (months < 168) return '10-14y';
    return '14-18y';
  }

  Map<String, String> toJson() => {
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'careType': careType,
      };

  factory ChildProfile.fromJson(Map<String, String> json) => ChildProfile(
        name: json['name'] ?? '',
        birthDate: DateTime.tryParse(json['birthDate'] ?? '') ?? DateTime.now(),
        careType: json['careType'] ?? 'zuhause',
      );
}

/// Ein Entwicklungsbereich mit Fragen.
class DevDomain {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final String description;
  final List<String> questions;
  final List<String> tips;

  const DevDomain({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.description,
    required this.questions,
    required this.tips,
  });
}

/// Altersgerechte Fragesets.
/// Pilot: 2-3 Jahre (30 Fragen, 5 Bereiche × 6 Fragen)
class DevelopmentQuestionBank {
  static List<DevDomain> getQuestionsForAge(String ageGroupId) {
    switch (ageGroupId) {
      case '0-12m':
        return _questions0to12m;
      case '1-2y':
        return _questions1to2;
      case '2-3y':
        return _questions2to3;
      case '3-4y':
        return _questions3to4;
      case '4-6y':
        return _questions4to6;
      case '6-10y':
        return _questions6to10;
      case '10-14y':
        return _questions10to14;
      case '14-18y':
        return _questions14to18;
      default:
        return _questions2to3;
    }
  }

  static const List<DevDomain> _questions2to3 = [
    DevDomain(
      id: 'motorik',
      title: 'Bewegung & Körper',
      emoji: '\u{1F3C3}',
      color: Color(0xFF0EA5E9),
      description: 'Grobmotorik, Feinmotorik & Körperwahrnehmung',
      questions: [
        'Kann dein Kind sicher Treppen steigen (mit Festhalten)?',
        'Kann dein Kind auf einem Bein kurz stehen?',
        'Kann dein Kind einen Ball fangen oder werfen?',
        'Kann dein Kind einfache Formen nachmalen (Kreis, Strich)?',
        'Kann dein Kind selbstständig mit Löffel oder Gabel essen?',
        'Springt oder hüpft dein Kind von selbst (z.B. über Pfützen)?',
      ],
      tips: [
        'Baue Kletter-Möglichkeiten in den Alltag ein (Spielplatz, Kissen)',
        'Knete, Perlen fädeln oder Sandspiel fördern Feinmotorik',
        'Lass dein Kind barfuß laufen — das stärkt Balance und Körpergefühl',
      ],
    ),
    DevDomain(
      id: 'sprache',
      title: 'Sprache & Verstehen',
      emoji: '\u{1F4AC}',
      color: Color(0xFF16A34A),
      description: 'Wortschatz, Sätze bilden & Sprachverständnis',
      questions: [
        'Bildet dein Kind Zwei- bis Drei-Wort-Sätze?',
        'Kann dein Kind einfache Fragen beantworten (Was? Wo?)?',
        'Benennt dein Kind Alltagsgegenstände richtig?',
        'Versteht dein Kind einfache Aufträge (Bring mir das Buch)?',
        'Singt oder summt dein Kind Lieder oder Melodien mit?',
        'Erzählt dein Kind von Erlebnissen (auch wenn noch nicht perfekt)?',
      ],
      tips: [
        'Sprich langsam und in kurzen Sätzen — wiederhole Wörter oft',
        'Lies jeden Tag 5-10 Minuten vor und zeige auf Bilder',
        'Benenne alles was du tust: "Ich schneide die Banane"',
      ],
    ),
    DevDomain(
      id: 'denken',
      title: 'Denken & Entdecken',
      emoji: '\u{1F4A1}',
      color: Color(0xFFF59E0B),
      description: 'Problemlösen, Neugier & Konzentration',
      questions: [
        'Kann dein Kind einfache Puzzles lösen (3-6 Teile)?',
        'Sortiert oder ordnet dein Kind Dinge nach Farbe oder Größe?',
        'Bleibt dein Kind bei einer Aufgabe länger als 2-3 Minuten dran?',
        'Zeigt dein Kind Interesse an Bücher-Anschauen?',
        'Versucht dein Kind Dinge herauszufinden (Was passiert wenn...)?',
        'Kann dein Kind Körperteile benennen oder zeigen?',
      ],
      tips: [
        'Biete offene Spielmaterialien an (Bauklotze, Sand, Wasser)',
        'Stelle Warum-Fragen zurück statt sie zu beantworten: "Was denkst DU?"',
        'Unterbrich konzentriertes Spiel nicht — auch wenn es "nur" Matschen ist',
      ],
    ),
    DevDomain(
      id: 'sozial',
      title: 'Gefühle & Miteinander',
      emoji: '\u{1F49C}',
      color: Color(0xFFEC4899),
      description: 'Emotionen, Empathie & soziales Verhalten',
      questions: [
        'Zeigt dein Kind deutlich Freude, Wut oder Trauer?',
        'Sucht dein Kind Trost bei dir wenn es traurig oder verletzt ist?',
        'Kann dein Kind kurze Wartezeiten aushalten (mit Begleitung)?',
        'Spielt dein Kind neben oder mit anderen Kindern?',
        'Zeigt dein Kind Mitgefühl wenn jemand weint oder sich wehgetan hat?',
        'Akzeptiert dein Kind einfache Grenzen (auch wenn es protestiert)?',
      ],
      tips: [
        'Benenne Gefühle laut: "Du bist wütend weil..." — das lehrt Emotionswortschatz',
        'Bleib ruhig bei Wutanfällen — deine Ruhe ist das Modell für Regulation',
        'Parallelspiel (nebeneinander) ist für 2-3-Jährige völlig normal und wertvoll',
      ],
    ),
    DevDomain(
      id: 'selbst',
      title: 'Eigenständigkeit & Alltag',
      emoji: '\u{1F31F}',
      color: Color(0xFF8B5CF6),
      description: 'Selbstständigkeit, Routinen & Alltagskompetenz',
      questions: [
        'Zieht sich dein Kind teilweise selbst an (Schuhe, Mütze, Jacke)?',
        'Kann dein Kind sich die Hände selbst waschen?',
        'Hilft dein Kind bei einfachen Aufgaben (Tisch decken, aufräumen)?',
        'Zeigt dein Kind den Wunsch Dinge "alleine" zu machen?',
        'Kennt dein Kind einfache Tagesabläufe (erst essen, dann spielen)?',
        'Kann dein Kind seinen Namen sagen wenn jemand fragt?',
      ],
      tips: [
        'Gib Wahlmöglichkeiten statt Anweisungen: "Rote oder blaue Jacke?"',
        'Lass Fehler zu — verschüttete Milch ist ein Lernmoment, keine Katastrophe',
        'Rituale geben Sicherheit: gleicher Ablauf morgens und abends',
      ],
    ),
  ];
  // ═══════════════════════════════════════════════════════════════════════
  // 0-12 MONATE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions0to12m = [
    DevDomain(
        id: 'motorik',
        title: 'Bewegung & Sinne',
        emoji: '\u{1F476}',
        color: Color(0xFF0EA5E9),
        description: 'Greifen, Drehen, Krabbeln & erste Schritte',
        questions: [
          'Greift dein Baby gezielt nach Gegenständen?',
          'Dreht sich dein Baby vom Rücken auf den Bauch (oder umgekehrt)?',
          'Kann dein Baby sitzen (mit oder ohne Stütze)?',
          'Krabbelt oder robbt dein Baby?',
          'Zieht sich dein Baby an Möbeln hoch?'
        ],
        tips: [
          'Biete verschiedene Greifspielzeuge in unterschiedlichen Texturen an',
          'Bauchlage täglich üben — stärkt Nacken und Rücken'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Laute & Verstehen',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Erste Laute, Reaktion auf Sprache & Kommunikation',
        questions: [
          'Macht dein Baby verschiedene Laute (Brabbeln, Quietschen)?',
          'Reagiert dein Baby auf seinen Namen?',
          'Dreht sich dein Baby zu Geräuschen um?',
          'Lacht oder juchzt dein Baby wenn du mit ihm sprichst?',
          'Versteht dein Baby einfache Wörter wie "Nein" oder "Winke-winke"?'
        ],
        tips: [
          'Sprich viel mit deinem Baby — auch beim Wickeln und Füttern',
          'Singe Lieder und wiederhole Laute die dein Baby macht'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Entdecken & Begreifen',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Neugier, Ursache-Wirkung & Objektpermanenz',
        questions: [
          'Untersucht dein Baby Gegenstände mit Händen und Mund?',
          'Sucht dein Baby nach Dingen die du versteckst?',
          'Klopft oder schüttelt dein Baby Spielzeug um Geräusche zu machen?',
          'Beobachtet dein Baby aufmerksam Gesichter und Bewegungen?',
          'Zeigt dein Baby auf Dinge die es interessieren?'
        ],
        tips: [
          'Spiele Kuckuck — das trainiert Objektpermanenz',
          'Lass dein Baby verschiedene Materialien erforschen (sicher!)'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Bindung & Gefühle',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Bindungsverhalten, Lächeln & Fremdeln',
        questions: [
          'Lächelt dein Baby dich gezielt an?',
          'Sucht dein Baby Blickkontakt mit dir?',
          'Zeigt dein Baby Unbehagen bei fremden Personen?',
          'Beruhigt sich dein Baby wenn du es aufnimmst?',
          'Streckt dein Baby die Arme aus um hochgenommen zu werden?'
        ],
        tips: [
          'Reagiere zuverlässig auf Weinen — das baut sichere Bindung auf',
          'Körpernähe und Hautkontakt sind in diesem Alter das Wichtigste'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Erste Selbstständigkeit',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Essen, Schlafen & einfache Eigenaktivität',
        questions: [
          'Kann dein Baby einen Keks oder Stück Obst selbst halten und essen?',
          'Trinkt dein Baby aus einem Becher (mit Hilfe)?',
          'Zeigt dein Baby einen Schlaf-Wach-Rhythmus?',
          'Kann dein Baby sich kurz alleine beschäftigen?',
          'Zeigt dein Baby Vorlieben (bestimmtes Spielzeug, bestimmte Person)?'
        ],
        tips: [
          'Biete Fingerfood an — fördert Feinmotorik und Autonomie',
          'Feste Rituale (Schlaf, Essen) geben Sicherheit'
        ]),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 1-2 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions1to2 = [
    DevDomain(
        id: 'motorik',
        title: 'Bewegung & Körper',
        emoji: '\u{1F3C3}',
        color: Color(0xFF0EA5E9),
        description: 'Laufen, Klettern & erste Feinmotorik',
        questions: [
          'Kann dein Kind frei laufen?',
          'Kann dein Kind sich bücken und wieder aufstehen?',
          'Klettert dein Kind auf niedrige Möbel oder Treppen?',
          'Kann dein Kind mit einem Stift kritzeln?',
          'Stapelt dein Kind 2-3 Klötze übereinander?',
          'Kann dein Kind einen Ball rollen oder werfen?'
        ],
        tips: [
          'Lass dein Kind viel barfuß laufen',
          'Biete Treppen zum Uebensteigen an (mit Aufsicht)',
          'Sandspiel und Wasser-Giessen fördern Feinmotorik'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Sprache & Ausdruck',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Erste Wörter, Zeigen & Verstehen',
        questions: [
          'Spricht dein Kind mindestens 10 erkennbare Wörter?',
          'Zeigt dein Kind auf Dinge die es haben oder zeigen möchte?',
          'Versteht dein Kind einfache Anweisungen (Komm her, gib mir)?',
          'Benennt dein Kind vertraute Personen (Mama, Papa)?',
          'Schüttelt oder nickt dein Kind den Kopf für Ja/Nein?',
          'Versucht dein Kind Wörter nachzusprechen?'
        ],
        tips: [
          'Benenne alles im Alltag — Wiederholung ist der Schlüssel',
          'Bilderbücher täglich anschauen und benennen',
          'Nicht korrigieren, sondern richtig wiederholen: Kind: "Wau!" — Du: "Ja, ein Hund!"'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Denken & Spielen',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Nachahmung, Sortieren & So-tun-als-ob',
        questions: [
          'Ahmt dein Kind Alltagshandlungen nach (telefonieren, kochen)?',
          'Versteht dein Kind wozu Gegenstände dienen (Kamm = Haare)?',
          'Kann dein Kind einfache Einlegepuzzles lösen (1-3 Teile)?',
          'Zeigt dein Kind auf Bilder in Büchern wenn du fragst?',
          'Sucht dein Kind aktiv nach versteckten Gegenständen?',
          'Sortiert dein Kind Dinge nach Größe oder Form?'
        ],
        tips: [
          'So-tun-als-ob Spiel fördern: Puppenessen kochen, Teddy wickeln',
          'Lass dein Kind im Alltag "helfen" (Waschmaschine befüllen, rühren)'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Gefühle & Kontakt',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Emotionen zeigen, Trosten & erste Empathie',
        questions: [
          'Zeigt dein Kind deutlich Freude (klatscht, hüpft)?',
          'Kommt dein Kind zu dir wenn es Trost braucht?',
          'Reagiert dein Kind wenn ein anderes Kind weint?',
          'Kann dein Kind "Nein" zeigen oder sagen?',
          'Spielt dein Kind gerne in der Nähe anderer Kinder?',
          'Zeigt dein Kind Stolz wenn ihm etwas gelingt?'
        ],
        tips: [
          'Benenne Gefühle: "Du bist froh!" / "Das hat dich erschreckt"',
          'Trosten statt ablenken — Gefühle duerfen da sein'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Eigenständigkeit',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Essen, Anziehen & "Alleine machen!"',
        questions: [
          'Isst dein Kind selbstständig mit Löffel?',
          'Trinkt dein Kind alleine aus einem Becher?',
          'Zieht dein Kind sich Mütze oder Socken aus?',
          'Zeigt dein Kind den Wunsch Dinge alleine zu tun?',
          'Räumt dein Kind Spielzeug weg (mit Aufforderung)?',
          'Zeigt dein Kind Interesse an Töpfchen oder Toilette?'
        ],
        tips: [
          'Geduld beim "Alleine!"-Wunsch — auch wenns länger dauert',
          'Kleine Aufgaben geben: Schuhe zur Tür bringen, Banane schälen helfen'
        ]),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 3-4 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions3to4 = [
    DevDomain(
        id: 'motorik',
        title: 'Bewegung & Geschick',
        emoji: '\u{1F3C3}',
        color: Color(0xFF0EA5E9),
        description: 'Balance, Klettern & Feinmotorik',
        questions: [
          'Kann dein Kind Dreirad oder Laufrad fahren?',
          'Kann dein Kind auf einem Bein kurz stehen?',
          'Kann dein Kind eine Schere benutzen (einfache Schnitte)?',
          'Malt dein Kind erkennbare Formen (Kreis, Kreuz)?',
          'Kann dein Kind Perlen auffädeln oder Knöpfe öffnen?',
          'Springt dein Kind mit beiden Füßen vom Boden ab?'
        ],
        tips: [
          'Bewegungsspiele draußen: Balancieren auf Baumstämmen, Hüpfspiele',
          'Basteln mit Schere und Kleber — auch wenn es nicht perfekt ist'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Sprache & Erzählen',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Sätze, Fragen stellen & Geschichten',
        questions: [
          'Spricht dein Kind in ganzen Sätzen (4-5 Wörter)?',
          'Stellt dein Kind Warum-Fragen?',
          'Kann dein Kind von Erlebnissen erzählen (auch wenn durcheinander)?',
          'Versteht dein Kind Präpositionen (auf, unter, neben)?',
          'Benutzt dein Kind Mehrzahl richtig (Autos, Bälle)?',
          'Kann dein Kind einfache Reime oder Lieder aufsagen?'
        ],
        tips: [
          'Warum-Fragen ernst nehmen — auch wenn es der 50. Warum ist',
          'Gemeinsam Geschichten erfinden: "Und dann...?"'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Denken & Fantasie',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Rollenspiel, Zählen & Zusammenhänge',
        questions: [
          'Spielt dein Kind Rollenspiele (Arzt, Kaufladen, Familie)?',
          'Kann dein Kind bis 5 oder 10 zählen?',
          'Versteht dein Kind einfache Zusammenhänge (wenn es regnet = nass)?',
          'Kann dein Kind 3-4 Farben benennen?',
          'Löst dein Kind Puzzles mit 6-12 Teilen?',
          'Erkennt dein Kind Muster und kann sie fortsetzen?'
        ],
        tips: [
          'Rollenspiel ist DIE Lernform in diesem Alter — mitspielen!',
          'Im Alltag zählen: Treppenstufen, Aepfel, Schuhe'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Gefühle & Freundschaft',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Teilen, Konflikte & Frustrationstoleranz',
        questions: [
          'Kann dein Kind mit anderen Kindern spielen (nicht nur nebeneinander)?',
          'Kann dein Kind kurz warten wenn es etwas will?',
          'Kann dein Kind Spielzeug teilen (manchmal)?',
          'Zeigt dein Kind Mitgefühl und tröstet andere?',
          'Kann dein Kind Enttäuschung ausdrücken ohne zu hauen?',
          'Hat dein Kind erste Spielfreundschaften?'
        ],
        tips: [
          'Teilen muss man nicht erzwingen — es kommt mit der sozialen Reife',
          'Konflikte zwischen Kindern begleiten, nicht lösen'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Alltag & Verantwortung',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Anziehen, Hygiene & kleine Aufgaben',
        questions: [
          'Kann dein Kind sich weitgehend selbst anziehen?',
          'Geht dein Kind selbstständig auf die Toilette (meistens)?',
          'Kann dein Kind sich die Zähne putzen (mit Nachputzen)?',
          'Hilft dein Kind bei Aufgaben (Tisch decken, Blumen giessen)?',
          'Kennt dein Kind Tagesablauefe und kann sie benennen?',
          'Kann dein Kind seinen Vor- und Nachnamen sagen?'
        ],
        tips: [
          'Lass dein Kind bei echten Aufgaben helfen — nicht nur Spielaufgaben',
          'Routinen visuell machen: Bilder-Plan für morgens/abends'
        ]),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 4-6 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions4to6 = [
    DevDomain(
        id: 'motorik',
        title: 'Körper & Koordination',
        emoji: '\u{1F3C3}',
        color: Color(0xFF0EA5E9),
        description: 'Sport, Schreiben & Geschicklichkeit',
        questions: [
          'Kann dein Kind Fahrrad fahren (mit oder ohne Stützräder)?',
          'Kann dein Kind seinen Namen schreiben?',
          'Kann dein Kind an einer Linie entlang schneiden?',
          'Kann dein Kind einen Ball gezielt fangen?',
          'Hüpft dein Kind auf einem Bein mehrere Male?',
          'Kann dein Kind kleine Knöpfe schließen?'
        ],
        tips: [
          'Feinmotorik: Perlen, Bügeln, Origami — Spaß statt Drill',
          'Bewegung draußen täglich mindestens 1 Stunde'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Sprache & Verständnis',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Erzählen, Grammatik & Wortschatz',
        questions: [
          'Erzählt dein Kind Geschichten mit Anfang, Mitte, Ende?',
          'Benutzt dein Kind korrekte Grammatik (meistens)?',
          'Kann dein Kind Witze verstehen oder erzählen?',
          'Versteht dein Kind komplexe Anweisungen (Erst..., dann...)?',
          'Interessiert sich dein Kind für Buchstaben oder Lesen?',
          'Kann dein Kind Reime bilden oder Silben klatschen?'
        ],
        tips: [
          'Vorlesen bleibt wichtig — auch wenn das Kind selbst "lesen" will',
          'Reim-Spiele und Silben-Klatschen bereiten auf Schule vor'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Denken & Schulreife',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Logik, Konzentration & Vorschulkompetenz',
        questions: [
          'Kann dein Kind 20 Minuten an einer Aufgabe dranbleiben?',
          'Versteht dein Kind Zeitbegriffe (gestern, morgen, später)?',
          'Kann dein Kind einfache Mengen vergleichen (mehr/weniger)?',
          'Löst dein Kind Probleme zunehmend selbst?',
          'Kann dein Kind Regeln in Brettspielen verstehen und einhalten?',
          'Zeigt dein Kind Interesse an Zahlen und Zählen?'
        ],
        tips: [
          'Brettspiele sind ideales Training für Frustrationstoleranz + Regeln',
          'Nicht zu früh schulisch fördern — Spielen IST Lernen'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Soziales & Empathie',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Freundschaften, Regeln & Perspektivübernahme',
        questions: [
          'Hat dein Kind feste Freundschaften?',
          'Kann dein Kind sich in andere hineinversetzen?',
          'Hält dein Kind Regeln ein (meistens)?',
          'Kann dein Kind Konflikte verbal lösen (manchmal)?',
          'Zeigt dein Kind Verantwortungsgefühl für Juengere oder Tiere?',
          'Kann dein Kind verlieren ohne länger als 2-3 Minuten zu weinen?'
        ],
        tips: [
          'Verlieren üben: Brettspiele spielen, nicht absichtlich verlieren lassen',
          'Empathie stärken: "Wie fühlt sich das andere Kind jetzt wohl?"'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Selbstständigkeit & Reife',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Verantwortung, Planung & Alltagskompetenz',
        questions: [
          'Kann dein Kind sich komplett alleine anziehen?',
          'Kann dein Kind einfache Mahlzeiten vorbereiten (Brot schmieren)?',
          'Kennt dein Kind seine Adresse oder Telefonnummer?',
          'Kann dein Kind alleine auf die Toilette (inkl. abwischen)?',
          'Kann dein Kind einen kurzen Weg alleine gehen (z.B. zum Nachbarn)?',
          'Kann dein Kind eigene Bedürfnisse klar kommunizieren?'
        ],
        tips: [
          'Echte Verantwortung geben: Haustier fuettern, Zimmer aufruaemen',
          'Schulweg üben — Schritt für Schritt mehr Autonomie'
        ]),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 6-10 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions6to10 = [
    DevDomain(
        id: 'motorik',
        title: 'Körper & Sport',
        emoji: '\u{1F3C3}',
        color: Color(0xFF0EA5E9),
        description: 'Koordination, Ausdauer & Feinmotorik',
        questions: [
          'Kann dein Kind fluessig schreiben?',
          'Treibt dein Kind gerne Sport oder bewegt sich ausdauernd?',
          'Kann dein Kind Schleife binden?',
          'Hat dein Kind eine gute Körperkoordination (Schwimmen, Klettern)?',
          'Kann dein Kind länger als 30 Minuten stillsitzen (in der Schule)?'
        ],
        tips: [
          'Sport soll Spaß machen — nicht Leistung',
          'Bildschirmzeit begrenzen = mehr natuerliche Bewegung'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Sprache & Lesen',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Lesen, Schreiben & Ausdruck',
        questions: [
          'Liest dein Kind altersgerechte Texte fluessig?',
          'Kann dein Kind Geschichten schriftlich erzählen?',
          'Drueckt sich dein Kind differenziert aus?',
          'Versteht dein Kind Ironie oder uebertragene Bedeutungen?',
          'Erzählt dein Kind von der Schule und Erlebnissen?'
        ],
        tips: [
          'Gemeinsam lesen — auch wenn das Kind schon selbst lesen kann',
          'Über den Tag sprechen: nicht nur "Wie war die Schule?"'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Lernen & Denken',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Schule, Konzentration & Problemlösen',
        questions: [
          'Kann dein Kind Hausaufgaben weitgehend selbstständig erledigen?',
          'Zeigt dein Kind Neugier und stellt Fragen?',
          'Kann dein Kind Zusammenhänge logisch erklären?',
          'Plant dein Kind Dinge voraus (Packen, Zeitmanagement)?',
          'Geht dein Kind konstruktiv mit Fehlern um?'
        ],
        tips: [
          'Fehler sind Lernchancen — nicht bestrafen, sondern besprechen',
          'Eigene Loesungswege zulassen, auch wenn sie umstaendlich sind'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Freundschaft & Gefühle',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Freundeskreis, Konflikte & Selbstregulation',
        questions: [
          'Hat dein Kind stabile Freundschaften?',
          'Kann dein Kind Konflikte ohne Gewalt lösen?',
          'Kann dein Kind mit Enttäuschung und Frust umgehen?',
          'Zeigt dein Kind Mitgefühl und Hilfsbereitschaft?',
          'Kann dein Kind eigene Gefühle benennen und erklären?'
        ],
        tips: [
          'Nicht jede Situation lösen — Kinder brauchen auch eigene Konfliktloesungen',
          'Gefühle validieren: "Ich verstehe dass dich das aergert"'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Verantwortung & Alltag',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Pflichten, Zeitgefühl & Eigenorganisation',
        questions: [
          'Übernimmt dein Kind regelmäßig Pflichten im Haushalt?',
          'Kann dein Kind seine Schulsachen selbst organisieren?',
          'Hat dein Kind ein Zeitgefühl (Absprachen einhalten)?',
          'Kann dein Kind alleine zur Schule gehen?',
          'Trifft dein Kind altersgerechte Entscheidungen selbst?'
        ],
        tips: [
          'Taschengeld ab 6-7 Jahren lehrt Verantwortung für Geld',
          'Eigenen Wecker stellen, eigene Tasche packen'
        ]),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 10-14 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions10to14 = [
    DevDomain(
        id: 'motorik',
        title: 'Körper & Gesundheit',
        emoji: '\u{1F3C3}',
        color: Color(0xFF0EA5E9),
        description: 'Pubertät, Körperbild & Bewegung',
        questions: [
          'Bewegt sich dein Kind regelmäßig (Sport, Fahrrad, draußen)?',
          'Hat dein Kind ein gesundes Verhältnis zu seinem Körper?',
          'Schlaeft dein Kind ausreichend (8-10 Stunden)?',
          'Ernaehrt sich dein Kind weitgehend gesund?',
          'Achtet dein Kind auf Körperhygiene selbstständig?'
        ],
        tips: [
          'Vorbild sein: gemeinsam bewegen statt Anweisungen geben',
          'Körperveränderungen normalisieren — offen darüber sprechen'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Ausdruck & Kommunikation',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Argumentieren, Reflektieren & Medienkompetenz',
        questions: [
          'Kann dein Kind seine Meinung begruendet ausdrücken?',
          'Liest dein Kind freiwillig (Bücher, Artikel, Comics)?',
          'Kann dein Kind sachlich diskutieren (meistens)?',
          'Nutzt dein Kind Medien reflektiert?',
          'Kann dein Kind über Gefühle sprechen wenn es will?'
        ],
        tips: [
          'Diskussionen zulassen — Teenager lernen durch Gegenposition',
          'Medienkompetenz gemeinsam entwickeln, nicht nur verbieten'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Denken & Lernen',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Abstraktes Denken, Planung & Lernstrategien',
        questions: [
          'Kann dein Kind abstrakt denken (Was waere wenn...)?',
          'Organisiert dein Kind Schularbeit selbstständig?',
          'Hat dein Kind eigene Interessen die es vertieft?',
          'Kann dein Kind Konsequenzen vorausdenken?',
          'Zeigt dein Kind intrinsische Motivation für mindestens ein Thema?'
        ],
        tips: [
          'Interesse unterstuetzen — auch wenn es nicht schulrelevant ist',
          'Planungstools anbieten: Kalender, To-Do-Listen'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Identitaet & Beziehungen',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Freundeskreis, Identitaet & Abgrenzung',
        questions: [
          'Hat dein Kind stabile Freundschaften?',
          'Kann dein Kind Gruppendruck widerstehen?',
          'Zeigt dein Kind Empathie für andere (auch Fremde)?',
          'Kann dein Kind Grenzen setzen und kommunizieren?',
          'Beginnt dein Kind eine eigene Identitaet zu entwickeln?'
        ],
        tips: [
          'Pubertät = Abgrenzung. Das ist gesund, nicht respektlos.',
          'Zuhoren ohne sofort zu lösen — Präsenz reicht oft'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Autonomie & Verantwortung',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Selbstorganisation, Geld & Entscheidungen',
        questions: [
          'Übernimmt dein Kind Verantwortung für eigene Aufgaben?',
          'Kann dein Kind mit Geld umgehen (Taschengeld)?',
          'Trifft dein Kind eigene Entscheidungen und traegt Konsequenzen?',
          'Kann dein Kind alleine unterwegs sein (Stadt, OEPNV)?',
          'Zeigt dein Kind Zuverlaessigkeit bei Absprachen?'
        ],
        tips: [
          'Mehr Freiheit bei mehr Verantwortung — verhandeln statt diktieren',
          'Fehler machen lassen — solange Sicherheit gewaehrleistet ist'
        ]),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 14-18 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions14to18 = [
    DevDomain(
        id: 'motorik',
        title: 'Gesundheit & Wohlbefinden',
        emoji: '\u{1F3C3}',
        color: Color(0xFF0EA5E9),
        description: 'Körper, Schlaf, Ernaehrung & Bewegung',
        questions: [
          'Bewegt sich dein Teenager regelmäßig?',
          'Hat dein Teenager einen gesunden Schlafrhythmus?',
          'Ernaehrt sich dein Teenager bewusst?',
          'Konsumiert dein Teenager verantwortungsvoll (kein Missbrauch)?',
          'Achtet dein Teenager auf psychische Gesundheit?'
        ],
        tips: [
          'Nicht kontrollieren sondern vorleben',
          'Über psychische Gesundheit offen sprechen — entstigmatisieren'
        ]),
    DevDomain(
        id: 'sprache',
        title: 'Ausdruck & Reflexion',
        emoji: '\u{1F4AC}',
        color: Color(0xFF16A34A),
        description: 'Selbstreflexion, Argumentation & Kommunikation',
        questions: [
          'Kann dein Teenager seine Gedanken klar ausdrücken?',
          'Reflektiert dein Teenager eigenes Verhalten?',
          'Kann dein Teenager konstruktiv Feedback annehmen?',
          'Kommuniziert dein Teenager respektvoll (meistens)?',
          'Kann dein Teenager verschiedene Perspektiven einnehmen?'
        ],
        tips: [
          'Respektvolle Kommunikation vorleben — auch in Konflikten',
          'Fragen statt Vorwuerfe: "Was brauchst du?" statt "Warum machst du...?"'
        ]),
    DevDomain(
        id: 'denken',
        title: 'Zukunft & Orientierung',
        emoji: '\u{1F4A1}',
        color: Color(0xFFF59E0B),
        description: 'Berufsorientierung, Werte & eigene Ziele',
        questions: [
          'Hat dein Teenager Vorstellungen von der eigenen Zukunft?',
          'Zeigt dein Teenager Eigeninitiative (Praktika, Projekte)?',
          'Kann dein Teenager eigene Werte benennen?',
          'Setzt sich dein Teenager eigene Ziele?',
          'Kann dein Teenager komplexe Entscheidungen abwaegen?'
        ],
        tips: [
          'Zukunftsplaene müssen nicht fest sein — Orientierung reicht',
          'Praktische Erfahrungen ermöglichen: Praktika, Nebenjobs, Ehrenamt'
        ]),
    DevDomain(
        id: 'sozial',
        title: 'Beziehungen & Identitaet',
        emoji: '\u{1F49C}',
        color: Color(0xFFEC4899),
        description: 'Partnerschaft, Identitaet & gesellschaftliche Rolle',
        questions: [
          'Pflegt dein Teenager gesunde Freundschaften?',
          'Kann dein Teenager Nein sagen zu Gruppendruck?',
          'Geht dein Teenager respektvoll mit Beziehungen um?',
          'Zeigt dein Teenager ein stabiles Selbstbild?',
          'Engagiert sich dein Teenager für etwas (sozial, politisch, kreativ)?'
        ],
        tips: [
          'Identitaetsfindung braucht Raum — nicht jede Phase kommentieren',
          'Beziehungen respektieren — auch wenn sie dir nicht gefallen'
        ]),
    DevDomain(
        id: 'selbst',
        title: 'Selbstständigkeit & Reife',
        emoji: '\u{1F31F}',
        color: Color(0xFF8B5CF6),
        description: 'Lebenskompetenz, Finanzen & Verantwortung',
        questions: [
          'Kann dein Teenager eigenständig einen Haushalt führen (kochen, waschen)?',
          'Geht dein Teenager verantwortungsvoll mit Geld um?',
          'Kann dein Teenager Behördengänge oder Arzttermine alleine machen?',
          'Hält dein Teenager Verpflichtungen zuverlässig ein?',
          'Ist dein Teenager bereit für ein zunehmend eigenständiges Leben?'
        ],
        tips: [
          'Lebenskompetenzen aktiv lehren: Kochen, Steuererklärung, Waschmaschine',
          'Loslassen üben — für euch beide'
        ]),
  ];
}
