class DevelopmentMilestoneItem {
  final String code;
  final String title;
  final String description;

  const DevelopmentMilestoneItem({
    required this.code,
    required this.title,
    required this.description,
  });
}

class DevelopmentCategory {
  final String name;
  final List<DevelopmentMilestoneItem> items;

  const DevelopmentCategory({
    required this.name,
    required this.items,
  });
}

class DevelopmentPhase {
  final String id;
  final String ageRange;
  final String title;
  final List<DevelopmentCategory> categories;

  const DevelopmentPhase({
    required this.id,
    required this.ageRange,
    required this.title,
    required this.categories,
  });
}

class MilestoneDatabase {
  final List<DevelopmentPhase> phases;

  const MilestoneDatabase({required this.phases});
}

class MilestoneProgress {
  final String childId;
  final String milestoneCode;
  final String status;
  final String updatedAt;

  const MilestoneProgress({
    required this.childId,
    required this.milestoneCode,
    required this.status,
    required this.updatedAt,
  });
}

const List<String> kMilestoneStatuses = [
  'NOCH_NICHT',
  'ANSATZWEISE',
  'WEITGEHEND',
  'ZUVERLAESSIG',
];

const MilestoneDatabase kDevelopmentMilestoneDatabase = MilestoneDatabase(
  phases: [
    DevelopmentPhase(
      id: 'phase_0_12_m',
      ageRange: '0 bis 12 Monate',
      title: 'Saeuglingsphase',
      categories: [
        DevelopmentCategory(
          name: 'Motorik',
          items: [
            DevelopmentMilestoneItem(
              code: 'MO.01',
              title: 'Kopfkontrolle',
              description:
                  'Das Kind hält seinen Kopf in Bauchlage sicher und stabil.',
            ),
            DevelopmentMilestoneItem(
              code: 'MO.02',
              title: 'Gezieltes Greifen',
              description:
                  'Das Kind greift bewusst nach Gegenstaenden, die sich vor seiner Brust befinden.',
            ),
            DevelopmentMilestoneItem(
              code: 'MO.03',
              title: 'Fortbewegung',
              description:
                  'Das Kind rollt, robbt oder krabbelt eigenständig vorwärts.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sprache und Kognition',
          items: [
            DevelopmentMilestoneItem(
              code: 'SP.01',
              title: 'Lautieren',
              description:
                  "Das Kind bildet zweisilbige Ketten wie 'ma-ma' oder 'ba-ba'.",
            ),
            DevelopmentMilestoneItem(
              code: 'KF.01',
              title: 'Objektpermanenz',
              description:
                  'Das Kind sucht mit den Augen nach Gegenstaenden, die vor ihm versteckt wurden.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sozial-emotional',
          items: [
            DevelopmentMilestoneItem(
              code: 'SE.01',
              title: 'Soziales Laecheln',
              description:
                  'Das Kind erwidert laechelnd den direkten Blickkontakt von Bezugspersonen.',
            ),
            DevelopmentMilestoneItem(
              code: 'G.01',
              title: 'Fremdeln',
              description:
                  'Das Kind zeigt eine deutliche Skepsis, Zurückhaltung oder Angst bei unbekannten Personen.',
            ),
          ],
        ),
      ],
    ),
    DevelopmentPhase(
      id: 'phase_1_3_y',
      ageRange: '1 bis 3 Jahre',
      title: 'Kleinkindphase',
      categories: [
        DevelopmentCategory(
          name: 'Motorik',
          items: [
            DevelopmentMilestoneItem(
              code: 'MO.04',
              title: 'Sicherer Stand',
              description:
                  'Das Kind laeuft mehrere Schritte frei und sicher im Raum.',
            ),
            DevelopmentMilestoneItem(
              code: 'MO.05',
              title: 'Feinmotorik',
              description:
                  'Das Kind stapelt mindestens drei Baeusteine stabil zu einem Turm uebereinander.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sprache und Kognition',
          items: [
            DevelopmentMilestoneItem(
              code: 'SP.02',
              title: 'Wortschatz',
              description:
                  'Das Kind nutzt aktiv einen eigenen Wortschatz von mindestens 50 unterschiedlichen Woertern.',
            ),
            DevelopmentMilestoneItem(
              code: 'SP.03',
              title: 'Satzbau',
              description:
                  'Das Kind bildet einfache Saetze, die aus zwei oder drei Woertern bestehen.',
            ),
            DevelopmentMilestoneItem(
              code: 'KF.02',
              title: 'Sortieren',
              description:
                  'Das Kind legt Gegenstaende nach einer bestimmten Eigenschaft zusammen.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sozial-emotional',
          items: [
            DevelopmentMilestoneItem(
              code: 'SE.02',
              title: 'Paralleles Spiel',
              description:
                  'Das Kind spielt friedlich und interessiert neben oder mit anderen Kindern.',
            ),
            DevelopmentMilestoneItem(
              code: 'G.02',
              title: 'Autonomie',
              description:
                  'Das Kind drückt seinen eigenen Willen deutlich verbal oder durch Körpersprache aus.',
            ),
          ],
        ),
      ],
    ),
    DevelopmentPhase(
      id: 'phase_3_6_y',
      ageRange: '3 bis 6 Jahre',
      title: 'Kindergarten- und Vorschulphase',
      categories: [
        DevelopmentCategory(
          name: 'Motorik',
          items: [
            DevelopmentMilestoneItem(
              code: 'MO.06',
              title: 'Koordination',
              description:
                  'Das Kind kann für einige Sekunden sicher auf einem Bein das Gleichgewicht halten.',
            ),
            DevelopmentMilestoneItem(
              code: 'MO.07',
              title: 'Werkzeuggebrauch',
              description:
                  'Das Kind schneidet mit einer Kinderschere einfache Formen sauber aus Papier aus.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sprache und Kognition',
          items: [
            DevelopmentMilestoneItem(
              code: 'SP.04',
              title: 'Grammatik',
              description:
                  "Das Kind bildet weitgehend fehlerfreie Nebensaetze und nutzt Bindewoerter wie 'weil' oder 'und'.",
            ),
            DevelopmentMilestoneItem(
              code: 'KF.03',
              title: 'Abzählen',
              description:
                  'Das Kind zaehlt eine Menge von bis zu fuenf Elementen fehlerfrei ab.',
            ),
            DevelopmentMilestoneItem(
              code: 'KF.04',
              title: 'Merkfaehigkeit',
              description:
                  'Das Kind findet bei einfachen Memory-Spielen zielsicher zusammengehörige Paare.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sozial-emotional',
          items: [
            DevelopmentMilestoneItem(
              code: 'SE.03',
              title: 'Regelspiel',
              description:
                  'Das Kind beteiligt sich an gemeinsamen Spielen und versteht sowie akzeptiert feste Regeln.',
            ),
            DevelopmentMilestoneItem(
              code: 'G.03',
              title: 'Selbstregulation',
              description:
                  'Das Kind kann sich nach grossem Ärger oder Frust nach kurzer Zeit eigenständig wieder beruhigen.',
            ),
          ],
        ),
      ],
    ),
    DevelopmentPhase(
      id: 'phase_6_12_y',
      ageRange: '6 bis 12 Jahre',
      title: 'Schulkindphase',
      categories: [
        DevelopmentCategory(
          name: 'Motorik und Alltag',
          items: [
            DevelopmentMilestoneItem(
              code: 'MO.08',
              title: 'Komplexe Motorik',
              description:
                  'Das Kind bewegt sich sicher, zum Beispiel beim Fahrradfahren, unter Beachtung grundlegender Verkehrsregeln.',
            ),
            DevelopmentMilestoneItem(
              code: 'AK.01',
              title: 'Selbstorganisation',
              description:
                  'Das Kind packt seine Schultasche oder Freizeitkleidung eigenständig nach Plan.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sprache und Kognition',
          items: [
            DevelopmentMilestoneItem(
              code: 'LSR.04',
              title: 'Kulturtechniken',
              description:
                  'Das Kind liest und schreibt altersgerechte Texte fluessig und erfasst dabei den Sinn des Inhalts.',
            ),
            DevelopmentMilestoneItem(
              code: 'KF.05',
              title: 'Logisches Denken',
              description:
                  'Das Kind versteht abstrakte Zusammenhaenge wie mathematische Regeln oder Bruchrechnen.',
            ),
            DevelopmentMilestoneItem(
              code: 'KF.06',
              title: 'Zeitgefühl',
              description:
                  'Das Kind liest die Uhrzeit verlässlich ab und kann seinen Tagesablauf danach planen.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sozial-emotional',
          items: [
            DevelopmentMilestoneItem(
              code: 'SE.04',
              title: 'Empathie',
              description:
                  'Das Kind erkennt und versteht komplexere Beweggruende für die Gefühle und das Verhalten anderer.',
            ),
            DevelopmentMilestoneItem(
              code: 'SE.05',
              title: 'Konfliktloesung',
              description:
                  'Das Kind loest kleinere Streitigkeiten mit Gleichaltrigen durch Kompromisse ohne Hilfe von Erwachsenen.',
            ),
            DevelopmentMilestoneItem(
              code: 'G.04',
              title: 'Metakognition',
              description:
                  'Das Kind kann Ursachen für seine eigenen Aengste, Freuden oder Sorgen benennen und reflektieren.',
            ),
          ],
        ),
      ],
    ),
    DevelopmentPhase(
      id: 'phase_12_18_y',
      ageRange: '12 bis 18 Jahre',
      title: 'Adoleszenz und Jugendalter',
      categories: [
        DevelopmentCategory(
          name: 'Identitaet und Psyche',
          items: [
            DevelopmentMilestoneItem(
              code: 'IP.01',
              title: 'Identitaetsfindung',
              description:
                  'Der Jugendliche entwickelt eigene moralische, politische oder gesellschaftliche Werte abseits des Elternhauses.',
            ),
            DevelopmentMilestoneItem(
              code: 'IP.02',
              title: 'Körperakzeptanz',
              description:
                  'Der Jugendliche geht reflektiert und akzeptierend mit den körperlichen Veränderungen der Pubertät um.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Sprache und Kognition',
          items: [
            DevelopmentMilestoneItem(
              code: 'KF.07',
              title: 'Hypothetisches Denken',
              description:
                  'Der Jugendliche denkt hypothetisch, analysiert vielschichtige Probleme und bildet sich eine fundierte Meinung.',
            ),
            DevelopmentMilestoneItem(
              code: 'KF.08',
              title: 'Zukunftsplanung',
              description:
                  'Der Jugendliche setzt konkrete und eigenständige Schritte zur beruflichen Orientierung um.',
            ),
          ],
        ),
        DevelopmentCategory(
          name: 'Alltagskompetenz und Sozial',
          items: [
            DevelopmentMilestoneItem(
              code: 'SE.06',
              title: 'Peer-Beziehungen',
              description:
                  'Der Jugendliche pflegt tiefgruendige, auf Vertrauen basierende Freundschaften oder Partnerschaften.',
            ),
            DevelopmentMilestoneItem(
              code: 'AK.02',
              title: 'Volle Autonomie',
              description:
                  'Der Jugendliche verwaltet Finanzen, persönliche Termine und behördliche Angelegenheiten komplett selbstständig.',
            ),
          ],
        ),
      ],
    ),
  ],
);
