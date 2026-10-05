import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/notification_service.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';

/// Extrahiert ein JSON-Objekt aus einer KI-Antwort. Preview-Modelle liefern
/// die JSON oft in ```json … ``` Codefences oder mit umgebendem Text — ein
/// direktes jsonDecode scheitert dann und der KI-Vorschlag landete bisher
/// immer stumm im Fallback. Gibt null zurück, wenn kein Objekt gefunden wird.
String? extractRitualJsonObject(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  text = text.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
  text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return null;
  return text.substring(start, end + 1);
}

String ritualStepCopy(String language, String text) {
  if (language != 'ku') return text;
  const steps = <String, String>{
    'Guten Morgen': 'Rojbaş',
    'Langsam ankommen': 'Bi hêdî dest pê bike',
    'Anziehen': 'Cil li xwe bike',
    'Etwas Bequemes finden': 'Cilên rehet bibîne',
    'Frühstück': 'Taştê',
    'Gemeinsam in den Tag starten': 'Bi hev re rojê dest pê bikin',
    'Bereit für den Tag': 'Ji bo rojê amade ye',
    'Was brauchen wir heute?': 'Îro em ji çi hewce ne?',
    'Ankommen': 'Bi rehetî bigihîje',
    'Schuhe aus, erst einmal ankommen': 'Pêlavên xwe derxe û hinekî rihet be',
    'Kleine Pause': 'Navbereke kurt',
    'Etwas trinken und durchatmen': 'Tiştekî vexwe û nefesê bistîne',
    'Freie Zeit': 'Dema azad',
    'Was tut euch jetzt gut?': 'Niha çi ji we re baş e?',
    'Waschen': 'Şûştin',
    'Gesicht und Hände werden ruhig': 'Rû û destan bi aramî bişo',
    'Frisch und gemütlich werden': 'Paşî xwe nû û rehet hîs bike',
    'Zähne putzen': 'Diranan paqij bike',
    'Kleine Kreise, ganz in Ruhe': 'Bi tevgereke biçûk û bi aramî',
    'Der Mund bekommt seine Nachtpflege': 'Dev ji bo şevê paqij dibe',
    'In Ruhe fertig werden': 'Bi aramî amade bibe',
    'Kuscheln': 'Hemêzkirin',
    'Noch ein lieber Moment': 'Kêliyek din a bi hez',
    'Für morgen vorbereiten': 'Ji bo sibê amade bike',
    'Lieblingskleidung bereitlegen': 'Cilên xwe yên bijare amade bike',
    'Geschichte aussuchen': 'Çîrokek hilbijêre',
    'Eine ruhige Geschichte wartet': 'Çîrokeke aram li bendê ye',
    'Morgen vorbereiten': 'Sibê amade bike',
    'Tasche und Kleidung bereitlegen': 'Çente û cilan amade bike',
    'Tasche, Kleidung und Wecker': 'Çente, cil û saetê amade bike',
    'Kurz Ordnung schaffen': 'Hinekî rêkûpêk bike',
    'Ein kleiner Handgriff für morgen': 'Gaveke biçûk ji bo sibê',
    'Tagesmoment': 'Kêliya rojê',
    'Was war heute gut?': 'Îro çi baş bû?',
    'Tag abschließen': 'Rojê bi dawî bike',
    'Was darf für heute losgelassen werden?':
        'Îro tu dikarî çi ji xwe dûr bikî?',
    'Ein guter Moment': 'Kêliyek baş',
    'Ein Satz für dich selbst': 'Hevokek ji bo xwe',
    'Aufwachen': 'Şiyar bibe',
    'Langsam in den Tag finden': 'Bi hêdî rojê dest pê bike',
    'Sanfter Morgen': 'Sibeke aram',
    'Ankommen am Nachmittag': 'Bi aramî piştî nîvro bigihîje',
    'Bequeme Kleidung auswählen': 'Cilên rehet hilbijêre',
    'Gemeinsam starten': 'Bi hev re dest pê bikin',
    'Erst einmal durchatmen': 'Pêşî nefesê bistîne',
    'Pause': 'Navber',
    'Trinken, snacken, entspannen': 'Vexwe, tiştekî bixwe û rihet be',
  };
  return steps[text] ?? text;
}

class RitualRuheScreen extends StatefulWidget {
  const RitualRuheScreen({super.key});

  @override
  State<RitualRuheScreen> createState() => _RitualRuheScreenState();
}

class _RitualRuheScreenState extends State<RitualRuheScreen> {
  String get _localeCode => Localizations.localeOf(context).languageCode;
  String _t(String key) => AppStringsManager.getString(_localeCode, key);
  static const _quietModeKey = 'ritual_ruhe.quiet_mode';
  static const _plansKey = 'ritual_ruhe.plans.v2';
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
  String _selectedSection = 'morning';
  Map<String, Map<String, _RitualPlan>> _plans = {};
  bool _planLoading = false;

  bool get _isEvening {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  bool get _isNightSection => _selectedSection == 'night';
  String get _sectionTitle => switch (_selectedSection) {
        'afternoon' => _t('ritual_afternoon'),
        'night' => _t('ritual_evening'),
        _ => _t('ritual_section_morning'),
      };

  KindDossier? get _child => _children.isEmpty
      ? null
      : _children[_selectedChild.clamp(0, _children.length - 1)];

  int get _ageMonths => _child?.ageMonths ?? 60;
  int get _ageYears => (_ageMonths / 12).floor();
  String get _ageVariantLabel {
    if (_ageYears < 5) return _t('ritual_age_young');
    if (_ageYears < 8) return _t('ritual_age_growing');
    if (_ageYears < 11) return _t('ritual_age_school');
    return _t('ritual_age_older');
  }

  String get _suggestionLabel => _t('ritual_suggestion')
      .replaceAll('{age}', '$_ageYears')
      .replaceAll('{section}', _sectionTitle);

  _RitualPlan? get _customPlan =>
      _plans[_child?.childName ?? '']?[_selectedSection];

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
    _selectedSection = _isEvening
        ? 'night'
        : DateTime.now().hour < 12
            ? 'morning'
            : 'afternoon';
    await _loadPlans();
    final ageKey = 'ritual_ruhe.age.${_child?.childName ?? 'family'}';
    final previousAge = prefs.getInt(ageKey);
    final currentAge = _child?.ageYears ?? 0;
    if (previousAge != null && previousAge != currentAge && mounted) {
      setState(() => _ageNotice = _t('ritual_age_notice')
          .replaceAll('{name}', _child?.childName ?? _t('ritual_child'))
          .replaceAll('{age}', '$currentAge'));
    }
    await prefs.setInt(ageKey, currentAge);
    await _loadChildState();
  }

  String get _stateKey =>
      'ritual_ruhe.state.${_child?.childName ?? 'family'}.${DateTime.now().toIso8601String().substring(0, 10)}';

  /// Liest den (ggf. korrupten) Tageszustand robust aus den Prefs.
  Future<Map<String, dynamic>> _readStateMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Abgehakte Schritte für die aktuelle Sektion aus dem State lesen.
  ///
  /// `completed` wird pro Sektion gespeichert (`{section: [ids]}`), damit sich
  /// gleichnamige Schritt-IDs (z. B. "zaehne", "morgen") nicht zwischen Morgen-
  /// und Abend-Routine koppeln. Alte flache Listen (Legacy) werden der aktuell
  /// aktiven Sektion zugeordnet, statt sie zu verlieren.
  Set<String> _completedForSection(Map<String, dynamic> state) {
    final completed = state['completed'];
    if (completed is Map) {
      final list = completed[_selectedSection];
      return (list is List ? list : const []).map((e) => e.toString()).toSet();
    }
    if (completed is List) {
      return completed.map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  Future<void> _loadChildState() async {
    final state = await _readStateMap();
    if (!mounted) return;
    setState(() {
      _completed = _completedForSection(state);
      _gratitudeController.text = state['gratitude']?.toString() ?? '';
      _story = state['story']?.toString();
    });
  }

  Future<void> _loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plansKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _plans = decoded.map((child, sections) {
        final sectionMap = sections is Map ? sections : <String, dynamic>{};
        return MapEntry(
            child,
            sectionMap.map((section, plan) => MapEntry(
                  section,
                  _RitualPlan.fromJson(Map<String, dynamic>.from(plan as Map)),
                )));
      });
    } catch (_) {
      _plans = {};
    }
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _plansKey,
      jsonEncode(_plans.map((child, sections) => MapEntry(
            child,
            sections.map((section, plan) => MapEntry(section, plan.toJson())),
          ))),
    );
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _readStateMap();
    // Bestehende Sektions-Map übernehmen (Legacy-Liste wird dabei verworfen,
    // da sie nicht sauber einer Sektion zugeordnet werden kann) und nur die
    // aktuell aktive Sektion aktualisieren.
    final rawCompleted = existing['completed'];
    final completedBySection = <String, List<String>>{};
    if (rawCompleted is Map) {
      rawCompleted.forEach((section, list) {
        completedBySection[section.toString()] =
            (list is List ? list : const []).map((e) => e.toString()).toList();
      });
    }
    completedBySection[_selectedSection] = _completed.toList();

    await prefs.setString(
        _stateKey,
        jsonEncode({
          'completed': completedBySection,
          'gratitude': _gratitudeController.text.trim(),
          if (_story != null) 'story': _story,
        }));
  }

  /// Baut einen Default-Schritt mit lokalisierten Texten. Titel/Untertitel
  /// kommen aus der zentralen String-Verwaltung, damit die Standard-Rituale in
  /// allen Picker-Sprachen erscheinen (statt nur Deutsch bzw. KU über die alte
  /// ritualStepCopy-Map).
  _RitualStep _defaultStep(
          String id, String titleKey, IconData icon, String subKey) =>
      _RitualStep(id, _t(titleKey), icon, _t(subKey));

  List<_RitualStep> get _steps {
    if (_selectedSection == 'morning' ||
        !_isNightSection && _selectedSection != 'afternoon') {
      return _customPlan?.steps ?? _morningSteps();
    }
    if (_selectedSection == 'afternoon') {
      return _customPlan?.steps ?? _afternoonSteps();
    }
    if (_ageYears < 5) {
      return [
        _defaultStep('waschen', 'ritual_step_wash_title',
            Icons.water_drop_rounded, 'ritual_step_wash_calm_sub'),
        _defaultStep('zaehne', 'ritual_step_teeth_title',
            Icons.clean_hands_rounded, 'ritual_step_teeth_circles_sub'),
        _defaultStep('kuscheln', 'ritual_step_cuddle_title',
            Icons.favorite_rounded, 'ritual_step_cuddle_sub'),
      ];
    }
    if (_ageYears < 8) {
      return [
        _defaultStep('waschen', 'ritual_step_wash_title',
            Icons.water_drop_rounded, 'ritual_step_wash_cozy_sub'),
        _defaultStep('zaehne', 'ritual_step_teeth_title',
            Icons.clean_hands_rounded, 'ritual_step_teeth_night_sub'),
        _defaultStep('morgen', 'ritual_step_prep_tomorrow_title',
            Icons.checkroom_rounded, 'ritual_step_prep_clothes_sub'),
        _defaultStep('geschichte', 'ritual_step_story_title',
            Icons.auto_stories_rounded, 'ritual_step_story_sub'),
      ];
    }
    if (_ageYears < 11) {
      return [
        _defaultStep('zaehne', 'ritual_step_teeth_title',
            Icons.clean_hands_rounded, 'ritual_step_teeth_calm_sub'),
        _defaultStep('morgen', 'ritual_step_prep_tomorrow_title',
            Icons.backpack_rounded, 'ritual_step_prep_bag_sub'),
        _defaultStep('aufräumen', 'ritual_step_tidy_title',
            Icons.auto_awesome_rounded, 'ritual_step_tidy_sub'),
        _defaultStep('reflexion', 'ritual_step_daymoment_title',
            Icons.chat_bubble_outline_rounded, 'ritual_step_daymoment_sub'),
      ];
    }
    return [
      _defaultStep('morgen', 'ritual_step_prep_tomorrow_title',
          Icons.backpack_rounded, 'ritual_step_prep_full_sub'),
      _defaultStep('abschluss', 'ritual_step_close_title',
          Icons.nightlight_round, 'ritual_step_close_sub'),
      _defaultStep('reflexion', 'ritual_step_goodmoment_title',
          Icons.favorite_border_rounded, 'ritual_step_goodmoment_sub'),
    ];
  }

  List<_RitualStep> _morningSteps() => [
        _defaultStep('aufstehen', 'ritual_step_morning_title',
            Icons.wb_sunny_rounded, 'ritual_step_morning_sub'),
        _defaultStep('anziehen', 'ritual_step_dress_title',
            Icons.checkroom_rounded, 'ritual_step_dress_sub'),
        _defaultStep('fruehstueck', 'ritual_step_breakfast_title',
            Icons.breakfast_dining_rounded, 'ritual_step_breakfast_sub'),
        _defaultStep('tasche', 'ritual_step_ready_title',
            Icons.backpack_rounded, 'ritual_step_ready_sub'),
      ];

  List<_RitualStep> _afternoonSteps() => [
        _defaultStep('ankommen', 'ritual_step_arrive_title', Icons.home_rounded,
            'ritual_step_arrive_sub'),
        _defaultStep('snack', 'ritual_step_pause_title',
            Icons.local_cafe_rounded, 'ritual_step_pause_sub'),
        _defaultStep('spielen', 'ritual_step_free_title', Icons.toys_rounded,
            'ritual_step_free_sub'),
      ];

  Future<void> _toggleStep(String id) async {
    setState(() {
      if (!_completed.remove(id)) _completed.add(id);
    });
    await _saveState();
  }

  Future<void> _selectSection(String section) async {
    setState(() {
      _selectedSection = section;
      _completed = <String>{};
    });
    await _loadChildState();
  }

  Future<void> _suggestPlan() async {
    final child = _child;
    if (child == null || _planLoading || _selectedSection == 'night') return;
    setState(() => _planLoading = true);
    _RitualPlan plan;
    try {
      final response = await GeminiAIService().generateText(
        'Erstelle eine kurze Ritualvorlage für ein Kind im Alter von $_ageYears Jahren. Tageszeit: $_sectionTitle. Liefere ausschließlich JSON mit name, time, weekdays und steps. steps ist eine Liste aus title, subtitle, icon und timerSeconds. Maximal 6 Schritte. Keine Namen und keine persönlichen Daten.',
        systemInstruction:
            'Du bist eine pädagogische, inklusive Familienbegleitung. Erstelle sanfte, realistische und druckfreie Rituale. Nutze nur JSON, keine Markdown-Zeichen. Keine Punkte, Streaks, Strafen oder Leistungsdruck.',
        appLanguage: _localeCode,
      );
      final jsonStr = extractRitualJsonObject(response);
      if (jsonStr == null) throw const FormatException('Kein JSON im KI-Text');
      plan = _RitualPlan.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      plan = _fallbackPlan(_selectedSection, _ageYears);
    }
    if (!mounted) return;
    await _editPlan(plan);
    if (mounted) setState(() => _planLoading = false);
  }

  _RitualPlan _fallbackPlan(String section, int ageYears) => _RitualPlan(
        name: section == 'morning'
            ? _t('ritual_fallback_name_morning')
            : _t('ritual_fallback_name_afternoon'),
        time: section == 'morning' ? '07:30' : '15:30',
        weekdays: [1, 2, 3, 4, 5],
        steps: section == 'morning'
            ? [
                _defaultStep('wake', 'ritual_step_morning_title',
                    Icons.wb_sunny_rounded, 'ritual_step_morning_sub'),
                _defaultStep('dress', 'ritual_step_dress_title',
                    Icons.checkroom_rounded, 'ritual_step_dress_sub'),
                _defaultStep(
                    'breakfast',
                    'ritual_step_breakfast_title',
                    Icons.breakfast_dining_rounded,
                    'ritual_step_breakfast_sub'),
              ]
            : [
                _defaultStep('arrive', 'ritual_step_arrive_title',
                    Icons.home_rounded, 'ritual_step_pause_breathe_sub'),
                _defaultStep('pause', 'ritual_step_pause_short_title',
                    Icons.local_cafe_rounded, 'ritual_step_pause_relax_sub'),
              ],
      );

  Future<void> _editPlan(_RitualPlan initial) async {
    final edited = await showModalBottomSheet<_RitualPlan>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RitualPlanEditor(initial: initial, title: _sectionTitle),
    );
    if (edited == null || _child == null) return;
    setState(() {
      _plans[_child!.childName] ??= {};
      _plans[_child!.childName]![_selectedSection] = edited;
    });
    await _savePlans();
    await _scheduleRitualReminders(edited);
  }

  /// Plant für die im Plan eingestellte Uhrzeit und Wochentage sanfte
  /// Erinnerungen. Nutzt den vorhandenen NotificationService, der selbst
  /// `kIsWeb` und den `quiet_mode` respektiert (keine Erinnerung bei Ruhe/Web).
  /// Macht die zuvor folgenlosen Felder `time`/`weekdays` tatsächlich wirksam.
  Future<void> _scheduleRitualReminders(_RitualPlan plan) async {
    if (kIsWeb) return;
    final parts = plan.time.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
    if (plan.weekdays.isEmpty) return;

    final now = DateTime.now();
    final title = _t('ritual_reminder_title');
    final body = _t('ritual_reminder_body').replaceAll('{name}', plan.name);
    for (final weekday in plan.weekdays) {
      if (weekday < 1 || weekday > 7) continue;
      // Nächstes Vorkommen dieses Wochentags zur eingestellten Uhrzeit finden.
      var daysAhead = (weekday - now.weekday) % 7;
      var when =
          DateTime(now.year, now.month, now.day + daysAhead, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
      await NotificationService.instance.scheduleReminder(when, title, body);
    }
  }

  Future<void> _toggleQuietMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quietModeKey, value);
    if (mounted) setState(() => _quietMode = value);
  }

  void _startTimer([int startSeconds = 120]) {
    _ritualTimer?.cancel();
    // Mit dem konfigurierten Wert des Schritts starten (statt immer 120s). Bei
    // 0/negativ auf die sanften 2 Minuten als Standard zurückfallen.
    setState(() => _secondsRemaining = startSeconds > 0 ? startSeconds : 120);
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

  String _formatTimer(int seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes == 0) return '0:${remainder.toString().padLeft(2, '0')}';
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _generateStory() async {
    final child = _child;
    if (child == null || _storyLoading) return;
    setState(() => _storyLoading = true);
    try {
      final story = await GeminiAIService().generateText(
        'Schreibe eine kurze Gute-Nacht-Geschichte für ein Kind, etwa $_ageYears Jahre alt. Thema: Mut, Geborgenheit und ein kleiner freundlicher Moment. 350 bis 500 Wörter. Verwende keine Namen und keine persönlichen Daten.',
        systemInstruction:
            'Du bist eine ruhige, inklusive Kinderbuchautorin. Schreibe warm, beruhigend und altersgerecht in der angefragten App-Sprache. Keine Angst, Gewalt, Diagnosen oder Leistungsdruck. Gib nur die Geschichte zurück, ohne Überschrift oder Erklärung.',
        appLanguage: _localeCode,
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

  String _fallbackStory(String name) => _t('ritual_fallback_story')
      .replaceAll('{name}', name.isEmpty ? _t('ritual_child') : name);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = _child;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        title: Text(_isEvening ? _t('ritual_evening') : _t('ritual_morning')),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _t('ritual_quiet_mode'),
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
                    _buildSectionPicker(theme),
                    _buildWelcome(theme, child),
                    const SizedBox(height: 18),
                    _buildRitualCard(theme),
                    if (_isNightSection) ...[
                      const SizedBox(height: 16),
                      _buildStoryCard(theme, child),
                      const SizedBox(height: 16),
                      _buildGratitudeCard(theme),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSectionPicker(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'morning',
                label: Text(_t('ritual_section_morning')),
                icon: const Icon(Icons.wb_sunny_rounded)),
            ButtonSegment(
                value: 'afternoon',
                label: Text(_t('ritual_afternoon')),
                icon: const Icon(Icons.wb_twilight_rounded)),
            ButtonSegment(
                value: 'night',
                label: Text(_t('ritual_section_evening')),
                icon: const Icon(Icons.nightlight_round)),
          ],
          selected: {_selectedSection},
          onSelectionChanged: (value) => _selectSection(value.first),
        ),
      );

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
            _isNightSection
                ? _t('ritual_welcome_night')
                : _t('ritual_welcome_child')
                    .replaceAll('{section}', _sectionTitle)
                    .replaceAll('{name}', child.childName),
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            _isNightSection
                ? _t('ritual_welcome_relaxed')
                : _t('ritual_welcome_question'),
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
                tooltip: _t('ritual_close'),
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
          Text(
              _isNightSection
                  ? _t('ritual_night_title')
                  : _t('ritual_your_section')
                      .replaceAll('{section}', _sectionTitle),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_t('ritual_card_subtitle'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            _ageVariantLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF287F76),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!_isNightSection) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _planLoading
                        ? null
                        : () => _editPlan(
                              _customPlan ??
                                  _fallbackPlan(_selectedSection, _ageYears),
                            ),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(_t('ritual_edit')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _planLoading ? null : _suggestPlan,
                    icon: _planLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_suggestionLabel),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ..._steps.where((step) => !_completed.contains(step.id)).map(
                (step) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEAF3EF),
                    child: Icon(step.icon, color: const Color(0xFF287F76)),
                  ),
                  title: Text(ritualStepCopy(_localeCode, step.title),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ritualStepCopy(_localeCode, step.subtitle)),
                      if (step.timerSeconds > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hourglass_bottom_rounded,
                                  size: 15, color: Color(0xFF287F76)),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimer(step.timerSeconds),
                                style: const TextStyle(
                                  color: Color(0xFF287F76),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _t('ritual_timer_start'),
                        onPressed: () => _startTimer(step.timerSeconds),
                        icon: const Icon(Icons.hourglass_bottom_rounded),
                      ),
                      TextButton(
                        onPressed: () => _toggleStep(step.id),
                        child: Text(_t('ritual_done')),
                      ),
                    ],
                  ),
                ),
              ),
          if (_steps.every((step) => _completed.contains(step.id)))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
              child: Text(_t('ritual_all_done'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF287F76))),
            ),
          if (_secondsRemaining > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text('${_t('ritual_timer')}  $_timerLabel',
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
          Row(children: [
            const Icon(Icons.auto_stories_rounded, color: Color(0xFF6F5A9C)),
            const SizedBox(width: 8),
            Text(_t('ritual_story_title'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          if (_story == null)
            Text(_t('ritual_story_hint').replaceAll('{name}', child.childName),
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
            label: Text(_story == null
                ? _t('ritual_story_generate')
                : _t('ritual_story_new')),
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
          Text(_t('ritual_gratitude_title'),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(_t('ritual_gratitude_hint')),
          const SizedBox(height: 10),
          TextField(
            controller: _gratitudeController,
            maxLines: 2,
            onChanged: (_) => _saveState(),
            decoration: InputDecoration(
              hintText: _t('ritual_gratitude_placeholder'),
              filled: true,
              fillColor: Colors.white,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ]),
      );
}

class _RitualStep {
  const _RitualStep(this.id, this.title, this.icon, this.subtitle,
      {this.timerSeconds = 0});
  final String id;
  final String title;
  final IconData icon;
  final String subtitle;
  final int timerSeconds;
}

class _RitualPlan {
  const _RitualPlan({
    required this.name,
    required this.time,
    required this.weekdays,
    required this.steps,
  });

  final String name;
  final String time;
  final List<int> weekdays;
  final List<_RitualStep> steps;

  Map<String, dynamic> toJson() => {
        'name': name,
        'time': time,
        'weekdays': weekdays,
        'steps': steps
            .map((step) => {
                  'id': step.id,
                  'title': step.title,
                  'subtitle': step.subtitle,
                  'icon': _iconName(step.icon),
                  'timerSeconds': step.timerSeconds,
                })
            .toList(),
      };

  factory _RitualPlan.fromJson(Map<String, dynamic> json) => _RitualPlan(
        name: json['name']?.toString() ?? 'Mein Ritual',
        time: json['time']?.toString() ?? '08:00',
        weekdays: (json['weekdays'] as List? ?? const [1, 2, 3, 4, 5])
            .map((value) => int.tryParse(value.toString()) ?? 1)
            .toList(),
        steps: (json['steps'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) => _RitualStep(
                  raw['id']?.toString() ?? DateTime.now().toIso8601String(),
                  raw['title']?.toString() ?? 'Schritt',
                  _iconFromName(raw['icon']?.toString()),
                  raw['subtitle']?.toString() ?? '',
                  timerSeconds:
                      int.tryParse(raw['timerSeconds']?.toString() ?? '') ?? 0,
                ))
            .toList(),
      );
}

String _iconName(IconData icon) {
  if (icon == Icons.checkroom_rounded) return 'checkroom';
  if (icon == Icons.backpack_rounded) return 'backpack';
  if (icon == Icons.breakfast_dining_rounded) return 'breakfast';
  if (icon == Icons.local_cafe_rounded) return 'cafe';
  if (icon == Icons.toys_rounded) return 'toys';
  if (icon == Icons.water_drop_rounded) return 'water';
  return 'star';
}

IconData _iconFromName(String? name) => switch (name) {
      'checkroom' => Icons.checkroom_rounded,
      'backpack' => Icons.backpack_rounded,
      'breakfast' => Icons.breakfast_dining_rounded,
      'cafe' => Icons.local_cafe_rounded,
      'toys' => Icons.toys_rounded,
      'water' => Icons.water_drop_rounded,
      _ => Icons.auto_awesome_rounded,
    };

class _RitualPlanEditor extends StatefulWidget {
  const _RitualPlanEditor({required this.initial, required this.title});
  final _RitualPlan initial;
  final String title;

  @override
  State<_RitualPlanEditor> createState() => _RitualPlanEditorState();
}

class _RitualPlanEditorState extends State<_RitualPlanEditor> {
  String _t(String key) => AppStringsManager.getString(
      Localizations.localeOf(context).languageCode, key);
  late final TextEditingController _nameController;
  late final TextEditingController _timeController;
  late List<_RitualStep> _steps;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _timeController = TextEditingController(text: widget.initial.time);
    _steps = [...widget.initial.steps];
    _weekdays = widget.initial.weekdays.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _addStep() async {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    final timerController = TextEditingController(text: '0');
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('ritual_add_step')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: _t('ritual_step_title'))),
          TextField(
              controller: subtitleController,
              decoration:
                  InputDecoration(labelText: _t('ritual_step_subtitle'))),
          const SizedBox(height: 8),
          TextField(
            controller: timerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t('ritual_timer_seconds'),
              hintText: _t('ritual_timer_hint'),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('ritual_cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(
                dialogContext, titleController.text.trim().isNotEmpty),
            child: Text(_t('ritual_add')),
          ),
        ],
      ),
    );
    if (added == true) {
      final timerSeconds = int.tryParse(timerController.text.trim()) ?? 0;
      setState(() => _steps.add(_RitualStep(
            DateTime.now().microsecondsSinceEpoch.toString(),
            titleController.text.trim(),
            Icons.auto_awesome_rounded,
            subtitleController.text.trim(),
            timerSeconds: timerSeconds.clamp(0, 1800),
          )));
    }
    titleController.dispose();
    subtitleController.dispose();
    timerController.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _RitualPlan(
        name: _nameController.text.trim().isEmpty
            ? widget.initial.name
            : _nameController.text.trim(),
        time: _timeController.text.trim().isEmpty
            ? widget.initial.time
            : _timeController.text.trim(),
        weekdays: _weekdays.toList()..sort(),
        steps: _steps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _t('ritual_edit_title').replaceAll('{title}', widget.title),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: _t('ritual_name'))),
                const SizedBox(height: 8),
                TextField(
                    controller: _timeController,
                    decoration: InputDecoration(
                        labelText: _t('ritual_time'), hintText: '08:00')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return FilterChip(
                      label: Text(_t('ritual_weekdays').split('|')[index]),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() => selected
                          ? _weekdays.add(day)
                          : _weekdays.remove(day)),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ReorderableListView.builder(
                    itemCount: _steps.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final step = _steps.removeAt(oldIndex);
                        _steps.insert(newIndex, step);
                      });
                    },
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return ListTile(
                        key: ValueKey(step.id),
                        leading: Icon(step.icon),
                        title: Text(ritualStepCopy(
                            Localizations.localeOf(context).languageCode,
                            step.title)),
                        subtitle: Text(ritualStepCopy(
                            Localizations.localeOf(context).languageCode,
                            step.subtitle)),
                        trailing: IconButton(
                          tooltip: _t('ritual_remove_step'),
                          onPressed: () =>
                              setState(() => _steps.removeAt(index)),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      );
                    },
                  ),
                ),
                Row(children: [
                  OutlinedButton.icon(
                      onPressed: _addStep,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(_t('ritual_step'))),
                  const Spacer(),
                  FilledButton(
                      onPressed: _save, child: Text(_t('ritual_save'))),
                ]),
              ]),
        ),
      );
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
            Text(
                AppStringsManager.getString(
                    Localizations.localeOf(context).languageCode,
                    'ritual_empty_title'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
                AppStringsManager.getString(
                    Localizations.localeOf(context).languageCode,
                    'ritual_empty_description'),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: onOpenProfile,
                child: Text(AppStringsManager.getString(
                    Localizations.localeOf(context).languageCode,
                    'ritual_empty_action'))),
          ]),
        ),
      );
}
