import 'package:parentpeak/models/country_finance_config.dart';

/// Alle verfuegbaren Laender-Konfigurationen.
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
        description: 'Monatliche Zahlung fuer jedes Kind bis 25 Jahre.',
        amount: '250\u{20AC}/Kind',
        eligibility: 'Alle Eltern mit Kindern unter 25 (in Ausbildung).',
        url: 'https://www.arbeitsagentur.de/familie-und-kinder/kindergeld',
        status: BenefitStatus.universal,
      ),
      SocialBenefit(
        id: 'kinderzuschlag',
        name: 'Kinderzuschlag (KiZ)',
        description:
            'Zusaetzliche Unterstuetzung fuer Familien mit geringem Einkommen.',
        amount: 'bis 292\u{20AC}/Kind',
        eligibility: 'Einkommen reicht fuer euch, aber nicht fuer die Kinder.',
        url: 'https://www.arbeitsagentur.de/familie-und-kinder/kinderzuschlag',
        status: BenefitStatus.incomeDependent,
      ),
      SocialBenefit(
        id: 'wohngeld',
        name: 'Wohngeld',
        description: 'Mietzuschuss fuer Familien mit niedrigem Einkommen.',
        amount: 'individuell berechnet',
        eligibility: 'Haushaltseinkommen unter bestimmter Grenze.',
        url: 'https://www.bmwsb.bund.de/Webs/BMWSB/DE/themen/wohnen/wohngeld',
        status: BenefitStatus.incomeDependent,
      ),
      SocialBenefit(
        id: 'but',
        name: 'Bildung & Teilhabe (BuT)',
        description:
            'Schulbedarf, Ausfluege, Nachhilfe, Mittagessen, Sport-Verein.',
        amount: 'Sachleistungen + 195\u{20AC}/Jahr Schulbedarf',
        eligibility: 'Familien mit KiZ, Wohngeld oder Buergergeld.',
        url: 'https://www.bmas.de/DE/Arbeit/Grundsicherung/Bildungspaket',
        status: BenefitStatus.checkRequired,
      ),
      SocialBenefit(
        id: 'elterngeld',
        name: 'Elterngeld',
        description: 'Einkommensersatz nach der Geburt (12-14 Monate).',
        amount: '300\u{20AC}\u{2013}1.800\u{20AC}/Monat',
        eligibility: 'Eltern mit Kindern unter 14 Monaten.',
        url:
            'https://familienportal.de/familienportal/familienleistungen/elterngeld',
        status: BenefitStatus.universal,
      ),
      SocialBenefit(
        id: 'unterhaltsvorschuss',
        name: 'Unterhaltsvorschuss',
        description: 'Wenn der andere Elternteil keinen Unterhalt zahlt.',
        amount: '187\u{20AC}\u{2013}338\u{20AC}/Monat',
        eligibility: 'Alleinerziehende deren Ex keinen Unterhalt zahlt.',
        url:
            'https://www.bmfsfj.de/bmfsfj/themen/familie/familienleistungen/unterhaltsvorschuss',
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
          note: 'Ranzen, Stifte, Turnbeutel, Schultuete'),
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
          note: 'Geraet + Huelle + erster Vertrag'),
      MilestoneCost(
          id: 'fuehrerschein',
          label: 'Fuehrerschein',
          emoji: '\u{1F697}',
          estimatedCost: 3500,
          childAgeYears: 17,
          note: 'Fahrstunden + Pruefungen'),
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
          id: 'mobilitaet',
          label: 'Mobilitaet',
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
    name: 'Oesterreich',
    flag: '\u{1F1E6}\u{1F1F9}',
    currency: 'EUR',
    currencySymbol: '\u{20AC}',
    benefits: [
      SocialBenefit(
          id: 'familienbeihilfe',
          name: 'Familienbeihilfe',
          description:
              'Monatliche Unterstuetzung pro Kind, gestaffelt nach Alter.',
          amount: '132\u{20AC}\u{2013}191\u{20AC}/Kind',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'kinderabsetzbetrag',
          name: 'Kinderabsetzbetrag',
          description: 'Steuerlicher Absetzbetrag pro Kind.',
          amount: '67\u{20AC}/Monat',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'kinderbetreuungsgeld',
          name: 'Kinderbetreuungsgeld',
          description: 'Nach der Geburt, verschiedene Modelle.',
          amount: '476\u{20AC}\u{2013}2.000\u{20AC}/Monat',
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
          amount: '200\u{2013}380 Fr./Kind',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'ausbildungszulage',
          name: 'Ausbildungszulage',
          description: 'Ab 16 Jahren in Ausbildung.',
          amount: '250\u{2013}450 Fr./Kind',
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
    name: 'Tuerkiye',
    flag: '\u{1F1F9}\u{1F1F7}',
    currency: 'TRY',
    currencySymbol: '\u{20BA}',
    benefits: [
      SocialBenefit(
          id: 'dogum_yardimi',
          name: 'Dogum Yardimi',
          description:
              'Einmalige Geburtshilfe (1. Kind: 300TL, 2.: 400TL, 3.+: 600TL).',
          amount: '300\u{2013}600\u{20BA}',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'cocuk_parasi',
          name: 'Cocuk Parasi',
          description: 'Monatliches Kindergeld fuer Familien.',
          amount: 'einkommensabhaengig',
          status: BenefitStatus.incomeDependent),
      SocialBenefit(
          id: 'sed',
          name: 'Sosyal Yardim (SED)',
          description: 'Soziale Unterstuetzung ueber SYDV.',
          eligibility: 'Familien unter der Armutsgrenze.',
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
          amount: '\u{00A3}25.60/week (1st), \u{00A3}16.95 (others)',
          status: BenefitStatus.universal),
      SocialBenefit(
          id: 'universal_credit',
          name: 'Universal Credit (Child Element)',
          description: 'Extra support for families on low income.',
          amount: 'up to \u{00A3}315/month per child',
          status: BenefitStatus.incomeDependent),
      SocialBenefit(
          id: 'tax_free_childcare',
          name: 'Tax-Free Childcare',
          description: 'Government tops up childcare payments by 20%.',
          amount: 'up to \u{00A3}2,000/year per child',
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
  // GENERISCH (Fallback fuer alle anderen Laender)
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
              'Die meisten Laender zahlen monatliche Familienleistungen. Pruefe bei deiner lokalen Behoerde.',
          status: BenefitStatus.checkRequired),
      SocialBenefit(
          id: 'generic_housing',
          name: 'Wohn-Unterstuetzung',
          description: 'Viele Laender bieten Mietzuschuesse fuer Familien an.',
          status: BenefitStatus.checkRequired),
      SocialBenefit(
          id: 'generic_childcare',
          name: 'Betreuungs-Zuschuss',
          description: 'Pruefe ob dein Land Kinderbetreuung subventioniert.',
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
