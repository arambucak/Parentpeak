import 'package:parentpeak/models/eltern_wissen_faq.dart';

/// 30 GfK-basierte Kern-Fragen für Eltern, sortiert nach Alter.
/// Basierend auf: Gewaltfreie Kommunikation (Rosenberg), Jesper Juul,
/// Attachment Parenting. Keine Bewertung, keine Strafen, bedürfnisorientiert.
const List<ElternWissenEntry> elternWissenData = [
  // ═══════════════════════════════════════════════════════════════════════════
  // BABY (0-1 Jahr)
  // ═══════════════════════════════════════════════════════════════════════════
  ElternWissenEntry(
    id: 'baby_01',
    question: 'Mein Baby weint und ich weiss nicht warum',
    akut: 'Nimm dein Baby hoch, halte es nah. Deine Ruhe ist seine Sicherheit.',
    bedürfnis:
        'Babys weinen um zu kommunizieren. Es hat ein unerfuelltes Bedürfnis: Hunger, Naehe, Reizueberflutung, Muedigkeit oder Schmerz.',
    gfkSatz:
        'Ich bin da. Ich hoere dich. Wir finden zusammen raus was du brauchst.',
    aktion: [
      'Koerperkontakt herstellen (Haut auf Haut)',
      'Grundbedürfnisse durchgehen: Hunger? Windel? Muede?',
      'Reize reduzieren: leiser, dunkler, ruhiger'
    ],
    ermutigung:
        'Du musst nicht sofort wissen was es braucht. Deine Anwesenheit ist schon die halbe Loesung.',
    minAge: 0,
    maxAge: 1,
    tags: [
      'weinen',
      'schreien',
      'baby',
      'unruhig',
      'nicht aufhoeren',
      'schreibaby'
    ],
    category: 'grundbedürfnisse',
  ),
  ElternWissenEntry(
    id: 'baby_02',
    question: 'Mein Baby schlaeft nicht ein',
    akut:
        'Bleib ruhig. Dein Baby spuert deine Anspannung. Atme langsam und halte es.',
    bedürfnis:
        'Babys brauchen Co-Regulation. Sie können sich noch nicht selbst beruhigen — dein Nervensystem ist ihr Anker.',
    gfkSatz: 'Du bist sicher. Ich bin hier. Dein Koerper darf jetzt ruhen.',
    aktion: [
      'Routinen schaffen: gleicher Ablauf jeden Abend',
      'Reize 30 Min vor dem Schlafen reduzieren',
      'Koerpernaehe anbieten (tragen, wiegen, stillen)'
    ],
    ermutigung:
        'Schlaf ist ein Entwicklungsprozess, kein Trainingsergebnis. Es wird besser.',
    minAge: 0,
    maxAge: 1,
    tags: [
      'schlafen',
      'einschlafen',
      'wach',
      'nacht',
      'durchschlafen',
      'muede'
    ],
    category: 'schlafen',
  ),
  ElternWissenEntry(
    id: 'baby_03',
    question: 'Mein Baby will nur zu mir und nicht zum anderen Elternteil',
    akut:
        'Das ist normal und gesund. Dein Baby zeigt sichere Bindung — keine Ablehnung.',
    bedürfnis:
        'Babys bauen primaere Bindung oft zuerst zu einer Person auf. Das zweite Elternteil braucht eigene Rituale und Zeit.',
    gfkSatz: 'Du liebst uns beide. Gerade brauchst du mich — und das ist okay.',
    aktion: [
      'Dem anderen Elternteil eigene Kuschelzeiten ohne Konkurrenz geben',
      'Nicht erzwingen — Vertrauen waechst durch positive Erfahrungen',
      'Kurze allein-Zeiten (5 Min) langsam steigern'
    ],
    ermutigung:
        'Das ist eine Phase die zeigt: Bindung funktioniert. Beide Elternteile sind wichtig.',
    minAge: 0,
    maxAge: 2,
    tags: ['mama', 'papa', 'klammern', 'fremdeln', 'nur zu mir', 'ablehnung'],
    category: 'bindung',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // KLEINKIND (1-3 Jahre)
  // ═══════════════════════════════════════════════════════════════════════════
  ElternWissenEntry(
    id: 'klein_01',
    question: 'Mein Kind haut andere Kinder',
    akut:
        'Ruhig dazugehen. Nicht schreien. Sage: Stopp, ich lasse nicht zu dass du haust.',
    bedürfnis:
        'Dein Kind ist nicht boese. Es hat starke Gefühle (Frust, Ueberforderung) und noch keine Worte dafuer. Hauen ist Kommunikation.',
    gfkSatz:
        'Ich sehe du bist wuetend. Hauen tut weh. Komm, wir finden zusammen raus was du brauchst.',
    aktion: [
      'Sofort ruhig dazugehen, das andere Kind troesten',
      'Später: Alternativen anbieten (stampfen, Kissen boxen)',
      'Ausloeser erkennen: Muedigkeit? Hunger? Ueberreizung?'
    ],
    ermutigung:
        'Das ist eine Phase. Dein Kind lernt gerade Impulskontrolle — das dauert bis 4-5 Jahre.',
    minAge: 1,
    maxAge: 4,
    tags: [
      'hauen',
      'schlagen',
      'aggressiv',
      'beissen',
      'kratzen',
      'wut',
      'gewalt',
      'andere kinder'
    ],
    category: 'wut',
  ),
  ElternWissenEntry(
    id: 'klein_02',
    question: 'Mein Kind bekommt Wutanfaelle',
    akut:
        'Bleib in der Naehe. Sage nichts. Lass den Sturm vorbeiziehen. Dein Kind braucht dich DANACH.',
    bedürfnis:
        'Wutanfaelle sind neurologisch: Das Grosshirn ist noch nicht reif genug um Gefühle zu regulieren. Dein Kind wird geflutet und braucht Co-Regulation.',
    gfkSatz:
        'Du darfst wuetend sein. Ich bin hier. Wenn du fertig bist, halte ich dich.',
    aktion: [
      'Sicherheit gewaehrleisten (nichts werfen lassen das verletzt)',
      'Nicht argumentieren, nicht schimpfen, nicht weggehen',
      'Nach dem Anfall: Koerperkontakt anbieten, nicht moralisieren'
    ],
    ermutigung:
        'Du bist nicht schuld. Wutanfaelle sind entwicklungsgerecht und KEIN Zeichen schlechter Erziehung.',
    minAge: 1,
    maxAge: 5,
    tags: [
      'wutanfall',
      'trotz',
      'trotzphase',
      'schreien',
      'toben',
      'werfen',
      'bocken',
      'ausrasten'
    ],
    category: 'wut',
  ),
  ElternWissenEntry(
    id: 'klein_03',
    question: 'Mein Kind will nicht teilen',
    akut:
        'Nicht zwingen. Teilen ist eine Faehigkeit die REIFT — sie kann nicht erzwungen werden.',
    bedürfnis:
        'Kinder unter 3-4 verstehen Besitz anders als Erwachsene. Teilen erfordert Empathie — die entwickelt sich erst.',
    gfkSatz:
        'Das ist deins. Du darfst entscheiden wann du es abgeben möchtest.',
    aktion: [
      'Nicht beschaemen (kein "Sei nicht so egoistisch!")',
      'Vorbild sein: Selbst laut teilen ("Möchtest du von meinem Apfel?")',
      'Lieblingsspielzeug VOR dem Besuch weglegen (reduziert Stress)'
    ],
    ermutigung:
        'Ein Kind das sich sicher fühlt in seinem Besitz wird freiwillig grosszuegig.',
    minAge: 1,
    maxAge: 4,
    tags: [
      'teilen',
      'meins',
      'wegnehmen',
      'egoistisch',
      'streit',
      'spielzeug',
      'abgeben'
    ],
    category: 'sozial',
  ),
  ElternWissenEntry(
    id: 'klein_04',
    question: 'Mein Kind sagt zu allem Nein',
    akut:
        'Das ist gesund! Dein Kind entdeckt gerade: Ich bin ein eigener Mensch mit eigenem Willen.',
    bedürfnis:
        'Autonomie ist ein Grundbedürfnis. "Nein" sagen ist die erste Form von Selbstbestimmung.',
    gfkSatz:
        'Ich hoere dein Nein. Manche Dinge müssen trotzdem sein — lass uns schauen wie.',
    aktion: [
      'Wahlmöglichkeiten geben statt Befehle ("Rote oder blaue Jacke?")',
      'Unnoetige Machtkampfe vermeiden (muss es WIRKLICH jetzt sein?)',
      'Das Nein respektieren wo möglich — staerkt Selbstvertrauen'
    ],
    ermutigung:
        'Ein Kind das Nein sagen darf zuhause kann später auch Nein sagen zu Fremden.',
    minAge: 1,
    maxAge: 3,
    tags: [
      'nein',
      'autonomie',
      'trotz',
      'will nicht',
      'verweigert',
      'sturr',
      'eigensinnig'
    ],
    category: 'grenzen',
  ),
  ElternWissenEntry(
    id: 'klein_05',
    question: 'Mein Kind will nicht essen',
    akut:
        'Kein Druck. Kein Zwang. Kein Ablenkfuettern. Vertraue: Kein Kind hungert freiwillig.',
    bedürfnis:
        'Essen ist ein Autonomie-Feld. Kinder regulieren ihren Hunger selbst — Druck erzeugt Gegendruck.',
    gfkSatz:
        'Dein Bauch weiss wann er Hunger hat. Das Essen steht hier wenn du magst.',
    aktion: [
      'Gemeinsam am Tisch sitzen (ohne Zwang zu essen)',
      'Immer mindestens 1 bekanntes Lebensmittel anbieten',
      'Neue Sachen 10-15x anbieten ohne Kommentar'
    ],
    ermutigung:
        'Picky Eating ist normal und geht vorbei. Dein Kind bekommt genug — auch wenn es sich nicht so anfühlt.',
    minAge: 1,
    maxAge: 6,
    tags: [
      'essen',
      'picky eater',
      'verweigert',
      'hunger',
      'wählerisch',
      'nichts essen',
      'gemuese'
    ],
    category: 'essen',
  ),
  ElternWissenEntry(
    id: 'klein_06',
    question: 'Wie hoere ich auf zu schreien wenn ich wuetend bin',
    akut:
        'Geh einen Schritt zurück. Atme. Du darfst den Raum kurz verlassen (Kind muss sicher sein).',
    bedürfnis:
        'Auch DEINE Gefühle sind real und wichtig. Schreien ist ein Zeichen DEINER Ueberlastung — nicht deines Versagens.',
    gfkSatz:
        'Ich merke ich bin gerade ueberfordert. Ich brauche kurz eine Pause um ruhig zu werden.',
    aktion: [
      'Erkenne deine Warnsignale (Kiefer, Schultern, Hitze)',
      'Sag laut: "Ich brauche kurz Pause" (modelliert Selbstregulation)',
      'Danach: Reparieren ("Es tut mir leid dass ich laut wurde")'
    ],
    ermutigung:
        'Dass du diese Frage stellst zeigt: Du bist ein reflektierter Elternteil. Perfekt muss niemand sein.',
    minAge: 0,
    maxAge: 18,
    tags: [
      'schreien',
      'bruellen',
      'wut eltern',
      'ueberfordert',
      'genervt',
      'geduld',
      'verliere nerven'
    ],
    category: 'selbstfuersorge',
  ),

  ElternWissenEntry(
    id: 'klein_07',
    question: 'Mein Kind will nicht in die Kita',
    akut:
        'Nimm den Schmerz ernst. Sage: Ich verstehe dass du lieber bei mir bleibst. Ich hole dich nachher ab.',
    bedürfnis:
        'Trennungsangst ist ein Zeichen sicherer Bindung. Dein Kind vermisst dich — das ist GESUND.',
    gfkSatz:
        'Ich sehe du bist traurig. Du möchtest bei mir bleiben. Ich komme nach dem Mittagessen zurück.',
    aktion: [
      'Abschiedsritual entwickeln (immer gleich, kurz, liebevoll)',
      'Nie heimlich weggehen — das zerstoert Vertrauen',
      'Ein Übergangsobjekt mitgeben (dein Schal, ein Foto)'
    ],
    ermutigung:
        'Eingewoehnung braucht Zeit. Wochen, manchmal Monate. Das ist kein Rueckschritt.',
    minAge: 1,
    maxAge: 5,
    tags: [
      'kita',
      'kindergarten',
      'trennung',
      'weinen',
      'abschied',
      'eingewoehnung',
      'angst'
    ],
    category: 'trennung',
  ),
  ElternWissenEntry(
    id: 'klein_08',
    question: 'Mein Kind ist auf das neue Geschwisterchen eifersuetig',
    akut:
        'Nicht vergleichen. Nicht sagen "Du bist doch schon gross". Dein aelteres Kind trauert — um geteilte Aufmerksamkeit.',
    bedürfnis:
        'Eifersucht ist Verlustangst: Liebt ihr mich noch genauso? Bin ich noch wichtig?',
    gfkSatz:
        'Du bist genauso wichtig wie vorher. Es ist okay dass du gerade traurig oder wuetend bist.',
    aktion: [
      'Exklusive Mama/Papa-Zeit NUR für das aeltere Kind (10 Min/Tag reicht)',
      'Aelteres Kind in Baby-Pflege einbeziehen (Windel bringen, singen)',
      'Gefühle benennen ohne zu bewerten: "Du bist sauer auf das Baby — das verstehe ich"'
    ],
    ermutigung:
        'Geschwister-Liebe waechst nicht sofort. Gib dem aelteren Kind Zeit und Sicherheit.',
    minAge: 1,
    maxAge: 6,
    tags: [
      'geschwister',
      'eifersucht',
      'baby',
      'neues kind',
      'neidisch',
      'aufmerksamkeit',
      'regression'
    ],
    category: 'geschwister',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // KITA-KIND (3-6 Jahre)
  // ═══════════════════════════════════════════════════════════════════════════
  ElternWissenEntry(
    id: 'kita_01',
    question: 'Mein Kind luegt',
    akut:
        'Nicht bestrafen. Nicht beschaemen. Kinder unter 6 "luegen" oft aus Fantasie, Angst oder Wunschdenken.',
    bedürfnis:
        'Kinder luegen wenn die Wahrheit sich gefaehrlich anfühlt. Frage dich: Fühlt mein Kind sich sicher genug um ehrlich zu sein?',
    gfkSatz:
        'Ich möchte verstehen was passiert ist. Du bekommst keinen Aerger — erzaehl mir deine Version.',
    aktion: [
      'Sicherheit schaffen: Ehrlichkeit NICHT bestrafen',
      'Zwischen Fantasie-Luege (normal, 3-5 J.) und Schutz-Luege (Angst) unterscheiden',
      'Vorbild: Selbst ehrlich sein, auch wenn es unangenehm ist'
    ],
    ermutigung:
        'Kinder die in Sicherheit ehrlich sein duerfen werden ehrliche Erwachsene.',
    minAge: 3,
    maxAge: 10,
    tags: [
      'luegen',
      'unehrlich',
      'flunkern',
      'fantasie',
      'wahrheit',
      'schwindeln'
    ],
    category: 'grenzen',
  ),
  ElternWissenEntry(
    id: 'kita_02',
    question: 'Mein Kind hat Angst im Dunkeln',
    akut:
        'Die Angst ist real. Nicht kleinreden. Sage: Ich glaube dir. Lass uns schauen wie du dich sicher fuehlst.',
    bedürfnis:
        'Angst im Dunkeln ist entwicklungsgerecht (3-8 Jahre). Das Gehirn kann jetzt Gefahren VORSTELLEN — das ist ein kognitiver Fortschritt.',
    gfkSatz:
        'Ich sehe du hast Angst. Die Dunkelheit fühlt sich unheimlich an. Ich bin im Nebenzimmer — du bist sicher.',
    aktion: [
      'Nachtlicht (gibt Kontrolle zurück)',
      'Monster-Spray (Wasser in Spruehflasche — Kind sprueht selbst)',
      'Kuscheltier als Beschuetzer einsetzen ("Der Baer passt auf dich auf")'
    ],
    ermutigung:
        'Dein Kind hat keine Stoerung. Es hat Fantasie. Das ist eine Stärke.',
    minAge: 3,
    maxAge: 8,
    tags: [
      'angst',
      'dunkel',
      'monster',
      'nacht',
      'alleine',
      'fuerchten',
      'albtraum'
    ],
    category: 'aengste',
  ),
  ElternWissenEntry(
    id: 'kita_03',
    question: 'Mein Kind will immer bestimmen beim Spielen',
    akut:
        'Das ist normal bei 4-6 Jaehrigen. Sie ueben gerade Fuehrung — ohne soziale Feinheiten.',
    bedürfnis:
        'Dein Kind braucht Selbstwirksamkeit. Es will erleben: Meine Ideen zählen.',
    gfkSatz:
        'Du hast tolle Ideen. Dein Freund hat auch welche. Wie waere es wenn ihr abwechselt?',
    aktion: [
      'Nicht sofort eingreifen — Kinder loesen mehr als wir denken',
      'Wenn noetig: Rollenwechsel vorschlagen, nicht befehlen',
      'Zuhause: Situationen schaffen wo das Kind fuehren DARF (Spielleiter)'
    ],
    ermutigung:
        'Bestimmen-wollen ist Fuehrungspotential. Das wird später eine Stärke.',
    minAge: 3,
    maxAge: 7,
    tags: [
      'bestimmen',
      'chef',
      'dominant',
      'spielen',
      'freunde',
      'streit',
      'egozentrisch'
    ],
    category: 'sozial',
  ),
  ElternWissenEntry(
    id: 'kita_04',
    question: 'Mein Kind macht immer noch ins Bett',
    akut:
        'Kein Schimpfen. Kein Beschaemen. Bettnassen ist NICHT Faulheit — es ist unreife Blasenkontrolle.',
    bedürfnis:
        'Der Koerper deines Kindes ist noch nicht so weit. Das Anti-Diuretische Hormon reift bei manchen Kindern erst mit 6-7.',
    gfkSatz:
        'Das ist nicht deine Schuld. Dein Koerper lernt noch. Wir finden eine Loesung zusammen.',
    aktion: [
      'Wasserdichte Unterlage (ohne Drama)',
      'Gemeinsam Bett neu beziehen (Kind einbeziehen, nicht bestrafen)',
      'Bei Sorge: Kinderarzt konsultieren ab 7 Jahren'
    ],
    ermutigung:
        'Fast 15% aller 5-Jaehrigen naessen noch ein. Dein Kind ist nicht allein.',
    minAge: 3,
    maxAge: 8,
    tags: [
      'bettnassen',
      'einnassen',
      'windel',
      'nacht',
      'trocken werden',
      'pipi'
    ],
    category: 'koerper',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // GRUNDSCHULKIND (6-10 Jahre)
  // ═══════════════════════════════════════════════════════════════════════════
  ElternWissenEntry(
    id: 'grund_01',
    question: 'Mein Kind will keine Hausaufgaben machen',
    akut:
        'Nicht kaempfen. Sage: Ich sehe du hast keine Lust. Was brauchst du um anzufangen?',
    bedürfnis:
        'Hausaufgaben-Verweigerung ist selten Faulheit. Oft steckt dahinter: Ueberforderung, Langeweile, Erschoepfung nach dem Schultag.',
    gfkSatz:
        'Ich merke die Aufgaben fühlen sich anstrengend an. Wollen wir zusammen schauen wo es hakt?',
    aktion: [
      '30 Min Pause nach der Schule (Bewegen, Snack, Ruhe)',
      'Kleine Portionen (5 Min fokussiert, dann Pause)',
      'Keine Drohungen — sondern Unterstuetzung: "Ich helfe dir beim Start"'
    ],
    ermutigung:
        'Motivation kommt durch Erfolg, nicht durch Druck. Kleine Schritte reichen.',
    minAge: 6,
    maxAge: 12,
    tags: [
      'hausaufgaben',
      'schule',
      'lernen',
      'keine lust',
      'verweigern',
      'faul',
      'schulstress'
    ],
    category: 'schule',
  ),
  ElternWissenEntry(
    id: 'grund_02',
    question: 'Mein Kind wird in der Schule ausgegrenzt',
    akut:
        'Hoere zu. Glaube deinem Kind. Sage: Das tut mir leid. Du verdienst Freunde die nett zu dir sind.',
    bedürfnis:
        'Zugehörigkeit ist ein Grundbedürfnis. Ausgrenzung schmerzt Kinder koerperlich — das Gehirn verarbeitet es wie physischen Schmerz.',
    gfkSatz:
        'Ich hoere dass dich das sehr traurig macht. Du bist liebenswert — egal was andere sagen.',
    aktion: [
      'Nicht sofort "loesen wollen" — erstmal Gefühle anerkennen',
      'Fragen: Was wuenscht du dir? (Manche wollen Hilfe, manche nur Zuhören)',
      'Bei Mobbing: Schule informieren (Klassenleitung)'
    ],
    ermutigung:
        'Dein Kind braucht nicht viele Freunde. Ein einziger guter Freund reicht für gesunde Entwicklung.',
    minAge: 5,
    maxAge: 14,
    tags: [
      'mobbing',
      'ausgrenzen',
      'keine freunde',
      'einsam',
      'schule',
      'haenseln',
      'aussen vor'
    ],
    category: 'sozial',
  ),
  ElternWissenEntry(
    id: 'grund_03',
    question: 'Mein Kind verbringt zu viel Zeit am Bildschirm',
    akut:
        'Nicht im Konflikt-Moment das Geraet wegnehmen. Kuendige Übergänge an: "Noch 5 Minuten, dann ist Schluss."',
    bedürfnis:
        'Bildschirme befriedigen Bedürfnisse: Langeweile, soziale Zugehörigkeit, Stimulation. Frage: Was braucht mein Kind STATTDESSEN?',
    gfkSatz:
        'Ich sehe du magst das Spiel. Unsere Regel ist 30 Minuten. Was möchtest du danach machen?',
    aktion: [
      'Klare Regeln VORHER vereinbaren (nicht im Moment)',
      'Alternativen anbieten die gleich attraktiv sind (nicht "Geh raus spielen")',
      'Eigenes Vorbild: Wie oft schaust DU aufs Handy?'
    ],
    ermutigung:
        'Du bist kein schlechter Elternteil weil dein Kind Bildschirmzeit hat. Balance ist das Ziel.',
    minAge: 4,
    maxAge: 16,
    tags: [
      'bildschirm',
      'handy',
      'tablet',
      'medien',
      'zocken',
      'fernsehen',
      'medienzeit',
      'sucht'
    ],
    category: 'medien',
  ),
  ElternWissenEntry(
    id: 'grund_04',
    question: 'Mein Kind hat Pruefungsangst',
    akut:
        'Normalisiere: Aufregung vor Pruefungen ist menschlich. Sage: Dein Wert haengt nicht von einer Note ab.',
    bedürfnis:
        'Pruefungsangst entsteht wenn Leistung mit Liebe verknuepft wird: "Wenn ich schlecht bin, bin ich nicht gut genug."',
    gfkSatz:
        'Ich liebe dich genauso — egal welche Note da steht. Du bist mehr als eine Zahl.',
    aktion: [
      'Nicht fragen "Hast du genug gelernt?" — sondern "Wie geht es dir damit?"',
      'Entspannungsuebung zeigen (4-7-8 Atmung)',
      'Nach der Pruefung: NIE zuerst nach der Note fragen'
    ],
    ermutigung:
        'Kinder die wissen dass sie bedingungslos geliebt werden haben weniger Angst.',
    minAge: 6,
    maxAge: 16,
    tags: [
      'pruefung',
      'angst',
      'klassenarbeit',
      'note',
      'druck',
      'versagen',
      'leistung',
      'stress'
    ],
    category: 'schule',
  ),
  ElternWissenEntry(
    id: 'grund_05',
    question: 'Mein Kind sagt es hasst mich',
    akut:
        'Das tut weh. Aber dein Kind meint: Ich bin gerade so wuetend dass ich nicht weiss wohin damit.',
    bedürfnis:
        'Kinder testen ob die Beziehung haelt — auch wenn sie das Schlimmste sagen. Dein Kind braucht die Erfahrung: Du gehst nicht weg.',
    gfkSatz:
        'Ich hoere dass du gerade sehr wuetend bist. Ich liebe dich — auch wenn du sauer auf mich bist.',
    aktion: [
      'Nicht kontern ("Dann geh doch!")',
      'Nicht beleidigt weggehen',
      'Später ansprechen: "Das hat mich verletzt. Was hat dich so wuetend gemacht?"'
    ],
    ermutigung:
        'Ein Kind das dir sagt was es fühlt (auch haesslich) vertraut dir. Das ist Beziehung.',
    minAge: 4,
    maxAge: 14,
    tags: [
      'hassen',
      'ich hasse dich',
      'boese worte',
      'beleidigen',
      'ablehnung',
      'verletzend'
    ],
    category: 'wut',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // TEENAGER (10-16 Jahre)
  // ═══════════════════════════════════════════════════════════════════════════
  ElternWissenEntry(
    id: 'teen_01',
    question: 'Mein Teenager redet nicht mehr mit mir',
    akut:
        'Nicht draengen. Nicht beleidigt sein. Anwesenheit zeigen ohne Erwartung. Verfügbar sein.',
    bedürfnis:
        'Teenager brauchen Abgrenzung um Identitaet zu bilden. Rueckzug ist keine Ablehnung sondern Entwicklung.',
    gfkSatz:
        'Ich bin da wenn du reden möchtest. Kein Druck. Ich frage nicht — aber ich hoere zu wenn du kommst.',
    aktion: [
      'Gemeinsame Aktivitaeten anbieten OHNE Gespraechsdruck (zusammen kochen, Auto fahren)',
      'Nicht jedes Schweigen fuellen',
      'Eigene Gefühle teilen: "Ich vermisse unsere Gespraeche manchmal"'
    ],
    ermutigung:
        'Dein Teenager liebt dich. Er braucht gerade Raum. Halte die Tuer offen — er kommt zurück.',
    minAge: 10,
    maxAge: 18,
    tags: [
      'teenager',
      'schweigen',
      'zurückziehen',
      'reden',
      'pubertaet',
      'zimmer',
      'kontakt'
    ],
    category: 'pubertaet',
  ),
  ElternWissenEntry(
    id: 'teen_02',
    question: 'Mein Teenager haelt sich an keine Regeln',
    akut:
        'Weniger Regeln, dafür klarere. Frage dich: Welche 3 Regeln sind WIRKLICH wichtig?',
    bedürfnis:
        'Teenager brauchen wachsende Autonomie. Zu viele Regeln werden als Kontrolle erlebt — und Kontrolle erzeugt Widerstand.',
    gfkSatz:
        'Ich mache mir Sorgen weil du um 23 Uhr nicht zuhause warst. Mir ist deine Sicherheit wichtig — nicht Kontrolle.',
    aktion: [
      'Regeln GEMEINSAM verhandeln (nicht diktieren)',
      'Konsequenzen vorher besprechen (nicht im Affekt)',
      'Unterscheiden: Was ist Sicherheit (nicht verhandelbar) vs. Geschmack (verhandelbar)?'
    ],
    ermutigung:
        'Teenager die Regeln brechen werden nicht kriminell. Sie werden erwachsen.',
    minAge: 11,
    maxAge: 18,
    tags: [
      'regeln',
      'grenzen',
      'pubertaet',
      'respektlos',
      'nicht hoeren',
      'spat kommen',
      'verbot'
    ],
    category: 'pubertaet',
  ),
  ElternWissenEntry(
    id: 'teen_03',
    question: 'Ich mache mir Sorgen um das Selbstbild meines Teenagers',
    akut:
        'Hoere zu ohne zu relativieren. Nicht: "Du bist doch huebsch!" Sondern: "Erzaehl mir mehr."',
    bedürfnis:
        'In der Pubertaet ist das Selbstbild fragil. Social Media verstaerkt Vergleiche. Dein Kind braucht Ankerworte die NICHT aeusseres bewerten.',
    gfkSatz:
        'Du bist wertvoll — nicht wegen deines Aussehens sondern wegen dem wer du bist.',
    aktion: [
      'Koerper nie kommentieren (auch nicht positiv!)',
      'Stärken benennen die nichts mit Aussehen zu tun haben',
      'Eigenes Vorbild: Wie sprichst DU ueber deinen Koerper?'
    ],
    ermutigung:
        'Deine Stimme wird zur inneren Stimme deines Kindes. Mach sie liebevoll.',
    minAge: 10,
    maxAge: 18,
    tags: [
      'selbstbild',
      'koerper',
      'aussehen',
      'selbstwert',
      'social media',
      'vergleich',
      'unsicher'
    ],
    category: 'selbstwert',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // ALLGEMEIN (alle Alter)
  // ═══════════════════════════════════════════════════════════════════════════
  ElternWissenEntry(
    id: 'allg_01',
    question: 'Wie setze ich Grenzen ohne zu strafen',
    akut:
        'Grenze = was DU brauchst, nicht was das Kind falsch macht. "Mir ist wichtig dass..." statt "Du darfst nicht!"',
    bedürfnis:
        'Kinder brauchen Grenzen — aber liebevolle. Grenzen geben Orientierung, Strafen erzeugen Angst.',
    gfkSatz:
        'Ich lasse nicht zu dass du mich schlägst. Nicht weil du boese bist — sondern weil mir mein Koerper wichtig ist.',
    aktion: [
      'Grenzen als ICH-Aussage formulieren (nicht DU-Vorwurf)',
      'Konsequenzen statt Strafen (natuerlich, nicht willkuerlich)',
      'Grenze setzen UND Gefühl anerkennen ("Du bist sauer UND wir gehen jetzt")'
    ],
    ermutigung: 'Grenzen setzen IST Liebe. Dein Kind braucht deine Fuehrung.',
    minAge: 0,
    maxAge: 18,
    tags: [
      'grenzen',
      'strafen',
      'konsequenzen',
      'nein sagen',
      'durchsetzen',
      'autoritaet',
      'fuehrung'
    ],
    category: 'grenzen',
  ),
  ElternWissenEntry(
    id: 'allg_02',
    question: 'Ich fuehle mich als schlechter Elternteil',
    akut:
        'Du bist hier. Du suchst nach Antworten. Das ist das Gegenteil von schlecht.',
    bedürfnis:
        'Eltern-Schuld ist allgegenwaertig. Social Media zeigt perfekte Familien — die es nicht gibt. Dein Gefühl ist menschlich.',
    gfkSatz:
        'Ich bin gut genug. Mein Kind braucht nicht perfekt — es braucht echt.',
    aktion: [
      'Vergleiche reduzieren (Social Media limitieren)',
      'Sich Hilfe holen ist Stärke (Beratung, Austausch, Entlastung)',
      'Täglich 1 Sache benennen die gut gelaufen ist'
    ],
    ermutigung:
        'Perfekte Eltern gibt es nicht. Gute Eltern sind die die es immer wieder versuchen.',
    minAge: 0,
    maxAge: 18,
    tags: [
      'schuld',
      'versagen',
      'schlecht',
      'nicht gut genug',
      'ueberfordert',
      'burn out',
      'muede'
    ],
    category: 'selbstfuersorge',
  ),
  ElternWissenEntry(
    id: 'allg_03',
    question: 'Mein Kind hört nicht auf mich',
    akut:
        'Kinder "hoeren" wenn sie sich gehört FUEHLEN. Geh auf Augenhoehe. Beruehre die Schulter. Dann sprich.',
    bedürfnis:
        'Nicht-Hoeren ist selten Respektlosigkeit. Oft: Das Kind ist vertieft, ueberreizt, oder die Bitte war zu komplex.',
    gfkSatz:
        'Hey, ich brauche kurz deine Aufmerksamkeit. Schau mich an — ich möchte dir was sagen.',
    aktion: [
      'Naeher kommen statt quer durch den Raum rufen',
      'Kurze klare Saetze (nicht "Raeumst du bitte irgendwann mal...")',
      'Vorwarnen: "In 5 Minuten gehen wir — mach dich bereit"'
    ],
    ermutigung:
        'Kinder die auf Augenhoehe angesprochen werden kooperieren 80% besser.',
    minAge: 1,
    maxAge: 12,
    tags: [
      'hoeren',
      'ignorieren',
      'nicht reagieren',
      'kooperation',
      'stur',
      'trotzig',
      'gehorchen'
    ],
    category: 'grenzen',
  ),
  ElternWissenEntry(
    id: 'allg_04',
    question: 'Wie erkläre ich meinem Kind eine Trennung',
    akut:
        'Gemeinsam erzählen wenn möglich. Kern-Botschaft: Du bist nicht schuld. Wir haben dich beide lieb.',
    bedürfnis:
        'Kinder brauchen: Sicherheit ("Wo werde ich wohnen?"), Liebe ("Haben mich beide noch lieb?"), Vorhersagbarkeit ("Was aendert sich?").',
    gfkSatz:
        'Mama und Papa haben sich entschieden getrennt zu wohnen. Das hat nichts mit dir zu tun. Wir haben dich beide genauso lieb.',
    aktion: [
      'Altersgerecht: Einfache Worte, wenig Details ueber Gruende',
      'Konkret: Was bleibt gleich? (Schule, Freunde, Kuscheltier)',
      'Gefühle erlauben: "Du darfst traurig und wuetend sein"'
    ],
    ermutigung:
        'Kinder verkraften Trennungen — wenn die Eltern respektvoll miteinander umgehen.',
    minAge: 2,
    maxAge: 16,
    tags: [
      'trennung',
      'scheidung',
      'papa weg',
      'mama weg',
      'getrennt',
      'zwei zuhause'
    ],
    category: 'familie',
  ),
  ElternWissenEntry(
    id: 'allg_05',
    question: 'Wie stärke ich das Selbstvertrauen meines Kindes',
    akut:
        'Nicht loben WAS es tut ("Toll gemalt!") — sondern WIE es das erlebt ("Du bist richtig stolz auf dein Bild!").',
    bedürfnis:
        'Selbstvertrauen entsteht durch: Selbstwirksamkeit (Ich KANN was), Zugehörigkeit (Ich GEHOERE dazu), Autonomie (Ich DARF entscheiden).',
    gfkSatz:
        'Ich sehe wie sehr du dich angestrengt hast. Wie fühlt sich das für dich an?',
    aktion: [
      'Kind Dinge SELBST machen lassen (auch wenn es laenger dauert)',
      'Prozess loben statt Ergebnis ("Du hast nicht aufgegeben — das war mutig")',
      'Fehler normalisieren: "Ups! Was könnten wir naechstes Mal anders machen?"'
    ],
    ermutigung:
        'Selbstvertrauen waechst durch Erfahrung — nicht durch Worte. Lass dein Kind scheitern und wieder aufstehen.',
    minAge: 1,
    maxAge: 18,
    tags: [
      'selbstvertrauen',
      'stärken',
      'loben',
      'mut',
      'unsicher',
      'schuechtern',
      'traut sich nicht'
    ],
    category: 'selbstwert',
  ),
  ElternWissenEntry(
    id: 'allg_06',
    question: 'Mein Kind hat Angst vor der Schule',
    akut:
        'Nimm die Angst ernst. Nicht: "Stell dich nicht an." Sondern: "Erzaehl mir was dich beschaeftigt."',
    bedürfnis:
        'Schulangst kann viele Ursachen haben: soziale Konflikte, Ueberforderung, Lehrerperson, Leistungsdruck.',
    gfkSatz:
        'Ich hoere dass die Schule sich gerade schwer anfühlt. Wir finden zusammen eine Loesung.',
    aktion: [
      'Genau nachfragen: WAS macht Angst? (Fach? Person? Pause?)',
      'Lehrerin einbeziehen (ohne Kind blosszustellen)',
      'Morgen-Ritual das Sicherheit gibt (fester Ablauf, Lieblings-Fruehstueck)'
    ],
    ermutigung:
        'Schulangst ist loesbar. Oft reichen kleine Veränderungen für grosse Erleichterung.',
    minAge: 5,
    maxAge: 14,
    tags: [
      'schulangst',
      'schule',
      'bauchschmerzen',
      'montag',
      'nicht hingehen',
      'weinen morgens'
    ],
    category: 'aengste',
  ),
  ElternWissenEntry(
    id: 'allg_07',
    question: 'Wie bringe ich mein Kind zum Zaehneputzen',
    akut:
        'Nicht kaempfen. Spielerisch: "Darf ich die Krokodil-Zaehne putzen?" oder "Wer findet den versteckten Zucker?"',
    bedürfnis:
        'Zaehneputzen ist ein Autonomie-Kampf (MunD = intimster Bereich). Dein Kind will selbst entscheiden.',
    gfkSatz:
        'Deine Zaehne brauchen Hilfe. Möchtest du zuerst selbst oder soll ich anfangen?',
    aktion: [
      'Wahlmöglichkeiten: Welche Zahnbuerste? Welches Lied dabei?',
      'Timer/Lied (2 Minuten Zaehneputz-Song)',
      'Nachputzen als Ritual, nicht als Machtkampf framen'
    ],
    ermutigung:
        'Irgendwann putzt jedes Kind freiwillig. Bis dahin: kreativ bleiben.',
    minAge: 1,
    maxAge: 6,
    tags: [
      'zaehneputzen',
      'zaehne',
      'mundpflege',
      'verweigern',
      'kaempfen',
      'abend'
    ],
    category: 'koerper',
  ),
  ElternWissenEntry(
    id: 'allg_08',
    question: 'Mein Kind schlaeft schlecht ein (Schulkind)',
    akut:
        'Abendroutine ist alles: Gleiche Zeit, gleiches Ritual, keine Bildschirme 45 Min vorher.',
    bedürfnis:
        'Schulkinder sind oft ueberreizt vom Tag. Ihr Kopf braucht Übergang von "aktiv" zu "ruhe".',
    gfkSatz:
        'Dein Koerper braucht Schlaf um morgen stark zu sein. Was hilft dir runterzukommen?',
    aktion: [
      'Feste Schlafenszeit (auch am Wochenende max. 1h abweichen)',
      'Routine: Bad/Zaehnef./Vorlesen/Kuscheln/Licht aus',
      'Sorgen-Zeit: 5 Min VOR dem Bett "Was beschaeftigt dich?"'
    ],
    ermutigung:
        'Schlaf-Probleme bei Schulkindern sind meist phasenbedingt (Wachstumsschub, Schulstress).',
    minAge: 5,
    maxAge: 12,
    tags: [
      'einschlafen',
      'schlafen',
      'wach',
      'abend',
      'muede aber wach',
      'gedanken',
      'sorgen'
    ],
    category: 'schlafen',
  ),
  ElternWissenEntry(
    id: 'allg_09',
    question: 'Meine Kinder streiten staendig',
    akut:
        'Nicht sofort Schiedsrichter spielen. Frage: Braucht ihr meine Hilfe oder schafft ihr das selbst?',
    bedürfnis:
        'Geschwister-Streit ist NORMAL und wichtig. Kinder lernen dabei: Verhandeln, Kompromiss, Perspektivwechsel.',
    gfkSatz:
        'Ich sehe ihr seid beide frustriert. Was braucht jeder von euch gerade?',
    aktion: [
      'Nur eingreifen wenn es koerperlich wird',
      'Keine Partei ergreifen ("Wer hat angefangen?" ist sinnlos)',
      'Jedem Kind sein Gefühl bestaetigen BEVOR Loesung gesucht wird'
    ],
    ermutigung:
        'Geschwister die streiten lernen Konfliktloesung. Das ist eine Lebenskompetenz.',
    minAge: 2,
    maxAge: 16,
    tags: [
      'geschwister',
      'streit',
      'streiten',
      'hauen',
      'schreien',
      'unfair',
      'petzen'
    ],
    category: 'geschwister',
  ),
];
