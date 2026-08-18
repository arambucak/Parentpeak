import 'package:parentpeak/models/benefit_application_data.dart';

/// Antragshelfer-Daten für Deutschland — Top 5 Sozialleistungen.
///
/// Quellen: Familienkasse, BMFSFJ, Wohngeldstelle.
/// Stand: 2026. Keine Rechtsberatung.
class BenefitApplicationDE {
  BenefitApplicationDE._();

  static const List<BenefitApplicationData> allBenefits = [
    kindergeld,
    kinderzuschlag,
    wohngeld,
    bildungTeilhabe,
    elterngeld,
    unterhaltsvorschuss,
    pflegegeld,
    eingliederungshilfe,
  ];

  static BenefitApplicationData? getById(String id) {
    for (final b in allBenefits) {
      if (b.benefitId == id) return b;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. KINDERGELD
  // ═══════════════════════════════════════════════════════════════════════════

  static const kindergeld = BenefitApplicationData(
    benefitId: 'kindergeld',
    benefitName: 'Kindergeld',
    emoji: '👶',
    countryCode: 'de',
    responsibleAuthority: 'Familienkasse der Bundesagentur für Arbeit',
    processingTime: '4–6 Wochen',
    renewalNote:
        'Kein Folgeantrag nötig. Wird automatisch bis zum 18. (bzw. 25.) Geburtstag gezahlt.',
    onlineApplicationUrl: 'https://web.arbeitsagentur.de/ofa/kindergeld/',
    proTip:
        'Antrag direkt nach der Geburt stellen — Kindergeld wird max. 6 Monate rückwirkend gezahlt.',
    aiTemplatePrompt:
        'Schreibe einen kurzen, freundlichen Begleitbrief für einen Kindergeldantrag. Elternteil beantragt erstmalig Kindergeld nach der Geburt. Halte es einfach und sachlich.',
    documents: [
      RequiredDocument(
        name: 'Geburtsurkunde des Kindes',
        whereToGet: 'Standesamt (bekommst du meist im Krankenhaus)',
      ),
      RequiredDocument(
        name: 'Steuer-ID des Kindes',
        whereToGet:
            'Kommt per Post vom Bundeszentralamt für Steuern (ca. 2–3 Wochen nach Geburt)',
      ),
      RequiredDocument(
        name: 'Steuer-ID des antragstellenden Elternteils',
        whereToGet: 'Steht auf deinem Steuerbescheid oder Lohnzettel',
      ),
      RequiredDocument(
        name: 'Personalausweis oder Reisepass (Kopie)',
      ),
      RequiredDocument(
        name: 'Bankverbindung (IBAN)',
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Online-Antrag ausfüllen',
        description:
            'Auf der Website der Familienkasse den Antrag "KG1" online ausfüllen. Dauert ca. 10 Minuten.',
        url: 'https://web.arbeitsagentur.de/ofa/kindergeld/',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Unterlagen hochladen oder per Post',
        description:
            'Geburtsurkunde und Steuer-IDs als Scan hochladen oder per Post an deine zuständige Familienkasse schicken.',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Bestätigung abwarten',
        description:
            'Du bekommst einen Bescheid per Post (4–6 Wochen). Die erste Auszahlung kommt danach monatlich.',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. KINDERZUSCHLAG (KiZ)
  // ═══════════════════════════════════════════════════════════════════════════

  static const kinderzuschlag = BenefitApplicationData(
    benefitId: 'kinderzuschlag',
    benefitName: 'Kinderzuschlag (KiZ)',
    emoji: '💶',
    countryCode: 'de',
    responsibleAuthority: 'Familienkasse der Bundesagentur für Arbeit',
    processingTime: '4–8 Wochen',
    renewalNote:
        'Muss alle 6 Monate neu beantragt werden (Weiterbewilligungsantrag).',
    onlineApplicationUrl: 'https://web.arbeitsagentur.de/ofa/kiz/',
    proTip:
        'Mit dem KiZ-Lotsen der Familienkasse kannst du in 2 Minuten prüfen ob du Anspruch hast — bevor du den vollen Antrag ausfüllst.',
    aiTemplatePrompt:
        'Schreibe eine kurze sachliche Begründung für einen Kinderzuschlag-Antrag. Die Familie hat ein geringes Einkommen und benötigt Unterstützung für die Kinder. Erwähne dass die Miete einen großen Teil des Einkommens ausmacht.',
    documents: [
      RequiredDocument(
        name: 'Einkommensnachweise der letzten 6 Monate',
        whereToGet:
            'Lohnzettel vom Arbeitgeber, Elterngeldbescheid, oder Steuerbescheid',
      ),
      RequiredDocument(
        name: 'Mietvertrag oder Wohnkostennachweis',
        whereToGet: 'Kopie deines Mietvertrags + letzte Nebenkostenabrechnung',
      ),
      RequiredDocument(
        name: 'Kontoauszüge der letzten 3 Monate',
        whereToGet: 'Online-Banking → PDF drucken',
        isOptional: true,
      ),
      RequiredDocument(
        name: 'Kindergeldbescheid',
        whereToGet: 'Hast du per Post von der Familienkasse bekommen',
      ),
      RequiredDocument(
        name: 'Geburtsurkunde(n) der Kinder',
      ),
      RequiredDocument(
        name: 'Personalausweis (Kopie)',
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'KiZ-Lotse nutzen (2 Min.)',
        description:
            'Prüfe mit dem Online-Lotsen ob du voraussichtlich Anspruch hast. Das spart dir Zeit falls nicht.',
        url: 'https://www.arbeitsagentur.de/familie-und-kinder/kiz-lotse',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Online-Antrag ausfüllen',
        description:
            'Antrag auf der Familienkasse-Website ausfüllen. Du brauchst Einkommensnachweise und Mietkosten griffbereit.',
        url: 'https://web.arbeitsagentur.de/ofa/kiz/',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Unterlagen einreichen',
        description:
            'Lohnzettel, Mietvertrag und Kontoauszüge hochladen oder per Post schicken.',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Bescheid + Weiterbewilligung',
        description:
            'Nach 4–8 Wochen kommt der Bescheid. Wichtig: Nach 6 Monaten den Weiterbewilligungsantrag nicht vergessen!',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. WOHNGELD
  // ═══════════════════════════════════════════════════════════════════════════

  static const wohngeld = BenefitApplicationData(
    benefitId: 'wohngeld',
    benefitName: 'Wohngeld',
    emoji: '🏠',
    countryCode: 'de',
    responsibleAuthority: 'Wohngeldstelle deiner Stadt/Gemeinde',
    processingTime: '3–8 Wochen (je nach Kommune)',
    renewalNote:
        'Bewilligungszeitraum: 12 Monate. Rechtzeitig Weiterleistungsantrag stellen (2 Monate vorher).',
    onlineApplicationUrl: null,
    proTip:
        'Seit der Wohngeld-Reform 2023 haben deutlich mehr Familien Anspruch — auch mit mittlerem Einkommen. Einfach mal prüfen!',
    aiTemplatePrompt:
        'Schreibe einen kurzen Begleitbrief für einen Wohngeldantrag. Eine Familie mit Kindern beantragt erstmalig Wohngeld weil die Miete einen großen Teil des Einkommens ausmacht. Sachlich und freundlich.',
    documents: [
      RequiredDocument(
        name: 'Einkommensnachweise aller Haushaltsmitglieder',
        whereToGet: 'Lohnzettel, Rentenbescheid, Elterngeldbescheid',
      ),
      RequiredDocument(
        name: 'Mietvertrag (Kopie)',
      ),
      RequiredDocument(
        name: 'Letzte Mietquittung oder Kontoauszug mit Mietzahlung',
      ),
      RequiredDocument(
        name: 'Nebenkostenabrechnung',
        whereToGet: 'Vom Vermieter (jährlich)',
      ),
      RequiredDocument(
        name: 'Personalausweise aller Haushaltsmitglieder (Kopie)',
      ),
      RequiredDocument(
        name: 'Meldebestätigung',
        whereToGet: 'Bürgeramt / Einwohnermeldeamt',
        isOptional: true,
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Wohngeldrechner nutzen',
        description:
            'Mit dem offiziellen Wohngeld-Plus-Rechner des BMWSB prüfen ob und wieviel Wohngeld dir zusteht.',
        url:
            'https://www.bmwsb.bund.de/Webs/BMWSB/DE/themen/stadt-wohnen/wohnraumfoerderung/wohngeld/wohngeldrechner-2025-artikel.html',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Antrag bei deiner Wohngeldstelle',
        description:
            'Den Antrag bekommst du bei deinem Rathaus/Bürgeramt oder als PDF online. Manche Kommunen bieten auch Online-Anträge an.',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Unterlagen beifügen',
        description:
            'Mietvertrag, Einkommensnachweise und Nebenkostenabrechnung beifügen. Im Zweifel lieber zu viel als zu wenig mitschicken.',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Bescheid abwarten + Erinnerung setzen',
        description:
            'Nach 3–8 Wochen kommt der Bescheid. Setze dir eine Erinnerung für den Weiterleistungsantrag (10 Monate nach Bewilligung).',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. BILDUNG UND TEILHABE (BuT)
  // ═══════════════════════════════════════════════════════════════════════════

  static const bildungTeilhabe = BenefitApplicationData(
    benefitId: 'but',
    benefitName: 'Bildung und Teilhabe (BuT)',
    emoji: '📚',
    countryCode: 'de',
    responsibleAuthority: 'Jobcenter oder Sozialamt deiner Stadt/Gemeinde',
    processingTime: '2–6 Wochen',
    renewalNote:
        'Pro Schuljahr neu beantragen (für Schulbedarf). Vereins-/Kurskosten: alle 6 Monate.',
    onlineApplicationUrl: null,
    proTip:
        'BuT deckt auch Schwimmkurse, Musikschule und Nachhilfe ab — nicht nur Schulbedarf! Bis 15€/Monat für Sport/Kultur/Freizeit.',
    aiTemplatePrompt:
        'Schreibe einen kurzen formlosen Antrag auf Leistungen für Bildung und Teilhabe. Ein Kind soll an einem Sportkurs teilnehmen. Die Familie bezieht Kinderzuschlag. Sachlich, 3-4 Sätze.',
    documents: [
      RequiredDocument(
        name: 'Nachweis über Leistungsbezug',
        whereToGet:
            'Bescheid über Kindergeldzuschlag, Wohngeld, Bürgergeld oder Sozialhilfe',
      ),
      RequiredDocument(
        name: 'Schulbescheinigung',
        whereToGet: 'Sekretariat der Schule deines Kindes',
      ),
      RequiredDocument(
        name: 'Nachweis über Kosten (z.B. Vereinsbeitrag)',
        whereToGet: 'Anmeldeformular oder Rechnung des Vereins/Kurses',
        isOptional: true,
      ),
      RequiredDocument(
        name: 'Personalausweis (Kopie)',
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Prüfen was möglich ist',
        description:
            'BuT umfasst: Schulbedarf (195€/Jahr), Mittagessen, Ausflüge, Nachhilfe, Sport/Kultur (15€/Monat), Schülerbeförderung.',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Formloser Antrag oder Formular',
        description:
            'Beim Jobcenter oder Sozialamt das BuT-Formular holen (oder formlos per Brief beantragen). Manche Städte haben Online-Formulare.',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Nachweise beifügen',
        description:
            'Leistungsbescheid + Schulbescheinigung + ggf. Vereinsrechnung beifügen.',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Gutschein oder Direktzahlung',
        description:
            'Du bekommst entweder einen Gutschein (z.B. für den Verein) oder das Geld wird direkt an den Anbieter überwiesen.',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. ELTERNGELD
  // ═══════════════════════════════════════════════════════════════════════════

  static const elterngeld = BenefitApplicationData(
    benefitId: 'elterngeld',
    benefitName: 'Elterngeld',
    emoji: '🍼',
    countryCode: 'de',
    responsibleAuthority: 'Elterngeldstelle deines Bundeslandes',
    processingTime: '4–12 Wochen (je nach Bundesland)',
    renewalNote:
        'Kein Folgeantrag. Einmalig für 12–14 Monate (Basis) oder 24–28 Monate (Plus).',
    onlineApplicationUrl: 'https://familienportal.de/familienportal/meta/egr',
    proTip:
        'Den Antrag kannst du schon VOR der Geburt vorbereiten — nur die Geburtsurkunde fehlt dann noch. Spart Wochen!',
    aiTemplatePrompt:
        'Schreibe einen kurzen Begleitbrief für einen Elterngeldantrag. Ein Elternteil beantragt Basiselterngeld nach der Geburt des ersten Kindes und plant die Aufteilung der Monate mit dem Partner. Sachlich und klar.',
    documents: [
      RequiredDocument(
        name: 'Geburtsurkunde des Kindes (Original oder beglaubigte Kopie)',
        whereToGet: 'Standesamt',
      ),
      RequiredDocument(
        name: 'Bescheinigung der Krankenkasse über Mutterschaftsgeld',
        whereToGet: 'Deine Krankenkasse (nach der Geburt beantragen)',
      ),
      RequiredDocument(
        name: 'Arbeitgeberbescheinigung über Zuschuss zum Mutterschaftsgeld',
        whereToGet: 'Personalabteilung deines Arbeitgebers',
      ),
      RequiredDocument(
        name: 'Einkommensnachweise der letzten 12 Monate vor Geburt',
        whereToGet: 'Lohnzettel oder Steuerbescheid',
      ),
      RequiredDocument(
        name: 'Personalausweis beider Elternteile (Kopie)',
      ),
      RequiredDocument(
        name: 'Bestätigung über geplante Arbeitszeit (bei Elterngeld Plus)',
        whereToGet: 'Arbeitgeber (wenn du in Teilzeit arbeitest)',
        isOptional: true,
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Elterngeld-Rechner nutzen',
        description:
            'Berechne mit dem offiziellen Rechner wie viel Elterngeld dir zusteht und welche Aufteilung (Basis/Plus/Partnerschaftsbonus) am besten passt.',
        url:
            'https://familienportal.de/familienportal/rechner-antraege/elterngeldrechner',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Antrag ausfüllen (online oder Papier)',
        description:
            'Jedes Bundesland hat ein eigenes Formular. Am einfachsten über ElterngeldDigital (in vielen Bundesländern verfügbar).',
        url: 'https://familienportal.de/familienportal/meta/egr',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Unterlagen zusammenstellen',
        description:
            'Geburtsurkunde, Einkommensnachweise, Mutterschaftsgeld-Bescheinigung und Ausweise kopieren.',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Einreichen + Geduld',
        description:
            'Per Post oder digital einreichen. Bearbeitungszeit variiert stark (4–12 Wochen). Tipp: Nachfragen nach 6 Wochen wenn nichts kommt.',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. UNTERHALTSVORSCHUSS
  // ═══════════════════════════════════════════════════════════════════════════

  static const unterhaltsvorschuss = BenefitApplicationData(
    benefitId: 'unterhaltsvorschuss',
    benefitName: 'Unterhaltsvorschuss',
    emoji: '💪',
    countryCode: 'de',
    responsibleAuthority: 'Jugendamt deiner Stadt/Gemeinde',
    processingTime: '4–8 Wochen',
    renewalNote:
        'Kein Folgeantrag nötig. Wird automatisch bis 18 gezahlt (solange Voraussetzungen bestehen).',
    onlineApplicationUrl: null,
    proTip:
        'Du kannst Unterhaltsvorschuss auch rückwirkend für 1 Monat beantragen. Also nicht warten — sofort stellen!',
    aiTemplatePrompt:
        'Schreibe einen kurzen sachlichen Antrag auf Unterhaltsvorschuss. Ein alleinerziehender Elternteil erhält keinen Unterhalt vom anderen Elternteil. Halte es sachlich und klar, 3-4 Sätze.',
    documents: [
      RequiredDocument(
        name: 'Geburtsurkunde des Kindes',
        whereToGet: 'Standesamt',
      ),
      RequiredDocument(
        name: 'Personalausweis (Kopie)',
      ),
      RequiredDocument(
        name: 'Meldebestätigung (alleinige Wohnung)',
        whereToGet: 'Bürgeramt — zeigt dass du allein mit dem Kind wohnst',
      ),
      RequiredDocument(
        name: 'Nachweis über ausbleibenden Unterhalt',
        whereToGet:
            'z.B. Schreiben an den Ex ohne Antwort, Unterhaltstitel, oder eigene Erklärung',
      ),
      RequiredDocument(
        name: 'Vaterschaftsanerkennung oder Geburtsurkunde mit Vater',
        whereToGet: 'Standesamt oder Jugendamt',
        isOptional: true,
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Jugendamt kontaktieren',
        description:
            'Ruf bei deinem Jugendamt an oder geh persönlich hin. Die helfen dir direkt beim Ausfüllen.',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Antrag ausfüllen',
        description:
            'Das Formular bekommst du beim Jugendamt. Manche Städte bieten es auch online als PDF an.',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Unterlagen einreichen',
        description:
            'Geburtsurkunde, Meldebestätigung und Nachweis über fehlenden Unterhalt beifügen.',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Bescheid abwarten',
        description:
            'Nach 4–8 Wochen kommt der Bescheid. Die Zahlung erfolgt monatlich rückwirkend ab Antragstellung.',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. PFLEGEGELD
  // ═══════════════════════════════════════════════════════════════════════════

  static const pflegegeld = BenefitApplicationData(
    benefitId: 'pflegegeld',
    benefitName: 'Pflegegeld',
    emoji: '🫶',
    countryCode: 'de',
    responsibleAuthority: 'Pflegekasse (bei deiner Krankenkasse)',
    processingTime: '4–12 Wochen (inkl. Begutachtung)',
    renewalNote:
        'Kein Folgeantrag. Bei Verschlechterung: Höherstufungsantrag stellen.',
    onlineApplicationUrl: null,
    proTip:
        'Den Antrag formlos per Telefon stellen — ein Anruf bei der Pflegekasse reicht! Das Datum zählt für die rückwirkende Zahlung.',
    aiTemplatePrompt:
        'Schreibe einen kurzen formlosen Antrag auf Pflegeleistungen für ein Kind. Das Kind hat eine Behinderung/chronische Erkrankung und braucht tägliche Unterstützung. Sachlich, 3-4 Sätze.',
    documents: [
      RequiredDocument(
        name: 'Formloser Antrag (reicht per Telefon oder Brief)',
        whereToGet: 'Anruf bei deiner Krankenkasse/Pflegekasse genügt',
      ),
      RequiredDocument(
        name: 'Ärztliche Unterlagen / Diagnosen',
        whereToGet: 'Kinderarzt, Facharzt oder Krankenhaus',
      ),
      RequiredDocument(
        name: 'Pflegetagebuch (2 Wochen vor Begutachtung)',
        whereToGet: 'Vorlage von der Pflegekasse oder online',
        isOptional: true,
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Pflegekasse anrufen',
        description:
            'Ein Anruf reicht als Antrag! Sage: "Ich möchte Pflegeleistungen für mein Kind beantragen." Das Datum des Anrufs zählt.',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Pflegetagebuch führen (2 Wochen)',
        description:
            'Notiere täglich was dein Kind an Hilfe braucht: Waschen, Anziehen, Essen, Nacht, Aufsicht. Je genauer, desto besser für die Begutachtung.',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'MD-Begutachtung (Hausbesuch)',
        description:
            'Der Medizinische Dienst kommt zu euch nach Hause. Zeige offen was dein Kind braucht — nicht den "guten Tag" zeigen!',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Bescheid + ggf. Widerspruch',
        description:
            'Nach 4–12 Wochen kommt der Pflegegrad-Bescheid. Bei zu niedrigem Grad: innerhalb 4 Wochen Widerspruch einlegen (kostenlos).',
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. EINGLIEDERUNGSHILFE
  // ═══════════════════════════════════════════════════════════════════════════

  static const eingliederungshilfe = BenefitApplicationData(
    benefitId: 'eingliederungshilfe',
    benefitName: 'Eingliederungshilfe',
    emoji: '🤝',
    countryCode: 'de',
    responsibleAuthority:
        'Sozialamt oder Jugendamt (je nach Art der Behinderung)',
    processingTime: '4–12 Wochen',
    renewalNote:
        'Wird für einen festgelegten Zeitraum bewilligt. Rechtzeitig Folgeantrag stellen.',
    onlineApplicationUrl: null,
    proTip:
        'Bei seelischer Behinderung (z.B. Autismus, ADHS) ist das Jugendamt zuständig (§35a SGB VIII). Bei körperlicher/geistiger Behinderung das Sozialamt.',
    aiTemplatePrompt:
        'Schreibe einen kurzen formlosen Antrag auf Eingliederungshilfe für ein Kind. Das Kind hat eine Behinderung und braucht Unterstützung für Teilhabe (z.B. Schulbegleitung, Frühförderung). Sachlich, 3-4 Sätze.',
    documents: [
      RequiredDocument(
        name: 'Ärztliche Stellungnahme / Diagnose',
        whereToGet:
            'Kinderarzt, SPZ (Sozialpädiatrisches Zentrum) oder Facharzt',
      ),
      RequiredDocument(
        name: 'Formloser Antrag auf Eingliederungshilfe',
        whereToGet: 'Eigener Brief an das Sozialamt/Jugendamt',
      ),
      RequiredDocument(
        name: 'Entwicklungsbericht (Kita/Schule)',
        whereToGet: 'Erzieher*in oder Lehrkraft schreibt einen kurzen Bericht',
        isOptional: true,
      ),
      RequiredDocument(
        name: 'Stellungnahme der Schule (bei Schulbegleitung)',
        whereToGet: 'Schulleitung oder Klassenlehrer*in',
        isOptional: true,
      ),
    ],
    steps: [
      ApplicationStep(
        stepNumber: 1,
        title: 'Zuständigkeit klären',
        description:
            'Seelische Behinderung (Autismus, ADHS, Ängste) → Jugendamt. Körperliche/geistige Behinderung → Sozialamt. Im Zweifel: Jugendamt fragen.',
      ),
      ApplicationStep(
        stepNumber: 2,
        title: 'Formloser Antrag stellen',
        description:
            'Ein Brief reicht: "Ich beantrage Eingliederungshilfe für mein Kind [Name] wegen [Diagnose]." Dazu die ärztliche Stellungnahme beifügen.',
      ),
      ApplicationStep(
        stepNumber: 3,
        title: 'Hilfeplan-Gespräch',
        description:
            'Das Amt lädt dich zu einem Gespräch ein. Dort wird besprochen welche Hilfe dein Kind braucht (Frühförderung, Schulbegleitung, Therapie etc.).',
      ),
      ApplicationStep(
        stepNumber: 4,
        title: 'Bewilligung + Beginn der Hilfe',
        description:
            'Nach der Bewilligung beginnt die Hilfe. Bei Ablehnung: Widerspruch einlegen (innerhalb 4 Wochen, kostenlos).',
      ),
    ],
  );
}
