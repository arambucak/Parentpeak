import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';

class RitualRuheScreen extends StatefulWidget {
  const RitualRuheScreen({super.key});

  @override
  State<RitualRuheScreen> createState() => _RitualRuheScreenState();
}

class _RitualRuheScreenState extends State<RitualRuheScreen> {
  static const _quietModeKey = 'ritual_ruhe.quiet_mode';
  final _gratitudeController = TextEditingController();
  List<KindDossier> _children = const [];
  int _selectedChild = 0;
  Set<String> _completed = <String>{};
  bool _quietMode = false;
  bool _loading = true;
  bool _storyLoading = false;
  String? _story;
  String? _ageNotice;
  Timer? _ritualTimer;
  int _secondsRemaining = 0;

  bool get _isEvening {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  KindDossier? get _child => _children.isEmpty
      ? null
      : _children[_selectedChild.clamp(0, _children.length - 1)];

  int get _ageMonths => _child?.ageMonths ?? 60;
  int get _ageYears => (_ageMonths / 12).floor();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ritualTimer?.cancel();
    _gratitudeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await KindDossierService.instance.load();
    var children = KindDossierService.instance.dossiers;
    if (children.isEmpty) {
      final profile = await FamilyMatchProfile.load();
      children = profile?.children
              .map((child) => KindDossier(
                    childName: child.name,
                    birthDate: child.birthDate,
                    ageMonths: child.ageMonths,
                  ))
              .toList() ??
          const [];
    }
    if (!mounted) return;
    setState(() {
      _children = children;
      _quietMode = prefs.getBool(_quietModeKey) ?? false;
      _loading = false;
    });
    final ageKey = 'ritual_ruhe.age.${_child?.childName ?? 'family'}';
    final previousAge = prefs.getInt(ageKey);
    final currentAge = _child?.ageYears ?? 0;
    if (previousAge != null && previousAge != currentAge && mounted) {
      setState(() => _ageNotice =
          '${_child?.childName ?? 'Euer Kind'} ist jetzt $currentAge — mögt ihr die Rituale gemeinsam anpassen?');
    }
    await prefs.setInt(ageKey, currentAge);
    await _loadChildState();
  }

  String get _stateKey =>
      'ritual_ruhe.state.${_child?.childName ?? 'family'}.${DateTime.now().toIso8601String().substring(0, 10)}';

  Future<void> _loadChildState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    final state = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _completed = (state['completed'] as List? ?? []).cast<String>().toSet();
      _gratitudeController.text = state['gratitude']?.toString() ?? '';
      _story = state['story']?.toString();
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _stateKey,
        jsonEncode({
          'completed': _completed.toList(),
          'gratitude': _gratitudeController.text.trim(),
          if (_story != null) 'story': _story,
        }));
  }

  List<_RitualStep> get _steps {
    if (!_isEvening) {
      return [
        const _RitualStep('aufstehen', 'Guten Morgen', Icons.wb_sunny_rounded,
            'Langsam ankommen'),
        const _RitualStep('anziehen', 'Anziehen', Icons.checkroom_rounded,
            'Etwas Bequemes finden'),
        const _RitualStep('fruehstueck', 'Frühstück',
            Icons.breakfast_dining_rounded, 'Gemeinsam in den Tag starten'),
        const _RitualStep('tasche', 'Bereit für den Tag',
            Icons.backpack_rounded, 'Was brauchen wir heute?'),
      ];
    }
    if (_ageYears < 5) {
      return [
        const _RitualStep('waschen', 'Waschen', Icons.water_drop_rounded,
            'Gesicht und Hände werden ruhig'),
        const _RitualStep('zaehne', 'Zähne putzen', Icons.clean_hands_rounded,
            'Kleine Kreise, ganz in Ruhe'),
        const _RitualStep('kuscheln', 'Kuscheln', Icons.favorite_rounded,
            'Noch ein lieber Moment'),
      ];
    }
    if (_ageYears < 8) {
      return [
        const _RitualStep('waschen', 'Waschen', Icons.water_drop_rounded,
            'Frisch und gemütlich werden'),
        const _RitualStep('zaehne', 'Zähne putzen', Icons.clean_hands_rounded,
            'Der Mund bekommt seine Nachtpflege'),
        const _RitualStep('morgen', 'Für morgen vorbereiten',
            Icons.checkroom_rounded, 'Lieblingskleidung bereitlegen'),
        const _RitualStep('geschichte', 'Geschichte aussuchen',
            Icons.auto_stories_rounded, 'Eine ruhige Geschichte wartet'),
      ];
    }
    if (_ageYears < 11) {
      return [
        const _RitualStep('zaehne', 'Zähne putzen', Icons.clean_hands_rounded,
            'In Ruhe fertig werden'),
        const _RitualStep('morgen', 'Morgen vorbereiten',
            Icons.backpack_rounded, 'Tasche und Kleidung bereitlegen'),
        const _RitualStep('aufräumen', 'Kurz Ordnung schaffen',
            Icons.auto_awesome_rounded, 'Ein kleiner Handgriff für morgen'),
        const _RitualStep('reflexion', 'Tagesmoment',
            Icons.chat_bubble_outline_rounded, 'Was war heute gut?'),
      ];
    }
    return [
      const _RitualStep('morgen', 'Morgen vorbereiten', Icons.backpack_rounded,
          'Tasche, Kleidung und Wecker'),
      const _RitualStep('abschluss', 'Tag abschließen', Icons.nightlight_round,
          'Was darf für heute losgelassen werden?'),
      const _RitualStep('reflexion', 'Ein guter Moment',
          Icons.favorite_border_rounded, 'Ein Satz für dich selbst'),
    ];
  }

  Future<void> _toggleStep(String id) async {
    setState(() {
      if (!_completed.remove(id)) _completed.add(id);
    });
    await _saveState();
  }

  Future<void> _toggleQuietMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quietModeKey, value);
    if (mounted) setState(() => _quietMode = value);
  }

  void _startTimer() {
    _ritualTimer?.cancel();
    setState(() => _secondsRemaining = 120);
    _ritualTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _timerLabel {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _generateStory() async {
    final child = _child;
    if (child == null || _storyLoading) return;
    setState(() => _storyLoading = true);
    try {
      final story = await GeminiAIService().generateText(
        'Schreibe eine kurze Gute-Nacht-Geschichte für ein Kind, etwa $_ageYears Jahre alt. Thema: Mut, Geborgenheit und ein kleiner freundlicher Moment. 350 bis 500 Wörter. Verwende keine Namen und keine persönlichen Daten.',
        systemInstruction:
            'Du bist eine ruhige, inklusive Kinderbuchautorin. Schreibe warm, beruhigend und altersgerecht auf Deutsch. Keine Angst, Gewalt, Diagnosen oder Leistungsdruck. Gib nur die Geschichte zurück, ohne Überschrift oder Erklärung.',
        appLanguage: 'de',
      );
      if (mounted) setState(() => _story = story.trim());
    } catch (_) {
      if (mounted) setState(() => _story = _fallbackStory(child.childName));
    } finally {
      if (mounted) {
        setState(() => _storyLoading = false);
        await _saveState();
      }
    }
  }

  String _fallbackStory(String name) =>
      'Als ${name.isEmpty ? 'ein Kind' : name} am Abend aus dem Fenster schaute, sah es einen kleinen Stern, der besonders freundlich funkelte. Der Stern erinnerte ${name.isEmpty ? 'das Kind' : name} daran, dass jeder Tag kleine gute Momente trägt: ein Lächeln, eine warme Hand und ein Zuhause, in dem man einfach sein darf.\n\nDer Wind flüsterte: „Für heute ist genug geschafft.“ ${name.isEmpty ? 'Das Kind' : name} kuschelte sich ein. Der Stern blieb noch ein wenig am Fenster und passte auf. Dann wurde alles still und weich, bis der neue Morgen kam.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = _child;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        title: Text(_isEvening ? 'Gute Nacht' : 'Guten Morgen'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Ruhemodus',
            onPressed: () => _toggleQuietMode(!_quietMode),
            icon: Icon(_quietMode
                ? Icons.notifications_off_rounded
                : Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : child == null
              ? _EmptyChildState(onOpenProfile: () => Navigator.pop(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                  children: [
                    if (_ageNotice != null) _buildAgeNotice(theme),
                    if (_children.length > 1) _buildChildSwitcher(theme),
                    _buildWelcome(theme, child),
                    const SizedBox(height: 18),
                    _buildRitualCard(theme),
                    if (_isEvening) ...[
                      const SizedBox(height: 16),
                      _buildStoryCard(theme, child),
                      const SizedBox(height: 16),
                      _buildGratitudeCard(theme),
                    ],
                  ],
                ),
    );
  }

  Widget _buildChildSwitcher(ThemeData theme) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _children.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => ChoiceChip(
            selected: index == _selectedChild,
            label: Text(_children[index].childName),
            avatar: const Icon(Icons.child_care_rounded, size: 18),
            onSelected: (_) async {
              setState(() => _selectedChild = index);
              await _loadChildState();
            },
          ),
        ),
      );

  Widget _buildWelcome(ThemeData theme, KindDossier child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF385A75), Color(0xFF6E7BA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_isEvening ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: const Color(0xFFFFD98A), size: 32),
          const SizedBox(height: 18),
          Text(
            _isEvening
                ? 'Zeit zum Runterkommen'
                : 'Guten Morgen, ${child.childName}',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            _isEvening
                ? 'Ein kleiner, ruhiger Schritt nach dem anderen.'
                : 'Was würde euch heute gut tun?',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82), height: 1.4),
          ),
        ]),
      );

  Widget _buildAgeNotice(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: const Color(0xFFE7F1EE),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF287F76)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_ageNotice!, style: theme.textTheme.bodySmall)),
              IconButton(
                tooltip: 'Schließen',
                onPressed: () => setState(() => _ageNotice = null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ]),
          ),
        ),
      );

  Widget _buildRitualCard(ThemeData theme) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5DED7)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isEvening ? 'Euer Abendmoment' : 'Euer Start in den Tag',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Nichts muss perfekt sein. Nehmt, was heute passt.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          ..._steps.where((step) => !_completed.contains(step.id)).map(
                (step) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEAF3EF),
                    child: Icon(step.icon, color: const Color(0xFF287F76)),
                  ),
                  title: Text(step.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(step.subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Ruhiger Timer starten',
                        onPressed: _startTimer,
                        icon: const Icon(Icons.hourglass_bottom_rounded),
                      ),
                      TextButton(
                        onPressed: () => _toggleStep(step.id),
                        child: const Text('Geschafft'),
                      ),
                    ],
                  ),
                ),
              ),
          if (_steps.every((step) => _completed.contains(step.id)))
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
              child: Text(
                  'Für heute ist genug geschafft. Jetzt darf Ruhe kommen.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF287F76))),
            ),
          if (_secondsRemaining > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text('Ruhiger Timer  $_timerLabel',
                  style: const TextStyle(
                      color: Color(0xFF287F76), fontWeight: FontWeight.w800)),
            ),
        ]),
      );

  Widget _buildStoryCard(ThemeData theme, KindDossier child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE8F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_stories_rounded, color: Color(0xFF6F5A9C)),
            SizedBox(width: 8),
            Text('Eine Geschichte für heute',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          if (_story == null)
            Text('Eine ruhige Geschichte, passend für ${child.childName}.',
                style: theme.textTheme.bodyMedium)
          else
            Text(_story!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _storyLoading ? null : _generateStory,
            icon: _storyLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
                _story == null ? 'Geschichte erzählen' : 'Neue Geschichte'),
          ),
        ]),
      );

  Widget _buildGratitudeCard(ThemeData theme) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ein guter Moment',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Heute war schön, dass …'),
          const SizedBox(height: 10),
          TextField(
            controller: _gratitudeController,
            maxLines: 2,
            onChanged: (_) => _saveState(),
            decoration: const InputDecoration(
              hintText: 'Ein kleiner Satz genügt',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ]),
      );
}

class _RitualStep {
  const _RitualStep(this.id, this.title, this.icon, this.subtitle);
  final String id;
  final String title;
  final IconData icon;
  final String subtitle;
}

class _EmptyChildState extends StatelessWidget {
  const _EmptyChildState({required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.child_care_rounded,
                size: 56, color: Color(0xFF6E7BA8)),
            const SizedBox(height: 14),
            const Text('Noch kein Kinderprofil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
                'Sobald ein Kinderprofil angelegt ist, kann ParentPeak die Rituale altersgerecht begleiten.',
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: onOpenProfile,
                child: const Text('Zum Familienprofil')),
          ]),
        ),
      );
}
