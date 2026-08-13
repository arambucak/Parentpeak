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
      title: 'Bewegung & Koerper',
      emoji: '\u{1F3C3}',
      color: Color(0xFF0EA5E9),
      description: 'Grobmotorik, Feinmotorik & Koerperwahrnehmung',
      questions: [
        'Kann dein Kind sicher Treppen steigen (mit Festhalten)?',
        'Kann dein Kind auf einem Bein kurz stehen?',
        'Kann dein Kind einen Ball fangen oder werfen?',
        'Kann dein Kind einfache Formen nachmalen (Kreis, Strich)?',
        'Kann dein Kind selbststaendig mit Loeffel oder Gabel essen?',
        'Springt oder huepft dein Kind von selbst (z.B. ueber Pfützen)?',
      ],
      tips: [
        'Baue Kletter-Möglichkeiten in den Alltag ein (Spielplatz, Kissen)',
        'Knete, Perlen faedeln oder Sandspiel foerdern Feinmotorik',
        'Lass dein Kind barfuss laufen — das staerkt Balance und Koerpergefühl',
      ],
    ),
    DevDomain(
      id: 'sprache',
      title: 'Sprache & Verstehen',
      emoji: '\u{1F4AC}',
      color: Color(0xFF16A34A),
      description: 'Wortschatz, Saetze bilden & Sprachverstaendnis',
      questions: [
        'Bildet dein Kind Zwei- bis Drei-Wort-Saetze?',
        'Kann dein Kind einfache Fragen beantworten (Was? Wo?)?',
        'Benennt dein Kind Alltagsgegenstaende richtig?',
        'Versteht dein Kind einfache Auftraege (Bring mir das Buch)?',
        'Singt oder summt dein Kind Lieder oder Melodien mit?',
        'Erzaehlt dein Kind von Erlebnissen (auch wenn noch nicht perfekt)?',
      ],
      tips: [
        'Sprich langsam und in kurzen Saetzen — wiederhole Woerter oft',
        'Lies jeden Tag 5-10 Minuten vor und zeige auf Bilder',
        'Benenne alles was du tust: "Ich schneide die Banane"',
      ],
    ),
    DevDomain(
      id: 'denken',
      title: 'Denken & Entdecken',
      emoji: '\u{1F4A1}',
      color: Color(0xFFF59E0B),
      description: 'Problemloesen, Neugier & Konzentration',
      questions: [
        'Kann dein Kind einfache Puzzles loesen (3-6 Teile)?',
        'Sortiert oder ordnet dein Kind Dinge nach Farbe oder Größe?',
        'Bleibt dein Kind bei einer Aufgabe laenger als 2-3 Minuten dran?',
        'Zeigt dein Kind Interesse an Bücher-Anschauen?',
        'Versucht dein Kind Dinge herauszufinden (Was passiert wenn...)?',
        'Kann dein Kind Koerperteile benennen oder zeigen?',
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
        'Sucht dein Kind Troest bei dir wenn es traurig oder verletzt ist?',
        'Kann dein Kind kurze Wartezeiten aushalten (mit Begleitung)?',
        'Spielt dein Kind neben oder mit anderen Kindern?',
        'Zeigt dein Kind Mitgefühl wenn jemand weint oder sich wehgetan hat?',
        'Akzeptiert dein Kind einfache Grenzen (auch wenn es protestiert)?',
      ],
      tips: [
        'Benenne Gefühle laut: "Du bist wuetend weil..." — das lehrt Emotionswortschatz',
        'Bleib ruhig bei Wutanfaellen — deine Ruhe ist das Modell für Regulation',
        'Parallelspiel (nebeneinander) ist für 2-3-Jaehrige voellig normal und wertvoll',
      ],
    ),
    DevDomain(
      id: 'selbst',
      title: 'Eigenstaendigkeit & Alltag',
      emoji: '\u{1F31F}',
      color: Color(0xFF8B5CF6),
      description: 'Selbststaendigkeit, Routinen & Alltagskompetenz',
      questions: [
        'Zieht sich dein Kind teilweise selbst an (Schuhe, Muetze, Jacke)?',
        'Kann dein Kind sich die Hände selbst waschen?',
        'Hilft dein Kind bei einfachen Aufgaben (Tisch decken, aufraeumen)?',
        'Zeigt dein Kind den Wunsch Dinge "alleine" zu machen?',
        'Kennt dein Kind einfache Tagesablaeufe (erst essen, dann spielen)?',
        'Kann dein Kind seinen Namen sagen wenn jemand fragt?',
      ],
      tips: [
        'Gib Wahlmöglichkeiten statt Anweisungen: "Rote oder blaue Jacke?"',
        'Lass Fehler zu — verschuettete Milch ist ein Lernmoment, keine Katastrophe',
        'Rituale geben Sicherheit: gleicher Ablauf morgens und abends',
      ],
    ),
  ];
  // ═══════════════════════════════════════════════════════════════════════
  // 0-12 MONATE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions0to12m = [
    DevDomain(id: 'motorik', title: 'Bewegung & Sinne', emoji: '\u{1F476}', color: Color(0xFF0EA5E9), description: 'Greifen, Drehen, Krabbeln & erste Schritte', questions: ['Greift dein Baby gezielt nach Gegenstaenden?', 'Dreht sich dein Baby vom Ruecken auf den Bauch (oder umgekehrt)?', 'Kann dein Baby sitzen (mit oder ohne Stuetze)?', 'Krabbelt oder robbt dein Baby?', 'Zieht sich dein Baby an Moebeln hoch?'], tips: ['Biete verschiedene Greifspielzeuge in unterschiedlichen Texturen an', 'Bauchlage täglich ueben — staerkt Nacken und Ruecken']),
    DevDomain(id: 'sprache', title: 'Laute & Verstehen', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Erste Laute, Reaktion auf Sprache & Kommunikation', questions: ['Macht dein Baby verschiedene Laute (Brabbeln, Quietschen)?', 'Reagiert dein Baby auf seinen Namen?', 'Dreht sich dein Baby zu Geraeuschen um?', 'Lacht oder juchzt dein Baby wenn du mit ihm sprichst?', 'Versteht dein Baby einfache Woerter wie "Nein" oder "Winke-winke"?'], tips: ['Sprich viel mit deinem Baby — auch beim Wickeln und Fuettern', 'Singe Lieder und wiederhole Laute die dein Baby macht']),
    DevDomain(id: 'denken', title: 'Entdecken & Begreifen', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Neugier, Ursache-Wirkung & Objektpermanenz', questions: ['Untersucht dein Baby Gegenstaende mit Händen und Mund?', 'Sucht dein Baby nach Dingen die du versteckst?', 'Klopft oder schuettelt dein Baby Spielzeug um Geraeusche zu machen?', 'Beobachtet dein Baby aufmerksam Gesichter und Bewegungen?', 'Zeigt dein Baby auf Dinge die es interessieren?'], tips: ['Spiele Kuckuck — das trainiert Objektpermanenz', 'Lass dein Baby verschiedene Materialien erforschen (sicher!)']),
    DevDomain(id: 'sozial', title: 'Bindung & Gefühle', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Bindungsverhalten, Laecheln & Fremdeln', questions: ['Laechelt dein Baby dich gezielt an?', 'Sucht dein Baby Blickkontakt mit dir?', 'Zeigt dein Baby Unbehagen bei fremden Personen?', 'Beruhigt sich dein Baby wenn du es aufnimmst?', 'Streckt dein Baby die Arme aus um hochgenommen zu werden?'], tips: ['Reagiere zuverlaessig auf Weinen — das baut sichere Bindung auf', 'Koerpernaehe und Hautkontakt sind in diesem Alter das Wichtigste']),
    DevDomain(id: 'selbst', title: 'Erste Selbststaendigkeit', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Essen, Schlafen & einfache Eigenaktivitaet', questions: ['Kann dein Baby einen Keks oder Stueck Obst selbst halten und essen?', 'Trinkt dein Baby aus einem Becher (mit Hilfe)?', 'Zeigt dein Baby einen Schlaf-Wach-Rhythmus?', 'Kann dein Baby sich kurz alleine beschaeftigen?', 'Zeigt dein Baby Vorlieben (bestimmtes Spielzeug, bestimmte Person)?'], tips: ['Biete Fingerfood an — foerdert Feinmotorik und Autonomie', 'Feste Rituale (Schlaf, Essen) geben Sicherheit']),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 1-2 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions1to2 = [
    DevDomain(id: 'motorik', title: 'Bewegung & Koerper', emoji: '\u{1F3C3}', color: Color(0xFF0EA5E9), description: 'Laufen, Klettern & erste Feinmotorik', questions: ['Kann dein Kind frei laufen?', 'Kann dein Kind sich buecken und wieder aufstehen?', 'Klettert dein Kind auf niedrige Moebel oder Treppen?', 'Kann dein Kind mit einem Stift kritzeln?', 'Stapelt dein Kind 2-3 Kloetze uebereinander?', 'Kann dein Kind einen Ball rollen oder werfen?'], tips: ['Lass dein Kind viel barfuss laufen', 'Biete Treppen zum Uebensteigen an (mit Aufsicht)', 'Sandspiel und Wasser-Giessen foerdern Feinmotorik']),
    DevDomain(id: 'sprache', title: 'Sprache & Ausdruck', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Erste Woerter, Zeigen & Verstehen', questions: ['Spricht dein Kind mindestens 10 erkennbare Woerter?', 'Zeigt dein Kind auf Dinge die es haben oder zeigen möchte?', 'Versteht dein Kind einfache Anweisungen (Komm her, gib mir)?', 'Benennt dein Kind vertraute Personen (Mama, Papa)?', 'Schuettelt oder nickt dein Kind den Kopf für Ja/Nein?', 'Versucht dein Kind Woerter nachzusprechen?'], tips: ['Benenne alles im Alltag — Wiederholung ist der Schluessel', 'Bilderbücher täglich anschauen und benennen', 'Nicht korrigieren, sondern richtig wiederholen: Kind: "Wau!" — Du: "Ja, ein Hund!"']),
    DevDomain(id: 'denken', title: 'Denken & Spielen', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Nachahmung, Sortieren & So-tun-als-ob', questions: ['Ahmt dein Kind Alltagshandlungen nach (telefonieren, kochen)?', 'Versteht dein Kind wozu Gegenstaende dienen (Kamm = Haare)?', 'Kann dein Kind einfache Einlegepuzzles loesen (1-3 Teile)?', 'Zeigt dein Kind auf Bilder in Büchern wenn du fragst?', 'Sucht dein Kind aktiv nach versteckten Gegenstaenden?', 'Sortiert dein Kind Dinge nach Größe oder Form?'], tips: ['So-tun-als-ob Spiel foerdern: Puppenessen kochen, Teddy wickeln', 'Lass dein Kind im Alltag "helfen" (Waschmaschine befuellen, ruehren)']),
    DevDomain(id: 'sozial', title: 'Gefühle & Kontakt', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Emotionen zeigen, Troesten & erste Empathie', questions: ['Zeigt dein Kind deutlich Freude (klatscht, huepft)?', 'Kommt dein Kind zu dir wenn es Trost braucht?', 'Reagiert dein Kind wenn ein anderes Kind weint?', 'Kann dein Kind "Nein" zeigen oder sagen?', 'Spielt dein Kind gerne in der Naehe anderer Kinder?', 'Zeigt dein Kind Stolz wenn ihm etwas gelingt?'], tips: ['Benenne Gefühle: "Du bist froh!" / "Das hat dich erschreckt"', 'Troesten statt ablenken — Gefühle duerfen da sein']),
    DevDomain(id: 'selbst', title: 'Eigenstaendigkeit', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Essen, Anziehen & "Alleine machen!"', questions: ['Isst dein Kind selbststaendig mit Loeffel?', 'Trinkt dein Kind alleine aus einem Becher?', 'Zieht dein Kind sich Muetze oder Socken aus?', 'Zeigt dein Kind den Wunsch Dinge alleine zu tun?', 'Raeumt dein Kind Spielzeug weg (mit Aufforderung)?', 'Zeigt dein Kind Interesse an Toepfchen oder Toilette?'], tips: ['Geduld beim "Alleine!"-Wunsch — auch wenns laenger dauert', 'Kleine Aufgaben geben: Schuhe zur Tuer bringen, Banane schaelen helfen']),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 3-4 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions3to4 = [
    DevDomain(id: 'motorik', title: 'Bewegung & Geschick', emoji: '\u{1F3C3}', color: Color(0xFF0EA5E9), description: 'Balance, Klettern & Feinmotorik', questions: ['Kann dein Kind Dreirad oder Laufrad fahren?', 'Kann dein Kind auf einem Bein kurz stehen?', 'Kann dein Kind eine Schere benutzen (einfache Schnitte)?', 'Malt dein Kind erkennbare Formen (Kreis, Kreuz)?', 'Kann dein Kind Perlen auffaedeln oder Knoepfe oeffnen?', 'Springt dein Kind mit beiden Fuessen vom Boden ab?'], tips: ['Bewegungsspiele draussen: Balancieren auf Baumstaemmen, Huepfspiele', 'Basteln mit Schere und Kleber — auch wenn es nicht perfekt ist']),
    DevDomain(id: 'sprache', title: 'Sprache & Erzählen', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Saetze, Fragen stellen & Geschichten', questions: ['Spricht dein Kind in ganzen Saetzen (4-5 Woerter)?', 'Stellt dein Kind Warum-Fragen?', 'Kann dein Kind von Erlebnissen erzählen (auch wenn durcheinander)?', 'Versteht dein Kind Praepostionen (auf, unter, neben)?', 'Benutzt dein Kind Mehrzahl richtig (Autos, Baelle)?', 'Kann dein Kind einfache Reime oder Lieder aufsagen?'], tips: ['Warum-Fragen ernst nehmen — auch wenn es der 50. Warum ist', 'Gemeinsam Geschichten erfinden: "Und dann...?"']),
    DevDomain(id: 'denken', title: 'Denken & Fantasie', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Rollenspiel, Zählen & Zusammenhaenge', questions: ['Spielt dein Kind Rollenspiele (Arzt, Kaufladen, Familie)?', 'Kann dein Kind bis 5 oder 10 zählen?', 'Versteht dein Kind einfache Zusammenhaenge (wenn es regnet = nass)?', 'Kann dein Kind 3-4 Farben benennen?', 'Loest dein Kind Puzzles mit 6-12 Teilen?', 'Erkennt dein Kind Muster und kann sie fortsetzen?'], tips: ['Rollenspiel ist DIE Lernform in diesem Alter — mitspielen!', 'Im Alltag zählen: Treppenstufen, Aepfel, Schuhe']),
    DevDomain(id: 'sozial', title: 'Gefühle & Freundschaft', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Teilen, Konflikte & Frustrationstoleranz', questions: ['Kann dein Kind mit anderen Kindern spielen (nicht nur nebeneinander)?', 'Kann dein Kind kurz warten wenn es etwas will?', 'Kann dein Kind Spielzeug teilen (manchmal)?', 'Zeigt dein Kind Mitgefühl und troestet andere?', 'Kann dein Kind Enttaeuschung ausdruecken ohne zu hauen?', 'Hat dein Kind erste Spielfreundschaften?'], tips: ['Teilen muss man nicht erzwingen — es kommt mit der sozialen Reife', 'Konflikte zwischen Kindern begleiten, nicht loesen']),
    DevDomain(id: 'selbst', title: 'Alltag & Verantwortung', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Anziehen, Hygiene & kleine Aufgaben', questions: ['Kann dein Kind sich weitgehend selbst anziehen?', 'Geht dein Kind selbststaendig auf die Toilette (meistens)?', 'Kann dein Kind sich die Zaehne putzen (mit Nachputzen)?', 'Hilft dein Kind bei Aufgaben (Tisch decken, Blumen giessen)?', 'Kennt dein Kind Tagesablauefe und kann sie benennen?', 'Kann dein Kind seinen Vor- und Nachnamen sagen?'], tips: ['Lass dein Kind bei echten Aufgaben helfen — nicht nur Spielaufgaben', 'Routinen visuell machen: Bilder-Plan für morgens/abends']),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 4-6 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions4to6 = [
    DevDomain(id: 'motorik', title: 'Koerper & Koordination', emoji: '\u{1F3C3}', color: Color(0xFF0EA5E9), description: 'Sport, Schreiben & Geschicklichkeit', questions: ['Kann dein Kind Fahrrad fahren (mit oder ohne Stuetzraeder)?', 'Kann dein Kind seinen Namen schreiben?', 'Kann dein Kind an einer Linie entlang schneiden?', 'Kann dein Kind einen Ball gezielt fangen?', 'Huepft dein Kind auf einem Bein mehrere Male?', 'Kann dein Kind kleine Knoepfe schliessen?'], tips: ['Feinmotorik: Perlen, Buegeln, Origami — Spass statt Drill', 'Bewegung draussen täglich mindestens 1 Stunde']),
    DevDomain(id: 'sprache', title: 'Sprache & Verstaendnis', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Erzählen, Grammatik & Wortschatz', questions: ['Erzaehlt dein Kind Geschichten mit Anfang, Mitte, Ende?', 'Benutzt dein Kind korrekte Grammatik (meistens)?', 'Kann dein Kind Witze verstehen oder erzählen?', 'Versteht dein Kind komplexe Anweisungen (Erst..., dann...)?', 'Interessiert sich dein Kind für Buchstaben oder Lesen?', 'Kann dein Kind Reime bilden oder Silben klatschen?'], tips: ['Vorlesen bleibt wichtig — auch wenn das Kind selbst "lesen" will', 'Reim-Spiele und Silben-Klatschen bereiten auf Schule vor']),
    DevDomain(id: 'denken', title: 'Denken & Schulreife', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Logik, Konzentration & Vorschulkompetenz', questions: ['Kann dein Kind 20 Minuten an einer Aufgabe dranbleiben?', 'Versteht dein Kind Zeitbegriffe (gestern, morgen, später)?', 'Kann dein Kind einfache Mengen vergleichen (mehr/weniger)?', 'Loest dein Kind Probleme zunehmend selbst?', 'Kann dein Kind Regeln in Brettspielen verstehen und einhalten?', 'Zeigt dein Kind Interesse an Zahlen und Zählen?'], tips: ['Brettspiele sind ideales Training für Frustrationstoleranz + Regeln', 'Nicht zu frueh schulisch foerdern — Spielen IST Lernen']),
    DevDomain(id: 'sozial', title: 'Soziales & Empathie', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Freundschaften, Regeln & Perspektivuebernahme', questions: ['Hat dein Kind feste Freundschaften?', 'Kann dein Kind sich in andere hineinversetzen?', 'Haelt dein Kind Regeln ein (meistens)?', 'Kann dein Kind Konflikte verbal loesen (manchmal)?', 'Zeigt dein Kind Verantwortungsgefühl für Juengere oder Tiere?', 'Kann dein Kind verlieren ohne laenger als 2-3 Minuten zu weinen?'], tips: ['Verlieren ueben: Brettspiele spielen, nicht absichtlich verlieren lassen', 'Empathie stärken: "Wie fühlt sich das andere Kind jetzt wohl?"']),
    DevDomain(id: 'selbst', title: 'Selbststaendigkeit & Reife', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Verantwortung, Planung & Alltagskompetenz', questions: ['Kann dein Kind sich komplett alleine anziehen?', 'Kann dein Kind einfache Mahlzeiten vorbereiten (Brot schmieren)?', 'Kennt dein Kind seine Adresse oder Telefonnummer?', 'Kann dein Kind alleine auf die Toilette (inkl. abwischen)?', 'Kann dein Kind einen kurzen Weg alleine gehen (z.B. zum Nachbarn)?', 'Kann dein Kind eigene Bedürfnisse klar kommunizieren?'], tips: ['Echte Verantwortung geben: Haustier fuettern, Zimmer aufruaemen', 'Schulweg ueben — Schritt für Schritt mehr Autonomie']),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 6-10 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions6to10 = [
    DevDomain(id: 'motorik', title: 'Koerper & Sport', emoji: '\u{1F3C3}', color: Color(0xFF0EA5E9), description: 'Koordination, Ausdauer & Feinmotorik', questions: ['Kann dein Kind fluessig schreiben?', 'Treibt dein Kind gerne Sport oder bewegt sich ausdauernd?', 'Kann dein Kind Schleife binden?', 'Hat dein Kind eine gute Koerperkoordination (Schwimmen, Klettern)?', 'Kann dein Kind laenger als 30 Minuten stillsitzen (in der Schule)?'], tips: ['Sport soll Spass machen — nicht Leistung', 'Bildschirmzeit begrenzen = mehr natuerliche Bewegung']),
    DevDomain(id: 'sprache', title: 'Sprache & Lesen', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Lesen, Schreiben & Ausdruck', questions: ['Liest dein Kind altersgerechte Texte fluessig?', 'Kann dein Kind Geschichten schriftlich erzählen?', 'Drueckt sich dein Kind differenziert aus?', 'Versteht dein Kind Ironie oder uebertragene Bedeutungen?', 'Erzaehlt dein Kind von der Schule und Erlebnissen?'], tips: ['Gemeinsam lesen — auch wenn das Kind schon selbst lesen kann', 'Ueber den Tag sprechen: nicht nur "Wie war die Schule?"']),
    DevDomain(id: 'denken', title: 'Lernen & Denken', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Schule, Konzentration & Problemloesen', questions: ['Kann dein Kind Hausaufgaben weitgehend selbststaendig erledigen?', 'Zeigt dein Kind Neugier und stellt Fragen?', 'Kann dein Kind Zusammenhaenge logisch erklären?', 'Plant dein Kind Dinge voraus (Packen, Zeitmanagement)?', 'Geht dein Kind konstruktiv mit Fehlern um?'], tips: ['Fehler sind Lernchancen — nicht bestrafen, sondern besprechen', 'Eigene Loesungswege zulassen, auch wenn sie umstaendlich sind']),
    DevDomain(id: 'sozial', title: 'Freundschaft & Gefühle', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Freundeskreis, Konflikte & Selbstregulation', questions: ['Hat dein Kind stabile Freundschaften?', 'Kann dein Kind Konflikte ohne Gewalt loesen?', 'Kann dein Kind mit Enttaeuschung und Frust umgehen?', 'Zeigt dein Kind Mitgefühl und Hilfsbereitschaft?', 'Kann dein Kind eigene Gefühle benennen und erklären?'], tips: ['Nicht jede Situation loesen — Kinder brauchen auch eigene Konfliktloesungen', 'Gefühle validieren: "Ich verstehe dass dich das aergert"']),
    DevDomain(id: 'selbst', title: 'Verantwortung & Alltag', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Pflichten, Zeitgefühl & Eigenorganisation', questions: ['Uebernimmt dein Kind regelmaessig Pflichten im Haushalt?', 'Kann dein Kind seine Schulsachen selbst organisieren?', 'Hat dein Kind ein Zeitgefühl (Absprachen einhalten)?', 'Kann dein Kind alleine zur Schule gehen?', 'Trifft dein Kind altersgerechte Entscheidungen selbst?'], tips: ['Taschengeld ab 6-7 Jahren lehrt Verantwortung für Geld', 'Eigenen Wecker stellen, eigene Tasche packen']),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 10-14 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions10to14 = [
    DevDomain(id: 'motorik', title: 'Koerper & Gesundheit', emoji: '\u{1F3C3}', color: Color(0xFF0EA5E9), description: 'Pubertaet, Koerperbild & Bewegung', questions: ['Bewegt sich dein Kind regelmaessig (Sport, Fahrrad, draussen)?', 'Hat dein Kind ein gesundes Verhaeltnis zu seinem Koerper?', 'Schlaeft dein Kind ausreichend (8-10 Stunden)?', 'Ernaehrt sich dein Kind weitgehend gesund?', 'Achtet dein Kind auf Koerperhygiene selbststaendig?'], tips: ['Vorbild sein: gemeinsam bewegen statt Anweisungen geben', 'Koerperveränderungen normalisieren — offen darueber sprechen']),
    DevDomain(id: 'sprache', title: 'Ausdruck & Kommunikation', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Argumentieren, Reflektieren & Medienkompetenz', questions: ['Kann dein Kind seine Meinung begruendet ausdruecken?', 'Liest dein Kind freiwillig (Bücher, Artikel, Comics)?', 'Kann dein Kind sachlich diskutieren (meistens)?', 'Nutzt dein Kind Medien reflektiert?', 'Kann dein Kind ueber Gefühle sprechen wenn es will?'], tips: ['Diskussionen zulassen — Teenager lernen durch Gegenposition', 'Medienkompetenz gemeinsam entwickeln, nicht nur verbieten']),
    DevDomain(id: 'denken', title: 'Denken & Lernen', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Abstraktes Denken, Planung & Lernstrategien', questions: ['Kann dein Kind abstrakt denken (Was waere wenn...)?', 'Organisiert dein Kind Schularbeit selbststaendig?', 'Hat dein Kind eigene Interessen die es vertieft?', 'Kann dein Kind Konsequenzen vorausdenken?', 'Zeigt dein Kind intrinsische Motivation für mindestens ein Thema?'], tips: ['Interesse unterstuetzen — auch wenn es nicht schulrelevant ist', 'Planungstools anbieten: Kalender, To-Do-Listen']),
    DevDomain(id: 'sozial', title: 'Identitaet & Beziehungen', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Freundeskreis, Identitaet & Abgrenzung', questions: ['Hat dein Kind stabile Freundschaften?', 'Kann dein Kind Gruppendruck widerstehen?', 'Zeigt dein Kind Empathie für andere (auch Fremde)?', 'Kann dein Kind Grenzen setzen und kommunizieren?', 'Beginnt dein Kind eine eigene Identitaet zu entwickeln?'], tips: ['Pubertaet = Abgrenzung. Das ist gesund, nicht respektlos.', 'Zuhoren ohne sofort zu loesen — Präsenz reicht oft']),
    DevDomain(id: 'selbst', title: 'Autonomie & Verantwortung', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Selbstorganisation, Geld & Entscheidungen', questions: ['Uebernimmt dein Kind Verantwortung für eigene Aufgaben?', 'Kann dein Kind mit Geld umgehen (Taschengeld)?', 'Trifft dein Kind eigene Entscheidungen und traegt Konsequenzen?', 'Kann dein Kind alleine unterwegs sein (Stadt, OEPNV)?', 'Zeigt dein Kind Zuverlaessigkeit bei Absprachen?'], tips: ['Mehr Freiheit bei mehr Verantwortung — verhandeln statt diktieren', 'Fehler machen lassen — solange Sicherheit gewaehrleistet ist']),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 14-18 JAHRE
  // ═══════════════════════════════════════════════════════════════════════
  static const List<DevDomain> _questions14to18 = [
    DevDomain(id: 'motorik', title: 'Gesundheit & Wohlbefinden', emoji: '\u{1F3C3}', color: Color(0xFF0EA5E9), description: 'Koerper, Schlaf, Ernaehrung & Bewegung', questions: ['Bewegt sich dein Teenager regelmaessig?', 'Hat dein Teenager einen gesunden Schlafrhythmus?', 'Ernaehrt sich dein Teenager bewusst?', 'Konsumiert dein Teenager verantwortungsvoll (kein Missbrauch)?', 'Achtet dein Teenager auf psychische Gesundheit?'], tips: ['Nicht kontrollieren sondern vorleben', 'Ueber psychische Gesundheit offen sprechen — entstigmatisieren']),
    DevDomain(id: 'sprache', title: 'Ausdruck & Reflexion', emoji: '\u{1F4AC}', color: Color(0xFF16A34A), description: 'Selbstreflexion, Argumentation & Kommunikation', questions: ['Kann dein Teenager seine Gedanken klar ausdruecken?', 'Reflektiert dein Teenager eigenes Verhalten?', 'Kann dein Teenager konstruktiv Feedback annehmen?', 'Kommuniziert dein Teenager respektvoll (meistens)?', 'Kann dein Teenager verschiedene Perspektiven einnehmen?'], tips: ['Respektvolle Kommunikation vorleben — auch in Konflikten', 'Fragen statt Vorwuerfe: "Was brauchst du?" statt "Warum machst du...?"']),
    DevDomain(id: 'denken', title: 'Zukunft & Orientierung', emoji: '\u{1F4A1}', color: Color(0xFFF59E0B), description: 'Berufsorientierung, Werte & eigene Ziele', questions: ['Hat dein Teenager Vorstellungen von der eigenen Zukunft?', 'Zeigt dein Teenager Eigeninitiative (Praktika, Projekte)?', 'Kann dein Teenager eigene Werte benennen?', 'Setzt sich dein Teenager eigene Ziele?', 'Kann dein Teenager komplexe Entscheidungen abwaegen?'], tips: ['Zukunftsplaene müssen nicht fest sein — Orientierung reicht', 'Praktische Erfahrungen ermoeglichen: Praktika, Nebenjobs, Ehrenamt']),
    DevDomain(id: 'sozial', title: 'Beziehungen & Identitaet', emoji: '\u{1F49C}', color: Color(0xFFEC4899), description: 'Partnerschaft, Identitaet & gesellschaftliche Rolle', questions: ['Pflegt dein Teenager gesunde Freundschaften?', 'Kann dein Teenager Nein sagen zu Gruppendruck?', 'Geht dein Teenager respektvoll mit Beziehungen um?', 'Zeigt dein Teenager ein stabiles Selbstbild?', 'Engagiert sich dein Teenager für etwas (sozial, politisch, kreativ)?'], tips: ['Identitaetsfindung braucht Raum — nicht jede Phase kommentieren', 'Beziehungen respektieren — auch wenn sie dir nicht gefallen']),
    DevDomain(id: 'selbst', title: 'Selbststaendigkeit & Reife', emoji: '\u{1F31F}', color: Color(0xFF8B5CF6), description: 'Lebenskompetenz, Finanzen & Verantwortung', questions: ['Kann dein Teenager eigenstaendig einen Haushalt fuehren (kochen, waschen)?', 'Geht dein Teenager verantwortungsvoll mit Geld um?', 'Kann dein Teenager Behoerdengaenge oder Arzttermine alleine machen?', 'Haelt dein Teenager Verpflichtungen zuverlaessig ein?', 'Ist dein Teenager bereit für ein zunehmend eigenstaendiges Leben?'], tips: ['Lebenskompetenzen aktiv lehren: Kochen, Steuererklärung, Waschmaschine', 'Loslassen ueben — für euch beide']),
  ];
}
