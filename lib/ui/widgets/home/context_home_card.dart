import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

/// Kontextbasierte Home-Card — zeigt unterschiedliche Inhalte je nach Tageszeit.
///
/// Morgens (6-11):  "Dein Tag" — Termine + Tipp
/// Nachmittags (11-17): "Was macht ihr heute?" — Aktivitaet + Events-Teaser
/// Abends (17-23): "Ausatmen" — Mood-Check + Motivation
/// Nachts (23-6): "Schlaf gut" — Sanfte Nachricht
///
/// Personalisierung: Nutzt Kinder-Alter aus dem Profil für passende Inhalte.
class ContextHomeCard extends StatefulWidget {
  final VoidCallback? onExpandTip;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenActivity;
  final void Function(String mood, String? moment)? onMoodSelected;
  final VoidCallback? onOpenWeeklyReview;
  final VoidCallback? onShuffleActivity;

  const ContextHomeCard({
    super.key,
    this.onExpandTip,
    this.onOpenChat,
    this.onOpenCalendar,
    this.onOpenActivity,
    this.onMoodSelected,
    this.onOpenWeeklyReview,
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
  bool _momentDone = false;
  String? _selectedMood;
  int _historyCount = 0;
  final TextEditingController _momentCtrl = TextEditingController();
  int _tipIndex = 0;
  bool _showMaterials = false;

  @override
  void dispose() {
    _momentCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determineContext();
    _loadUserData();
  }

  void _determineContext() {
    final hour = DateTime.now().hour;
    final lang = languageService.currentLanguage;
    if (hour >= 6 && hour < 11) {
      _context = _TimeContext.morning;
      _greeting = AppStringsManager.getString(lang, 'greeting_morning');
    } else if (hour >= 11 && hour < 17) {
      _context = _TimeContext.afternoon;
      _greeting = 'Schön dass ihr da seid';
    } else if (hour >= 17 && hour < 23) {
      _context = _TimeContext.evening;
      _greeting = AppStringsManager.getString(lang, 'greeting_evening');
    } else {
      _context = _TimeContext.night;
      _greeting = AppStringsManager.getString(lang, 'sleep_well');
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await FamilyMatchProfile.load();

    // User-Name
    String name = prefs.getString('user.displayName') ?? '';
    if (name.isEmpty && profile != null) name = profile.displayName;
    if (name.isEmpty) name = '';

    // Kinder-Alter für Personalisierung
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

    // Restore mood-done state if already completed today
    final moodDateStr = prefs.getString('mood.today_date');
    bool alreadyDone = false;
    if (moodDateStr != null) {
      final moodDate = DateTime.tryParse(moodDateStr);
      if (moodDate != null) {
        final now = DateTime.now();
        alreadyDone = moodDate.year == now.year &&
            moodDate.month == now.month &&
            moodDate.day == now.day;
      }
    }
    // Count history entries for weekly review badge
    final historyRaw = prefs.getString('mood.history.v2');
    int histCount = 0;
    if (historyRaw != null && historyRaw.isNotEmpty) {
      try {
        histCount = (jsonDecode(historyRaw) as List).length;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _userName = name;
        _childAgeHint = ageHint;
        _nextEvent = nextEvent;
        _tip = tip;
        if (alreadyDone) {
          _moodDone = true;
          _momentDone = true;
        }
        _historyCount = histCount;
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
              'tip':
                  'Versteckspiel mit Tuechern: Du versteckst, Baby sucht. Foerdert Objektpermanenz.',
              'materials': 'Tuecher, Decke',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Krabbelwettrennen: Kriecht zusammen durch die Wohnung. Lachen garantiert.',
              'materials': 'Nichts noetig',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Topf-Orchester: Toepfe und Kochloeffel als Instrumente — Rhythmus foerdert Gehirnentwicklung.',
              'materials': 'Toepfe, Kochloeffel',
              'duration': '15 Min'
            },
            {
              'tip':
                  'Seifenblasen jagen: Draussen oder drinnen. Trainiert Hand-Augen-Koordination.',
              'materials': 'Seifenblasen',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Fingerspiele mit Gesang: "Alle meine Entchen" mit Fingerbewegungen.',
              'materials': 'Nichts noetig',
              'duration': '5 Min'
            },
            {
              'tip':
                  'Turmbauen und umwerfen: Baue einen Turm aus Bechern — Kind darf umhauen!',
              'materials': 'Plastikbecher oder Bauklötze',
              'duration': '15 Min'
            },
            {
              'tip':
                  'Spiegelspiel: Sitz mit Baby vor dem Spiegel und ahmt gemeinsam Mimik nach.',
              'materials': 'Spiegel',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Wasserspass: Schuessel mit lauwarmem Wasser, Becher und Loeffel eintauchen.',
              'materials': 'Schuessel, Wasser, Becher, Loeffel',
              'duration': '15 Min'
            },
            {
              'tip':
                  'Knisterpapier-Erkundung: Verschiedene Papiere und Tuecher befühlen und zerknuellen.',
              'materials': 'Zeitungspapier, Alufolie, weiches Tuch',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Ball rollen: Setzt euch gegenueber auf den Boden und rollt einen Ball hin und her.',
              'materials': 'Weicher Ball',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Schaukel-Lied: Kind auf den Knien wiegen und dabei ein ruhiges Lied summen.',
              'materials': 'Nichts noetig',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Koerperteil-Spiel: "Wo ist deine Nase?" — Baby zeigt und benennt mit.',
              'materials': 'Nichts noetig',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Schuettelbuechse basteln: Reiskoerner in eine leere Plastikflasche — selbst gemachtes Instrument.',
              'materials': 'Plastikflasche, Reiskoerner oder Linsen',
              'duration': '10 Min'
            },
            {
              'tip':
                  'Spaziergang mit Staunen: Langsam gehen und alles benennen, was ihr seht und hört.',
              'materials': 'Babytrage oder Kinderwagen',
              'duration': '20 Min'
            },
            {
              'tip':
                  'Klatsch-Rhythmus: Einfache Klatschspiele wie "Backe backe Kuchen" gemeinsam lernen.',
              'materials': 'Nichts noetig',
              'duration': '5 Min'
            },
          ]
        : age < 5
            ? [
                // ── Kleinkind 2–4 Jahre ────────────────────────────────────
                {
                  'tip':
                      'Schatzsuche im Wohnzimmer: Verstecke 5 Dinge und zeichne eine Schatzkarte.',
                  'materials': 'Papier, Stifte, 5 kleine Gegenstaende',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Verkleiden aus dem Schrank: Alte Klamotten, Huete, Tuecher — Theater spielen!',
                  'materials': 'Alte Kleidung, Accessoires',
                  'duration': '30 Min'
                },
                {
                  'tip':
                      'Barfuss-Parcours: Kissen, Handtuecher, Plastikfolie — verschiedene Texturen fühlen.',
                  'materials': 'Kissen, Handtuecher, Folie, Decken',
                  'duration': '15 Min'
                },
                {
                  'tip':
                      'Steine bemalen: Draussen sammeln, drinnen mit Wasserfarben verzieren.',
                  'materials': 'Steine, Wasserfarben, Pinsel',
                  'duration': '30 Min'
                },
                {
                  'tip':
                      'Karton-Burg: Grosse Kartons werden zu Haeusern, Autos oder Raketen.',
                  'materials': 'Grosse Kartons, Klebeband, Stifte',
                  'duration': '45 Min'
                },
                {
                  'tip':
                      'Knetmasse selber machen: Mehl + Salz + Wasser + Lebensmittelfarbe — selbst geknetet!',
                  'materials': 'Mehl, Salz, Wasser, Oel, Lebensmittelfarbe',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Pfützen-Springen: Nach dem Regen raus — Gummistiefel an und los!',
                  'materials': 'Gummistiefel, Regenjacke',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Kuchenbäckerei: Zusammen einen einfachen Rührkuchen backen.',
                  'materials': 'Mehl, Eier, Zucker, Butter, Backform',
                  'duration': '45 Min'
                },
                {
                  'tip':
                      'Schattentheater: Taschenlampe an die Wand, Hände formen Tiere und Figuren.',
                  'materials': 'Taschenlampe, dunkler Raum',
                  'duration': '15 Min'
                },
                {
                  'tip':
                      'Naturmandala: Blätter, Steine und Zweige draussen kreisfoermig legen.',
                  'materials': 'Naturmaterialien',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Hindernislauf: Stühle, Decken und Kissen als Tunnel und Brücke aufbauen.',
                  'materials': 'Stuehle, Decken, Kissen',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Farb-Experimente: Wasserfarben mischen — welche Farbe entsteht aus Blau und Gelb?',
                  'materials': 'Wasserfarben, Becher, Wasser, Papier',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Wetter-Malbuch: Jeden Tag das Wetter ins Heft zeichnen — Sonne, Wolken, Regen.',
                  'materials': 'Kleines Heft, Stifte',
                  'duration': '10 Min'
                },
                {
                  'tip':
                      'Matschküche draussen: Mit Wasser, Erde und Blaettern "Suppe kochen".',
                  'materials': 'Schuessel, Wasser, Naturmaterialien',
                  'duration': '30 Min'
                },
                {
                  'tip':
                      'Fingertheater: Gesichter auf Finger malen und gemeinsam eine Geschichte erfinden.',
                  'materials': 'Filzstifte (hautvertraeglich), Hände',
                  'duration': '15 Min'
                },
              ]
            : [
                // ── Schulkinder 5+ Jahre ───────────────────────────────────
                {
                  'tip':
                      'Schnitzeljagd im Park: Hinweise schreiben, Route planen, Schatz verstecken.',
                  'materials': 'Papier, Stifte, kleiner Schatz',
                  'duration': '45 Min'
                },
                {
                  'tip':
                      'Familien-Quiz: Jeder schreibt 5 Fragen ueber sich — wer kennt wen am besten?',
                  'materials': 'Papier, Stifte',
                  'duration': '30 Min'
                },
                {
                  'tip':
                      'Geocaching: Kostenlose App, draussen Schaetze suchen — echtes Abenteuer.',
                  'materials': 'Smartphone mit Geocaching-App',
                  'duration': '60 Min'
                },
                {
                  'tip':
                      'Comic zeichnen: Zusammen eine kurze Geschichte als Comicstrip erzählen.',
                  'materials': 'Papier, Stifte, Buntstifte',
                  'duration': '30 Min'
                },
                {
                  'tip':
                      'Fotosafari: Handy-Kamera und eine Liste: Finde etwas Rotes, Rundes, Weiches...',
                  'materials': 'Smartphone, ausgedruckte Liste',
                  'duration': '30 Min'
                },
                {
                  'tip':
                      'Wissenschafts-Labor: Backpulver-Essig-Vulkan, Geheimschrift mit Zitronensaft.',
                  'materials':
                      'Backpulver, Essig, Zitrone, Glas, Wattestäbchen',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Lager im Wohnzimmer: Decken, Kissen, Lichterkette — Zeltuebernachtung drinnen.',
                  'materials': 'Decken, Kissen, Lichterkette, Taschenlampe',
                  'duration': '60 Min'
                },
                {
                  'tip':
                      'Brettspiel-Turnier: 3 Runden hintereinander, gemeinsam Punkte zählen.',
                  'materials': 'Brettspiele, Snacks',
                  'duration': '60 Min'
                },
                {
                  'tip':
                      'Kurzfilm drehen: Geschichte erfinden, Rollen verteilen, mit dem Handy aufnehmen.',
                  'materials': 'Smartphone, optional Verkleidung',
                  'duration': '60 Min'
                },
                {
                  'tip':
                      'Pflanzenprojekt: Samen in Erde pflanzen, Wachstum täglichbeobachten und notieren.',
                  'materials': 'Blumentopf, Erde, Samen, kleines Heft',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Brief an die Zukunft: Schreibe heute einen Brief ans eigene Ich in 5 Jahren.',
                  'materials': 'Papier, Briefumschlag, Stift',
                  'duration': '20 Min'
                },
                {
                  'tip':
                      'Kochduell: Jedes Familienmitglied kocht oder bereitet einen Gang zu.',
                  'materials': 'Kuehlschrankinhalt, Kochgeschirr',
                  'duration': '45 Min'
                },
                {
                  'tip':
                      'Naturtagebuch: Vögel, Insekten und Pflanzen draussen zeichnen und benennen.',
                  'materials': 'Kleines Heft, Stifte, Buntstifte',
                  'duration': '40 Min'
                },
                {
                  'tip':
                      'Familien-Escape-Room: Raetsel für die ganze Familie selber erfinden und loesen.',
                  'materials':
                      'Papier, Stifte, Alltagsgegenstaende als Requisiten',
                  'duration': '60 Min'
                },
                {
                  'tip':
                      'Sternenhimmel beobachten: Abends raus oder Fenster auf, Sternbilder mit App suchen.',
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
        const SizedBox(height: 8),
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
                      color: const Color(0xFFD97706))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                _showMaterials
                    ? '\u{1F9F0} $_tipMaterials'
                    : '\u{1F9F0} ${AppStringsManager.getString(languageService.currentLanguage, 'what_you_need')} \u{25BC}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFF92400E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        ),
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
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _miniButton(
            theme,
            '\u{1F3B2} ${AppStringsManager.getString(languageService.currentLanguage, 'new_activity')}',
            const Color(0xFFD97706),
            _shuffleTip,
          ),
        ),
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
                Text(
                    _userName.isNotEmpty
                        ? 'Hallo $_userName!'
                        : AppStringsManager.getString(
                            languageService.currentLanguage, 'hello_family'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                    AppStringsManager.getString(
                        languageService.currentLanguage, 'what_today_together'),
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
                    : '\u{1F9F0} ${AppStringsManager.getString(languageService.currentLanguage, 'what_you_need')} \u{25BC}',
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
            '\u{1F3B2} ${AppStringsManager.getString(languageService.currentLanguage, 'new_activity')}',
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
          Text(AppStringsManager.getString(languageService.currentLanguage, 'how_was_your_day'),
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B21A8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _moodEmoji('\u{1F60A}', 'Super', const Color(0xFF16A34A)),
            _moodEmoji('\u{1F642}', 'Gut', const Color(0xFF2563EB)),
            _moodEmoji('\u{1F610}', 'Okay', const Color(0xFFF97316)),
            _moodEmoji('\u{1F614}', 'Mühsam', const Color(0xFFDC2626)),
            _moodEmoji('\u{1F970}', 'Dankbar', const Color(0xFFEC4899)),
          ]),
        ] else if (!_momentDone) ...[
          _momentQuestion(theme),
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
          if (_historyCount >= 1 && widget.onOpenWeeklyReview != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.onOpenWeeklyReview,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('✨ Deine Woche ansehen',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        Text('\u{1F4A1} $_tip',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF7C3AED), height: 1.3)),
        const SizedBox(height: 8),
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
                      color: const Color(0xFF7C3AED))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                _showMaterials
                    ? '\u{1F9F0} $_tipMaterials'
                    : '\u{1F9F0} ${AppStringsManager.getString(languageService.currentLanguage, 'what_you_need')} \u{25BC}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFF6B21A8)),
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
            '\u{1F3B2} ${AppStringsManager.getString(languageService.currentLanguage, 'new_activity')}',
            const Color(0xFF7C3AED),
            _shuffleTip,
          ),
        ),
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
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'rest_message'),
            style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8), height: 1.4)),
        const SizedBox(height: 12),
        Text('\u{1F3A8} $_tip',
            style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7), height: 1.3)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _showMaterials = !_showMaterials),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Text('\u{23F1}\u{FE0F} $_tipDuration',
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                _showMaterials
                    ? '\u{1F9F0} $_tipMaterials'
                    : '\u{1F9F0} ${AppStringsManager.getString(languageService.currentLanguage, 'what_you_need')} \u{25BC}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
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
            '\u{1F3B2} ${AppStringsManager.getString(languageService.currentLanguage, 'new_activity')}',
            Colors.white,
            _shuffleTip,
          ),
        ),
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

  Widget _momentQuestion(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('✨', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Was war heute dein schönster Moment?',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B21A8), fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _momentCtrl,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Ein Moment mit meinem Kind …',
            hintStyle: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF9CA3AF)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: const Color(0xFFF9F7FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _saveMoment,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(AppStringsManager.getString(languageService.currentLanguage, 'save_mood'),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _saveMoment(skip: true),
            child: Text('Überspringen',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFF9CA3AF))),
          ),
        ]),
      ]),
    );
  }

  void _saveMoment({bool skip = false}) {
    final text = _momentCtrl.text.trim();
    final moment = (!skip && text.isNotEmpty) ? text : null;
    setState(() {
      _momentDone = true;
      _historyCount = _historyCount + 1;
    });
    widget.onMoodSelected?.call(_selectedMood ?? '', moment);
  }

  Widget _moodEmoji(String emoji, String label, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _moodDone = true;
          _selectedMood = label;
        });
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
