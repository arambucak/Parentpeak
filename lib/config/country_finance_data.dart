import 'package:parentpeak/models/country_finance_config.dart';

/// Alle verfügbaren Laender-Konfigurationen.
class CountryFinanceData {
  static const List<CountryFinanceConfig> availableCountries = [
    germany,
    austria,
    switzerland,
    turkey,
    uk,
    generic,
  ];

  static CountryFinanceConfig getByCode(String code) {
    return availableCountries.firstWhere(
      (c) => c.code == code,
      orElse: () => generic,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEUTSCHLAND
  // ═══════════════════════════════════════════════════════════════════════════

  static const germany = CountryFinanceConfig(
    code: 'de',
    name: 'Deutschland',
    flag: '\u{1F1E9}\u{1F1EA}',
    currency: 'EUR',
    currencySymbol: '\u{20AC}',
    benefits: [
      SocialBenefit(
        id: 'kindergeld',
        name: 'Kindergeld',
        description: 'Monatliche Zahlung für Kinder; bei Volljährigen gelten zusätzliche Voraussetzungen.',
        amount: '259\u{20AC}/Kind',
        eligibility: 'Grundsätzlich für Minderjährige; Versorgung, Haushalt und Wohnsitz sowie Sonderfälle prüfen.',
        url: 'https://www.arbeitsagentur.de/familie-und-kinder/infos-rund-um-kindergeld/kindergeld-anspruch-hoehe-dauer',
        status: BenefitStatus.universal,
      ),
      SocialBenefit(
        id: 'kinderzuschlag',
        name: 'Kinderzuschlag (KiZ)',
        description:
            'Zusätzliche Unterstützung für Familien mit geringem Einkommen.',
        amount: 'bis 297\u{20AC}/Kind/Monat',
        eligibility: 'Kind unter 25 im Haushalt, Kindergeldbezug; Einkommen, Vermögen und Familienbedarf individuell prüfen.',
        url: 'https://www.arbeitsagentur.de/familie-und-kinder/kinderzuschlag-verstehen/kinderzuschlag-anspruch-hoehe-dauer',
        status: BenefitStatus.incomeDependent,
      ),
      SocialBenefit(
        id: 'wohngeld',
        name: 'Wohngeld',
        description: 'Mietzuschuss für Familien mit niedrigem Einkommen.',
        amount: 'individuell berechnet',
        eligibility: 'Abhängig von Haushaltsgröße, berücksichtigter Miete/Belastung und Gesamteinkommen.',
        url:
            'https://www.bmwsb.bund.de/Webs/BMWSB/DE/themen/stadt-wohnen/wohnraumfoerderung/wohngeld/wohngeldrechner-2025-artikel.html',
        status: BenefitStatus.incomeDependent,
      ),
      SocialBenefit(
        id: 'but',
        name: 'Bildung & Teilhabe (BuT)',
        description:
            'Schulbedarf, Ausflüge, Nachhilfe, Mittagessen, Sport-Verein.',
        amount: 'Sachleistungen + 195\u{20AC}/Jahr Schulbedarf',
        eligibility: 'Familien mit KiZ, Wohngeld oder Bürgergeld.',
        url:
            'https://familienportal.de/familienportal/familienleistungen/bildung-und-teilhabe',
        status: BenefitStatus.checkRequired,
      ),
      SocialBenefit(
        id: 'elterngeld',
        name: 'Elterngeld',
        description: 'Einkommensersatz nach der Geburt; Basiselterngeld und ElterngeldPlus haben unterschiedliche Bezugszeiten.',
        amount: 'Basis: 300\u{20AC}\u{2013}1.800\u{20AC}/Monat; Plus: 150\u{20AC}\u{2013}900\u{20AC}/Monat (ohne Zuschläge)',
        eligibility: 'Gemeinsamer Haushalt, eigene Betreuung und keine volle Erwerbstätigkeit; weitere Voraussetzungen und Ausnahmen prüfen.',
        url:
            'https://familienportal.de/familienportal/familienleistungen/elterngeld',
        status: BenefitStatus.universal,
      ),
      SocialBenefit(
        id: 'unterhaltsvorschuss',
        name: 'Unterhaltsvorschuss',
        description: 'Wenn der andere Elternteil keinen, unregelmäßig oder zu wenig Unterhalt zahlt.',
        amount: '227 / 299 / 394\u{20AC}/Monat (0\u{2013}5 / 6\u{2013}11 / 12\u{2013}17 Jahre)',
        eligibility: 'Kind lebt bei alleinerziehendem Elternteil; für 12 bis 17 Jahre gelten zusätzliche Voraussetzungen.',
        url:
            'https://familienportal.de/familienportal/familienleistungen/unterhaltsvorschuss/wieviel-unterhaltsvorschuss-kann-ich-fuer-mein-kind-bekommen--125264',
        status: BenefitStatus.checkRequired,
      ),
      SocialBenefit(
        id: 'pflegegeld',
        name: 'Pflegegeld',
        description:
            'Für Kinder mit Behinderung oder chronischer Erkrankung die Pflege brauchen.',
        amount: '347 / 599 / 800 / 990\u{20AC}/Monat (Pflegegrad 2 / 3 / 4 / 5)',
        eligibility: 'Pflegegrad 2 bis 5; häusliche Pflege muss in geeigneter Weise selbst sichergestellt sein.',
        url:
            'https://www.gesetze-im-internet.de/sgb_11/__37.html',
        status: BenefitStatus.checkRequired,
      ),
      SocialBenefit(
        id: 'eingliederungshilfe',
        name: 'Eingliederungshilfe',
        description:
            'Unterstützung für Kinder mit Behinderung: Therapie, Schulbegleitung, Frühförderung.',
        amount: 'Individuell (Sachleistungen)',
        eligibility: 'Kinder mit drohender oder bestehender Behinderung.',
        url:
            'https://familienportal.de/familienportal/familienleistungen/weitere-leistungen',
        status: BenefitStatus.checkRequired,
      ),
    ],
    milestones: [
      MilestoneCost(
          id: 'schulstart',
          label: 'Schulstart',
          emoji: '\u{1F392}',
          estimatedCost: 350,
          childAgeYears: 6,
          note: 'Ranzen, Stifte, Turnbeutel, Schultüte'),
      MilestoneCost(
          id: 'fahrrad',
          label: 'Erstes Fahrrad',
          emoji: '\u{1F6B2}',
          estimatedCost: 250,
          childAgeYears: 4,
          note: 'Kinderfahrrad + Helm'),
      MilestoneCost(
          id: 'klassenfahrt',
          label: 'Erste Klassenfahrt',
          emoji: '\u{1F3D5}\u{FE0F}',
          estimatedCost: 400,
          childAgeYears: 9,
          note: '3-5 Tage, inkl. Taschengeld'),
      MilestoneCost(
          id: 'smartphone',
          label: 'Erstes Smartphone',
          emoji: '\u{1F4F1}',
          estimatedCost: 300,
          childAgeYears: 11,
          note: 'Gerät + Hülle + erster Vertrag'),
      MilestoneCost(
          id: 'fuehrerschein',
          label: 'Führerschein',
          emoji: '\u{1F697}',
          estimatedCost: 3500,
          childAgeYears: 17,
          note: 'Fahrstunden + Prüfungen'),
      MilestoneCost(
          id: 'ausbildung',
          label: 'Ausbildung/Studium',
          emoji: '\u{1F393}',
          estimatedCost: 5000,
          childAgeYears: 18,
          note: 'Erstausstattung, Umzug, Kaution'),
    ],
    categories: [
      MonthlyCategory(
          id: 'kita',
          label: 'Kita / Betreuung',
          emoji: '\u{1F3EB}',
          typicalAmount: 300),
      MonthlyCategory(
          id: 'essen',
          label: 'Essen & Trinken',
          emoji: '\u{1F35D}',
          typicalAmount: 400),
      MonthlyCategory(
          id: 'kleidung',
          label: 'Kleidung',
          emoji: '\u{1F455}',
          typicalAmount: 80),
      MonthlyCategory(
          id: 'freizeit',
          label: 'Freizeit & Kurse',
          emoji: '\u{1F3A8}',
          typicalAmount: 100),
      MonthlyCategory(
          id: 'gesundheit',
          label: 'Gesundheit',
          emoji: '\u{1F3E5}',
          typicalAmount: 50),
      MonthlyCategory(
          id: 'mobilität',
          label: 'Mobilität',
          emoji: '\u{1F68C}',
          typicalAmount: 80),
      MonthlyCategory(
          id: 'wohnen',
          label: 'Wohnen (Kinder-Anteil)',
          emoji: '\u{1F3E0}',
          typicalAmount: 200),
      MonthlyCategory(
          id: 'sonstiges',
          label: 'Sonstiges',
          emoji: '\u{1F4E6}',
          typicalAmount: 50),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // OESTERREICH
  // ═══════════════════════════════════════════════════════════════════════════

  static const austria = CountryFinanceConfig(
    code: 'at',
    name: 'Österreich',
    flag: '\u{1F1E6}\u{1F1F9}',
    currency: 'EUR',
    currencySymbol: '\u{20AC}',
    benefits: [
      SocialBenefit(
          id: 'familienbeihilfe',
          name: 'Familienbeihilfe',
          description:
              'Monatliche Unterstützung pro Kind, gestaffelt nach Alter.',
          amount: '138,40 / 148 / 171,80 / 200,40\u{20AC}/Monat (ab 0 / 3 / 10 / 19 Jahren; ohne Zuschläge)',
          url: 'https://www.bundeskanzleramt.gv.at/agenda/familie/familienbeihilfe/basisinformation-zur-familienbeihilfe/familienbeihilfenbetraege.html',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'kinderabsetzbetrag',
          name: 'Kinderabsetzbetrag',
          description: 'Steuerlicher Absetzbetrag pro Kind.',
          amount: '70,90\u{20AC}/Kind/Monat',
          eligibility: 'Wird gemeinsam mit der Familienbeihilfe ausgezahlt; kein gesonderter Antrag.',
          url: 'https://www.bundeskanzleramt.gv.at/agenda/familie/finanzielle-entlastung-von-familien/familiensteuerentlastung/kinderabsetzbetrag.html',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'kinderbetreuungsgeld',
          name: 'Kinderbetreuungsgeld',
          description: 'Nach der Geburt, verschiedene Modelle.',
          amount: 'Konto: 17,65\u{2013}41,14\u{20AC}/Tag; einkommensabhängig: 80% der Letzteinkünfte, max. 80,12\u{20AC}/Tag',
          url: 'https://www.bundeskanzleramt.gv.at/agenda/familie/kinderbetreuungsgeld/basisinformationen-kinderbetreuungsgeld.html',
          status: BenefitStatus.universal),
    ],
    milestones: [
      MilestoneCost(
          id: 'schulstart',
          label: 'Schulstart',
          emoji: '\u{1F392}',
          estimatedCost: 300,
          childAgeYears: 6),
      MilestoneCost(
          id: 'fahrrad',
          label: 'Erstes Fahrrad',
          emoji: '\u{1F6B2}',
          estimatedCost: 250,
          childAgeYears: 4),
      MilestoneCost(
          id: 'smartphone',
          label: 'Erstes Smartphone',
          emoji: '\u{1F4F1}',
          estimatedCost: 300,
          childAgeYears: 11),
    ],
    categories: [
      MonthlyCategory(
          id: 'kita',
          label: 'Kinderbetreuung',
          emoji: '\u{1F3EB}',
          typicalAmount: 200),
      MonthlyCategory(
          id: 'essen',
          label: 'Essen & Trinken',
          emoji: '\u{1F35D}',
          typicalAmount: 380),
      MonthlyCategory(
          id: 'kleidung',
          label: 'Kleidung',
          emoji: '\u{1F455}',
          typicalAmount: 70),
      MonthlyCategory(
          id: 'freizeit',
          label: 'Freizeit & Kurse',
          emoji: '\u{1F3A8}',
          typicalAmount: 90),
      MonthlyCategory(
          id: 'sonstiges',
          label: 'Sonstiges',
          emoji: '\u{1F4E6}',
          typicalAmount: 60),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SCHWEIZ
  // ═══════════════════════════════════════════════════════════════════════════

  static const switzerland = CountryFinanceConfig(
    code: 'ch',
    name: 'Schweiz',
    flag: '\u{1F1E8}\u{1F1ED}',
    currency: 'CHF',
    currencySymbol: 'Fr.',
    benefits: [
      SocialBenefit(
          id: 'kinderzulage',
          name: 'Kinderzulage',
          description: 'Kantonal unterschiedlich, pro Kind.',
          amount: 'mindestens 215 Fr./Kind/Monat; kantonal ggf. höher',
          url: 'https://www.bsv.admin.ch/de/familienzulagen-leistungen-und-voraussetzungen',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'ausbildungszulage',
          name: 'Ausbildungszulage',
          description: 'Nachobligatorische Ausbildung, frühestens ab 15 bis längstens 25 Jahre; genaue Monatsgrenzen prüfen.',
          amount: 'mindestens 268 Fr./Kind/Monat; kantonal ggf. höher',
          url: 'https://www.bsv.admin.ch/de/familienzulagen-leistungen-und-voraussetzungen',
          status: BenefitStatus.universal),
    ],
    milestones: [
      MilestoneCost(
          id: 'schulstart',
          label: 'Schulstart',
          emoji: '\u{1F392}',
          estimatedCost: 400,
          childAgeYears: 6),
      MilestoneCost(
          id: 'fahrrad',
          label: 'Erstes Fahrrad',
          emoji: '\u{1F6B2}',
          estimatedCost: 350,
          childAgeYears: 4),
      MilestoneCost(
          id: 'smartphone',
          label: 'Erstes Smartphone',
          emoji: '\u{1F4F1}',
          estimatedCost: 400,
          childAgeYears: 11),
    ],
    categories: [
      MonthlyCategory(
          id: 'kita',
          label: 'Kinderbetreuung',
          emoji: '\u{1F3EB}',
          typicalAmount: 1500),
      MonthlyCategory(
          id: 'essen',
          label: 'Essen & Trinken',
          emoji: '\u{1F35D}',
          typicalAmount: 600),
      MonthlyCategory(
          id: 'kleidung',
          label: 'Kleidung',
          emoji: '\u{1F455}',
          typicalAmount: 100),
      MonthlyCategory(
          id: 'freizeit',
          label: 'Freizeit',
          emoji: '\u{1F3A8}',
          typicalAmount: 150),
      MonthlyCategory(
          id: 'sonstiges',
          label: 'Sonstiges',
          emoji: '\u{1F4E6}',
          typicalAmount: 100),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TUERKEI
  // ═══════════════════════════════════════════════════════════════════════════

  static const turkey = CountryFinanceConfig(
    code: 'tr',
    name: 'Türkiye',
    flag: '\u{1F1F9}\u{1F1F7}',
    currency: 'TRY',
    currencySymbol: '\u{20BA}',
    benefits: [
      SocialBenefit(
          id: 'dogum_yardimi',
          name: 'Dogum Yardimi',
          description:
              'Neues Geburtshilfeprogramm für Geburten ab 01.01.2025; regelmäßige Zahlungen ab Antrag bis einschließlich 60. Monat.',
          amount: '1. Kind: einmalig 5.000\u{20BA}; 2.: 1.500\u{20BA}/Monat; 3.+: 5.000\u{20BA}/Monat',
          eligibility: 'Türkische Staatsangehörigkeit und Wohnsitz in Türkiye; weitere Antragsvoraussetzungen amtlich prüfen.',
          url: 'https://www.aile.gov.tr/sss/sosyal-yardimlar-genel-mudurlugu/yeni-dogum-yardimi/',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'cocuk_parasi',
          name: 'Cocuk Parasi',
          description: 'Monatliches Kindergeld für Familien.',
          amount: 'einkommensabhängig',
          status: BenefitStatus.incomeDependent),
      SocialBenefit(
          id: 'sed',
          name: 'Sosyal Yardim (SED)',
          description: 'Soziale und wirtschaftliche Unterstützung über İl Müdürlüğü/Sosyal Hizmet Merkezi.',
          eligibility: 'Individuelle soziale Prüfung der familiären, wirtschaftlichen und regionalen Situation.',
          url: 'https://www.aile.gov.tr/sss/cocuk-hizmetleri-genel-mudurlugu/sed-hizmeti/',
          status: BenefitStatus.checkRequired),
    ],
    milestones: [
      MilestoneCost(
          id: 'schulstart',
          label: 'Okul Baslangici',
          emoji: '\u{1F392}',
          estimatedCost: 5000,
          childAgeYears: 6,
          note: 'Canta, kirtasiye, forma'),
      MilestoneCost(
          id: 'fahrrad',
          label: 'Ilk Bisiklet',
          emoji: '\u{1F6B2}',
          estimatedCost: 4000,
          childAgeYears: 5),
      MilestoneCost(
          id: 'smartphone',
          label: 'Ilk Telefon',
          emoji: '\u{1F4F1}',
          estimatedCost: 15000,
          childAgeYears: 12),
    ],
    categories: [
      MonthlyCategory(
          id: 'kita',
          label: 'Kres / Bakim',
          emoji: '\u{1F3EB}',
          typicalAmount: 8000),
      MonthlyCategory(
          id: 'essen', label: 'Yemek', emoji: '\u{1F35D}', typicalAmount: 6000),
      MonthlyCategory(
          id: 'kleidung',
          label: 'Giyim',
          emoji: '\u{1F455}',
          typicalAmount: 2000),
      MonthlyCategory(
          id: 'freizeit',
          label: 'Etkinlik',
          emoji: '\u{1F3A8}',
          typicalAmount: 1500),
      MonthlyCategory(
          id: 'sonstiges',
          label: 'Diger',
          emoji: '\u{1F4E6}',
          typicalAmount: 1000),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // UNITED KINGDOM
  // ═══════════════════════════════════════════════════════════════════════════

  static const uk = CountryFinanceConfig(
    code: 'gb',
    name: 'United Kingdom',
    flag: '\u{1F1EC}\u{1F1E7}',
    currency: 'GBP',
    currencySymbol: '\u{00A3}',
    benefits: [
      SocialBenefit(
          id: 'child_benefit',
          name: 'Child Benefit',
          description: 'Weekly payment for each child.',
          amount: '\u{00A3}27.05/week (eldest or only), \u{00A3}17.90/week (additional children)',
          url: 'https://www.gov.uk/child-benefit/what-youll-get',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'universal_credit',
          name: 'Universal Credit (Child Element)',
          description: 'Extra support for families on low income.',
          amount: '\u{00A3}303.94/month per child; extra \u{00A3}47.94 for first child born before 6 April 2017',
          url: 'https://www.gov.uk/universal-credit/what-youll-get',
          status: BenefitStatus.incomeDependent),
      SocialBenefit(
          id: 'tax_free_childcare',
          name: 'Tax-Free Childcare',
          description: 'Government adds \u{00A3}2 for each \u{00A3}8 paid into the childcare account.',
          amount: 'up to \u{00A3}500/3 months (\u{00A3}2,000/year); disabled child: \u{00A3}1,000/3 months (\u{00A3}4,000/year)',
          url: 'https://www.gov.uk/tax-free-childcare',
          status: BenefitStatus.checkRequired),
    ],
    milestones: [
      MilestoneCost(
          id: 'schulstart',
          label: 'School Start',
          emoji: '\u{1F392}',
          estimatedCost: 200,
          childAgeYears: 5,
          note: 'Uniform, bag, shoes, stationery'),
      MilestoneCost(
          id: 'fahrrad',
          label: 'First Bike',
          emoji: '\u{1F6B2}',
          estimatedCost: 180,
          childAgeYears: 4),
      MilestoneCost(
          id: 'smartphone',
          label: 'First Phone',
          emoji: '\u{1F4F1}',
          estimatedCost: 250,
          childAgeYears: 11),
    ],
    categories: [
      MonthlyCategory(
          id: 'kita',
          label: 'Childcare',
          emoji: '\u{1F3EB}',
          typicalAmount: 800),
      MonthlyCategory(
          id: 'essen',
          label: 'Food & Drink',
          emoji: '\u{1F35D}',
          typicalAmount: 300),
      MonthlyCategory(
          id: 'kleidung',
          label: 'Clothing',
          emoji: '\u{1F455}',
          typicalAmount: 60),
      MonthlyCategory(
          id: 'freizeit',
          label: 'Activities',
          emoji: '\u{1F3A8}',
          typicalAmount: 80),
      MonthlyCategory(
          id: 'sonstiges',
          label: 'Other',
          emoji: '\u{1F4E6}',
          typicalAmount: 50),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERISCH (Fallback für alle anderen Laender)
  // ═══════════════════════════════════════════════════════════════════════════

  static const generic = CountryFinanceConfig(
    code: 'generic',
    name: 'Anderes Land',
    flag: '\u{1F30D}',
    currency: 'EUR',
    currencySymbol: '\u{20AC}',
    benefits: [
      SocialBenefit(
          id: 'generic_kindergeld',
          name: 'Kindergeld / Child Benefit',
          description:
              'Die meisten Länder zahlen monatliche Familienleistungen. Prüfe bei deiner lokalen Behörde.',
          status: BenefitStatus.checkRequired),
      SocialBenefit(
          id: 'generic_housing',
          name: 'Wohn-Unterstützung',
          description: 'Viele Länder bieten Mietzuschüsse für Familien an.',
          status: BenefitStatus.checkRequired),
      SocialBenefit(
          id: 'generic_childcare',
          name: 'Betreuungs-Zuschuss',
          description: 'Prüfe ob dein Land Kinderbetreuung subventioniert.',
          status: BenefitStatus.checkRequired),
    ],
    milestones: [
      MilestoneCost(
          id: 'schulstart',
          label: 'Schulstart',
          emoji: '\u{1F392}',
          estimatedCost: 300,
          childAgeYears: 6),
      MilestoneCost(
          id: 'fahrrad',
          label: 'Erstes Fahrrad',
          emoji: '\u{1F6B2}',
          estimatedCost: 200,
          childAgeYears: 4),
      MilestoneCost(
          id: 'smartphone',
          label: 'Erstes Smartphone',
          emoji: '\u{1F4F1}',
          estimatedCost: 250,
          childAgeYears: 11),
    ],
    categories: [
      MonthlyCategory(id: 'kita', label: 'Kinderbetreuung', emoji: '\u{1F3EB}'),
      MonthlyCategory(id: 'essen', label: 'Essen', emoji: '\u{1F35D}'),
      MonthlyCategory(id: 'kleidung', label: 'Kleidung', emoji: '\u{1F455}'),
      MonthlyCategory(id: 'freizeit', label: 'Freizeit', emoji: '\u{1F3A8}'),
      MonthlyCategory(id: 'sonstiges', label: 'Sonstiges', emoji: '\u{1F4E6}'),
    ],
  );
}
