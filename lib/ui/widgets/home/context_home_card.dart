import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// Kontextbasierte Home-Card — zeigt unterschiedliche Inhalte je nach Tageszeit.
///
/// Morgens (6-11):  "Dein Tag" — Termine + Tipp
/// Nachmittags (11-17): "Was macht ihr heute?" — Aktivitaet + Events-Teaser
/// Abends (17-23): "Ausatmen" — Mood-Check + Motivation
/// Nachts (23-6): "Schlaf gut" — Sanfte Nachricht
///
/// Personalisierung: Nutzt Kinder-Alter aus dem Profil fuer passende Inhalte.
class ContextHomeCard extends StatefulWidget {
  final VoidCallback? onExpandTip;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenActivity;
  final void Function(String mood)? onMoodSelected;
  final VoidCallback? onShuffleActivity; // NEU: Spielidee shufflen

  const ContextHomeCard({
    super.key,
    this.onExpandTip,
    this.onOpenChat,
    this.onOpenCalendar,
    this.onOpenActivity,
    this.onMoodSelected,
    this.onShuffleActivity,
  });

  @override
  State<ContextHomeCard> createState() => _ContextHomeCardState();
}

enum _TimeContext { morning, afternoon, evening, night }

class _ContextHomeCardState extends State<ContextHomeCard> {
  _TimeContext _context = _TimeContext.afternoon;
  String _greeting = '';
  String _userName = '';
  String _tip = '';
  String _tipMaterials = '';
  String _tipDuration = '';
  String? _nextEvent;
  int _childAgeHint = 3;
  bool _moodDone = false;
  int _tipIndex = 0;
  bool _showMaterials = false;

  @override
  void initState() {
    super.initState();
    _determineContext();
    _loadUserData();
  }

  void _determineContext() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      _context = _TimeContext.morning;
      _greeting = 'Guten Morgen';
    } else if (hour >= 11 && hour < 17) {
      _context = _TimeContext.afternoon;
      _greeting = 'Schoen dass ihr da seid';
    } else if (hour >= 17 && hour < 23) {
      _context = _TimeContext.evening;
      _greeting = 'Guten Abend';
    } else {
      _context = _TimeContext.night;
      _greeting = 'Schlaf gut';
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await FamilyMatchProfile.load();

    // User-Name
    String name = prefs.getString('user.displayName') ?? '';
    if (name.isEmpty && profile != null) name = profile.displayName;
    if (name.isEmpty) name = '';

    // Kinder-Alter fuer Personalisierung
    int ageHint = 3;
    if (profile != null && profile.children.isNotEmpty) {
      ageHint = (profile.children.first.ageMonths / 12).round().clamp(0, 16);
    }

    // Naechster Termin
    final calRaw = prefs.getString('calendar.events');
    String? nextEvent;
    if (calRaw != null && calRaw.isNotEmpty) {
      try {
        final events = (jsonDecode(calRaw) as List)
            .map((e) => e as Map<String, dynamic>)
            .where((e) {
          final date = DateTime.tryParse(e['date']?.toString() ?? '');
          return date != null && date.isAfter(DateTime.now());
        }).toList()
          ..sort(
              (a, b) => (a['date'] as String).compareTo(b['date'] as String));
        if (events.isNotEmpty) {
          nextEvent = events.first['title']?.toString();
        }
      } catch (_) {}
    }

    // Tagesspezifischer Tipp
    final tip = _getTip(ageHint);

    if (mounted) {
      setState(() {
        _userName = name;
        _childAgeHint = ageHint;
        _nextEvent = nextEvent;
        _tip = tip;
      });
    }
  }

  /// Monatlicher Basis-Index: wechselt jeden Monat automatisch,
  /// sodass Eltern bei App-Oeffnung jedesmal eine andere Idee sehen.
  int _monthlyBase() {
    final now = DateTime.now();
    return now.year * 12 + now.month;
  }

  void _shuffleTip() {
    _tipIndex++;
    _showMaterials = false;
    final data = _getTipData(_childAgeHint, _monthlyBase() + _tipIndex);
    setState(() {
      _tip = data['tip']!;
      _tipMaterials = data['materials']!;
      _tipDuration = data['duration']!;
    });
  }

  String _getTip(int age) {
    final data = _getTipData(age, _monthlyBase());
    _tipMaterials = data['materials']!;
    _tipDuration = data['duration']!;
    return data['tip']!;
  }

  Map<String, String> _getTipData(int age, int index) {
    final tips = age < 2
        ? [
            // ── Babys & Krabbelalter ──────────────────────────────────────
            {
              'tip': 'Versteckspiel mit Tuechern: Du versteckst, Baby sucht. Foerdert Objektpermanenz.',
              'materials': 'Tuecher, Decke',
              'duration': '10 Min'
            },
            {
              'tip': 'Krabbelwettrennen: Kriecht zusammen durch die Wohnung. Lachen garantiert.',
              'materials': 'Nichts noetig',
              'duration': '10 Min'
            },
            {
              'tip': 'Topf-Orchester: Toepfe und Kochloeffel als Instrumente — Rhythmus foerdert Gehirnentwicklung.',
              'materials': 'Toepfe, Kochloeffel',
              'duration': '15 Min'
            },
            {
              'tip': 'Seifenblasen jagen: Draussen oder drinnen. Trainiert Hand-Augen-Koordination.',
              'materials': 'Seifenblasen',
              'duration': '10 Min'
            },
            {
              'tip': 'Fingerspiele mit Gesang: "Alle meine Entchen" mit Fingerbewegungen.',
              'materials': 'Nichts noetig',
              'duration': '5 Min'
            },
            {
              'tip': 'Turmbauen und umwerfen: Baue einen Turm aus Bechern — Kind darf umhauen!',
              'materials': 'Plastikbecher oder Bauklötze',
              'duration': '15 Min'
            },
            {
              'tip': 'Spiegelspiel: Sitz mit Baby vor dem Spiegel und ahmt gemeinsam Mimik nach.',
              'materials': 'Spiegel',
              'duration': '10 Min'
            },
            {
              'tip': 'Wasserspass: Schuessel mit lauwarmem Wasser, Becher und Loeffel eintauchen.',
              'materials': 'Schuessel, Wasser, Becher, Loeffel',
              'duration': '15 Min'
            },
            {
              'tip': 'Knisterpapier-Erkundung: Verschiedene Papiere und Tuecher befuehlen und zerknuellen.',
              'materials': 'Zeitungspapier, Alufolie, weiches Tuch',
              'duration': '10 Min'
            },
            {
              'tip': 'Ball rollen: Setzt euch gegenueber auf den Boden und rollt einen Ball hin und her.',
              'materials': 'Weicher Ball',
              'duration': '10 Min'
            },
            {
              'tip': 'Schaukel-Lied: Kind auf den Knien wiegen und dabei ein ruhiges Lied summen.',
              'materials': 'Nichts noetig',
              'duration': '10 Min'
            },
            {
              'tip': 'Koerperteil-Spiel: "Wo ist deine Nase?" — Baby zeigt und benennt mit.',
              'materials': 'Nichts noetig',
              'duration': '10 Min'
            },
            {
              'tip': 'Schuettelbuechse basteln: Reiskoerner in eine leere Plastikflasche — selbst gemachtes Instrument.',
              'materials': 'Plastikflasche, Reiskoerner oder Linsen',
              'duration': '10 Min'
            },
            {
              'tip': 'Spaziergang mit Staunen: Langsam gehen und alles benennen, was ihr seht und hoert.',
              'materials': 'Babytrage oder Kinderwagen',
              'duration': '20 Min'
            },
            {
              'tip': 'Klatsch-Rhythmus: Einfache Klatschspiele wie "Backe backe Kuchen" gemeinsam lernen.',
              'materials': 'Nichts noetig',
              'duration': '5 Min'
            },
          ]
        : age < 5
            ? [
                // ── Kleinkind 2–4 Jahre ────────────────────────────────────
                {
                  'tip': 'Schatzsuche im Wohnzimmer: Verstecke 5 Dinge und zeichne eine Schatzkarte.',
                  'materials': 'Papier, Stifte, 5 kleine Gegenstaende',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Verkleiden aus dem Schrank: Alte Klamotten, Huete, Tuecher — Theater spielen!',
                  'materials': 'Alte Kleidung, Accessoires',
                  'duration': '30 Min'
                },
                {
                  'tip': 'Barfuss-Parcours: Kissen, Handtuecher, Plastikfolie — verschiedene Texturen fühlen.',
                  'materials': 'Kissen, Handtuecher, Folie, Decken',
                  'duration': '15 Min'
                },
                {
                  'tip': 'Steine bemalen: Draussen sammeln, drinnen mit Wasserfarben verzieren.',
                  'materials': 'Steine, Wasserfarben, Pinsel',
                  'duration': '30 Min'
                },
                {
                  'tip': 'Karton-Burg: Grosse Kartons werden zu Haeusern, Autos oder Raketen.',
                  'materials': 'Grosse Kartons, Klebeband, Stifte',
                  'duration': '45 Min'
                },
                {
                  'tip': 'Knetmasse selber machen: Mehl + Salz + Wasser + Lebensmittelfarbe — selbst geknetet!',
                  'materials': 'Mehl, Salz, Wasser, Oel, Lebensmittelfarbe',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Pfuetzen-Springen: Nach dem Regen raus — Gummistiefel an und los!',
                  'materials': 'Gummistiefel, Regenjacke',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Kuchenbaeckerei: Zusammen einen einfachen Ruehrkuchen backen.',
                  'materials': 'Mehl, Eier, Zucker, Butter, Backform',
                  'duration': '45 Min'
                },
                {
                  'tip': 'Schattentheater: Taschenlampe an die Wand, Haende formen Tiere und Figuren.',
                  'materials': 'Taschenlampe, dunkler Raum',
                  'duration': '15 Min'
                },
                {
                  'tip': 'Naturmandala: Blätter, Steine und Zweige draussen kreisfoermig legen.',
                  'materials': 'Naturmaterialien',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Hindernislauf: Stühle, Decken und Kissen als Tunnel und Bruecke aufbauen.',
                  'materials': 'Stuehle, Decken, Kissen',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Farb-Experimente: Wasserfarben mischen — welche Farbe entsteht aus Blau und Gelb?',
                  'materials': 'Wasserfarben, Becher, Wasser, Papier',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Wetter-Malbuch: Jeden Tag das Wetter ins Heft zeichnen — Sonne, Wolken, Regen.',
                  'materials': 'Kleines Heft, Stifte',
                  'duration': '10 Min'
                },
                {
                  'tip': 'Matschkueche draussen: Mit Wasser, Erde und Blaettern "Suppe kochen".',
                  'materials': 'Schuessel, Wasser, Naturmaterialien',
                  'duration': '30 Min'
                },
                {
                  'tip': 'Fingertheater: Gesichter auf Finger malen und gemeinsam eine Geschichte erfinden.',
                  'materials': 'Filzstifte (hautvertraeglich), Haende',
                  'duration': '15 Min'
                },
              ]
            : [
                // ── Schulkinder 5+ Jahre ───────────────────────────────────
                {
                  'tip': 'Schnitzeljagd im Park: Hinweise schreiben, Route planen, Schatz verstecken.',
                  'materials': 'Papier, Stifte, kleiner Schatz',
                  'duration': '45 Min'
                },
                {
                  'tip': 'Familien-Quiz: Jeder schreibt 5 Fragen ueber sich — wer kennt wen am besten?',
                  'materials': 'Papier, Stifte',
                  'duration': '30 Min'
                },
                {
                  'tip': 'Geocaching: Kostenlose App, draussen Schaetze suchen — echtes Abenteuer.',
                  'materials': 'Smartphone mit Geocaching-App',
                  'duration': '60 Min'
                },
                {
                  'tip': 'Comic zeichnen: Zusammen eine kurze Geschichte als Comicstrip erzaehlen.',
                  'materials': 'Papier, Stifte, Buntstifte',
                  'duration': '30 Min'
                },
                {
                  'tip': 'Fotosafari: Handy-Kamera und eine Liste: Finde etwas Rotes, Rundes, Weiches...',
                  'materials': 'Smartphone, ausgedruckte Liste',
                  'duration': '30 Min'
                },
                {
                  'tip': 'Wissenschafts-Labor: Backpulver-Essig-Vulkan, Geheimschrift mit Zitronensaft.',
                  'materials': 'Backpulver, Essig, Zitrone, Glas, Wattestäbchen',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Lager im Wohnzimmer: Decken, Kissen, Lichterkette — Zeltuebernachtung drinnen.',
                  'materials': 'Decken, Kissen, Lichterkette, Taschenlampe',
                  'duration': '60 Min'
                },
                {
                  'tip': 'Brettspiel-Turnier: 3 Runden hintereinander, gemeinsam Punkte zaehlen.',
                  'materials': 'Brettspiele, Snacks',
                  'duration': '60 Min'
                },
                {
                  'tip': 'Kurzfilm drehen: Geschichte erfinden, Rollen verteilen, mit dem Handy aufnehmen.',
                  'materials': 'Smartphone, optional Verkleidung',
                  'duration': '60 Min'
                },
                {
                  'tip': 'Pflanzenprojekt: Samen in Erde pflanzen, Wachstum taeglichbeobachten und notieren.',
                  'materials': 'Blumentopf, Erde, Samen, kleines Heft',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Brief an die Zukunft: Schreibe heute einen Brief ans eigene Ich in 5 Jahren.',
                  'materials': 'Papier, Briefumschlag, Stift',
                  'duration': '20 Min'
                },
                {
                  'tip': 'Kochduell: Jedes Familienmitglied kocht oder bereitet einen Gang zu.',
                  'materials': 'Kuehlschrankinhalt, Kochgeschirr',
                  'duration': '45 Min'
                },
                {
                  'tip': 'Naturtagebuch: Vögel, Insekten und Pflanzen draussen zeichnen und benennen.',
                  'materials': 'Kleines Heft, Stifte, Buntstifte',
                  'duration': '40 Min'
                },
                {
                  'tip': 'Familien-Escape-Room: Raetsel fuer die ganze Familie selber erfinden und loesen.',
                  'materials': 'Papier, Stifte, Alltagsgegenstaende als Requisiten',
                  'duration': '60 Min'
                },
                {
                  'tip': 'Sternenhimmel beobachten: Abends raus oder Fenster auf, Sternbilder mit App suchen.',
                  'materials': 'Sternenhimmel-App (z.B. Sky Map), Decke',
                  'duration': '30 Min'
                },
              ];
    final item = tips[index % tips.length];
    return item;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (_context) {
      case _TimeContext.morning:
        return _morningCard(theme);
      case _TimeContext.afternoon:
        return _afternoonCard(theme);
      case _TimeContext.evening:
        return _eveningCard(theme);
      case _TimeContext.night:
        return _nightCard(theme);
    }
  }

  // ─── MORGENS: "Dein Tag" ──────────────────────────────────────────────────
  Widget _morningCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('\u{2600}\u{FE0F}', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text('$_greeting, $_userName!',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        if (_nextEvent != null) ...[
          GestureDetector(
            onTap: widget.onOpenCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_nextEvent!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: Color(0xFFD97706)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text('\u{1F4A1} $_tip',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF92400E), height: 1.4)),
        if (widget.onExpandTip != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: widget.onExpandTip,
            child: Text('\u{2728} Erklaere mir das genauer \u{2192}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFD97706),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  // ─── NACHMITTAGS: "Was macht ihr heute?" ──────────────────────────────────
  Widget _afternoonCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('\u{1F31E}', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_userName.isNotEmpty ? 'Hallo $_userName!' : 'Hallo ihr!',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('Was macht ihr heute zusammen?',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF16A34A))),
              ])),
        ]),
        const SizedBox(height: 14),
        Text('\u{1F3A8} $_tip',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF166534), height: 1.4)),
        const SizedBox(height: 8),
        // Dauer + Materialien (kompakt)
        GestureDetector(
          onTap: () => setState(() => _showMaterials = !_showMaterials),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Text('\u{23F1}\u{FE0F} $_tipDuration',
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                _showMaterials
                    ? '\u{1F9F0} $_tipMaterials'
                    : '\u{1F9F0} Was ihr braucht \u{25BC}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFF166534)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _miniButton(
            theme,
            '\u{1F3B2} Neue Spielidee',
            const Color(0xFF16A34A),
            _shuffleTip,
          ),
        ),
      ]),
    );
  }

  // ─── ABENDS: "Ausatmen" ───────────────────────────────────────────────────
  Widget _eveningCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('\u{1F319}', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text(_userName.isNotEmpty ? '$_greeting, $_userName' : '$_greeting',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        if (!_moodDone) ...[
          Text('Wie war dein Tag?',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B21A8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _moodEmoji('\u{1F60A}', 'Super', const Color(0xFF16A34A)),
            _moodEmoji('\u{1F642}', 'Gut', const Color(0xFF2563EB)),
            _moodEmoji('\u{1F610}', 'Okay', const Color(0xFFF97316)),
            _moodEmoji('\u{1F614}', 'Muehsam', const Color(0xFFDC2626)),
            _moodEmoji('\u{1F970}', 'Dankbar', const Color(0xFFEC4899)),
          ]),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Text('\u{1F49C}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Du bist da. Morgen ist ein neuer Tag.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B21A8),
                    fontStyle: FontStyle.italic),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Text('\u{1F4A1} $_tip',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF7C3AED), height: 1.3)),
      ]),
    );
  }

  // ─── NACHTS: Minimal ──────────────────────────────────────────────────────
  Widget _nightCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u{1F31F}', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text(_userName.isNotEmpty ? '$_greeting, $_userName' : _greeting,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        const SizedBox(height: 10),
        Text('Ruh dich aus. Morgen seid ihr wieder ein tolles Team.',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8), height: 1.4)),
      ]),
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────────────

  Widget _miniButton(
      ThemeData theme, String label, Color color, VoidCallback? onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _moodEmoji(String emoji, String label, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() => _moodDone = true);
        widget.onMoodSelected?.call(label);
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
