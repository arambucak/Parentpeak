import 'dart:convert';
import 'package:flutter/material.dart';
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

  const ContextHomeCard({
    super.key,
    this.onExpandTip,
    this.onOpenChat,
    this.onOpenCalendar,
    this.onOpenActivity,
    this.onMoodSelected,
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
  String? _nextEvent;
  int _childAgeHint = 3;
  bool _moodDone = false;

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
      _greeting = 'Hey';
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
    if (name.isEmpty) name = 'du';

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

  String _getTip(int age) {
    final tips = age < 2
        ? [
            'Babys lernen durch Wiederholung. Heute: Peekaboo spielen!',
            'Hautkontakt beruhigt. 10 Minuten kuscheln wirkt Wunder.',
            'Singe deinem Baby vor — egal wie. Deine Stimme ist Musik.',
          ]
        : age < 5
            ? [
                'Kinder brauchen keine perfekten Eltern, sondern echte.',
                'Langeweile ist kreativ. Lass 10 Minuten ungeplant.',
                'Gemeinsam Steine sammeln: Sortieren foerdert Mathe-Denken.',
              ]
            : [
                'Schulkinder brauchen nach der Schule 30 Min Ruhe ohne Fragen.',
                'Zusammen kochen: Abwiegen, Zaehlen, Schmecken — Lernen pur.',
                'Frag heute: Was war das Lustigste in deinem Tag?',
              ];
    return tips[DateTime.now().day % tips.length];
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
                Text('$_greeting, $_userName!',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('Was macht ihr heute?',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF16A34A))),
              ])),
        ]),
        const SizedBox(height: 14),
        Text('\u{1F3A8} $_tip',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF166534), height: 1.4)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _miniButton(
            theme,
            '\u{1F4A1} Neue Idee',
            const Color(0xFF16A34A),
            widget.onOpenActivity,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _miniButton(
            theme, '\u{1F389} Events', const Color(0xFF8B5CF6),
            null, // Events handled via Quick-Actions
          )),
        ]),
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
          Text('$_greeting, $_userName',
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
                'Du machst das gut. Morgen ist ein neuer Tag.',
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
          Text('$_greeting, $_userName',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color))),
      ),
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
