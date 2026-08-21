import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/services/weekly_reflection_service.dart';
import 'package:parentpeak/ui/chat_screen.dart';

class WochenrueckblickScreen extends StatefulWidget {
  const WochenrueckblickScreen({super.key});

  @override
  State<WochenrueckblickScreen> createState() => _WochenrueckblickScreenState();
}

class _WochenrueckblickScreenState extends State<WochenrueckblickScreen>
    with TickerProviderStateMixin {
  int _step = 0; // 0-4 = questions, 5 = summary

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  bool _loading = true;
  bool _aiLoading = false;
  String? _aiFeedback;

  // Answers
  String? _selectedMood;
  final _wellCtrl = TextEditingController();
  final _challengeCtrl = TextEditingController();
  final _learnedCtrl = TextEditingController();
  final _lookingForwardCtrl = TextEditingController();

  // Archive
  List<WeeklyReflection> _archive = [];
  WeeklyReflection? _currentWeekReflection;
  bool _showArchive = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _moods = [
    {
      'key': 'Super',
      'emoji': '\u{1F60A}',
      'label': 'Super',
      'color': 0xFF16A34A
    },
    {'key': 'Gut', 'emoji': '\u{1F642}', 'label': 'Gut', 'color': 0xFF2563EB},
    {
      'key': 'Gemischt',
      'emoji': '\u{1F610}',
      'label': 'Gemischt',
      'color': 0xFFF97316
    },
    {
      'key': 'Anstrengend',
      'emoji': '\u{1F614}',
      'label': 'Anstrengend',
      'color': 0xFFDC2626
    },
    {
      'key': 'Dankbar',
      'emoji': '\u{1F970}',
      'label': 'Dankbar',
      'color': 0xFFEC4899
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _wellCtrl.dispose();
    _challengeCtrl.dispose();
    _learnedCtrl.dispose();
    _lookingForwardCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final all = await WeeklyReflectionService.loadAll();
    final current = await WeeklyReflectionService.currentWeek();
    if (mounted) {
      setState(() {
        _archive = all;
        _currentWeekReflection = current;
        if (current != null) {
          _selectedMood = current.overallMood;
          _wellCtrl.text = current.whatWentWell;
          _challengeCtrl.text = current.whatWasChallenging;
          _learnedCtrl.text = current.whatILearned;
          _lookingForwardCtrl.text = current.lookingForwardTo;
          _aiFeedback = current.aiFeedback;
          _step = 5; // Show summary
        }
        _loading = false;
      });
    }
  }

  void _nextStep() {
    if (_step == 0 && _selectedMood == null) return;
    setState(() {
      _step++;
      _fadeCtrl.reset();
      _fadeCtrl.forward();
    });
    if (_step == 5) _saveAndGenerateAI();
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _step--;
        _fadeCtrl.reset();
        _fadeCtrl.forward();
      });
    }
  }

  Future<void> _saveAndGenerateAI() async {
    final reflection = WeeklyReflection(
      weekId: WeeklyReflectionService.currentWeekId(),
      createdAt: DateTime.now(),
      overallMood: _selectedMood ?? 'Gut',
      whatWentWell: _wellCtrl.text.trim(),
      whatWasChallenging: _challengeCtrl.text.trim(),
      whatILearned: _learnedCtrl.text.trim(),
      lookingForwardTo: _lookingForwardCtrl.text.trim(),
    );
    await WeeklyReflectionService.save(reflection);
    setState(() => _currentWeekReflection = reflection);

    // Generate AI feedback
    if (APIConfig.isGeminiApiKeyConfigured()) {
      setState(() => _aiLoading = true);
      try {
        final ai = GeminiAIService(
          apiKey: APIConfig.getGeminiApiKey(),
          modelName: APIConfig.getGeminiModelName(),
        );
        final prompt = _buildAIPrompt(reflection);
        final response = await ai.chat(prompt);
        final updated = reflection.copyWith(aiFeedback: response);
        await WeeklyReflectionService.save(updated);
        if (mounted) {
          setState(() {
            _aiFeedback = response;
            _aiLoading = false;
            _currentWeekReflection = updated;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _aiLoading = false);
      }
    }
  }

  String _buildAIPrompt(WeeklyReflection r) {
    return '''Du bist ein empathischer Eltern-Coach. Ein Elternteil hat gerade seinen Wochenrückblick geschrieben.

Gesamtstimmung: ${r.overallMood}
Was gut lief: ${r.whatWentWell.isNotEmpty ? r.whatWentWell : "(nicht ausgefüllt)"}
Was herausfordernd war: ${r.whatWasChallenging.isNotEmpty ? r.whatWasChallenging : "(nicht ausgefüllt)"}
Was gelernt wurde: ${r.whatILearned.isNotEmpty ? r.whatILearned : "(nicht ausgefüllt)"}
Worauf sich gefreut wird: ${r.lookingForwardTo.isNotEmpty ? r.lookingForwardTo : "(nicht ausgefüllt)"}

Schreibe eine kurze, warme, empathische Rückmeldung (max 3-4 Sätze). 
Feiere Erfolge, validiere Herausforderungen, gib einen kleinen Impuls für nächste Woche.
Nutze GfK-Prinzipien (Gewaltfreie Kommunikation). Kein Belehren, kein Bewerten.
Schreibe auf Deutsch, duze den Elternteil. Nutze 1-2 passende Emojis.''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'weekly_review'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: false,
        actions: [
          if (_archive.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _showArchive = !_showArchive),
              icon: Icon(
                  _showArchive ? Icons.edit_rounded : Icons.history_rounded,
                  size: 18),
              label: Text(_showArchive ? 'Neu' : 'Archiv'),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _showArchive
              ? _buildArchive()
              : _buildWizard(),
    );
  }

  Widget _buildWizard() {
    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: _buildProgressDots(),
        ),
        // Content
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: _step == 5 ? _buildSummary() : _buildQuestion(),
            ),
          ),
        ),
        // Navigation
        if (_step < 5) _buildNavBar(),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      children: List.generate(5, (i) {
        final isActive = i == _step;
        final isDone = i < _step;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDone
                  ? const Color(0xFF7C3AED)
                  : isActive
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                      : const Color(0xFFE5E7EB),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuestion() {
    switch (_step) {
      case 0:
        return _buildMoodStep();
      case 1:
        return _buildTextStep(
          emoji: '\u{2728}',
          title: 'Was lief richtig gut?',
          subtitle: 'Feiere deine Erfolge — auch die kleinen.',
          hint: 'z.B. Schöner Familienabend, Kind hat gelacht...',
          controller: _wellCtrl,
        );
      case 2:
        return _buildTextStep(
          emoji: '\u{1F4AA}',
          title: 'Was war herausfordernd?',
          subtitle: 'Schwierige Momente verdienen Anerkennung.',
          hint: 'z.B. Schlafmangel, Streit, Überforderung...',
          controller: _challengeCtrl,
        );
      case 3:
        return _buildTextStep(
          emoji: '\u{1F4A1}',
          title: 'Was hast du dabei gelernt?',
          subtitle: 'Jede Woche bringt Erkenntnisse — welche sind deine?',
          hint: 'z.B. Mehr Geduld mit mir selbst, Grenzen setzen...',
          controller: _learnedCtrl,
        );
      case 4:
        return _buildTextStep(
          emoji: '\u{1F31F}',
          title: 'Worauf freust du dich nächste Woche?',
          subtitle: 'Ein Ausblick gibt Kraft und Vorfreude.',
          hint: 'z.B. Spielplatz-Besuch, Abend zu zweit...',
          controller: _lookingForwardCtrl,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMoodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Text('\u{1F49C}', style: const TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Wie war deine Woche?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Dein Gesamteindruck — es gibt kein Richtig oder Falsch.',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        ...(_moods.map((m) => _moodOption(m))),
      ],
    );
  }

  Widget _moodOption(Map<String, dynamic> mood) {
    final key = mood['key'] as String;
    final emoji = mood['emoji'] as String;
    final label = mood['label'] as String;
    final color = Color(mood['color'] as int);
    final selected = _selectedMood == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedMood = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.15), blurRadius: 12)
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : const Color(0xFF374151),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextStep({
    required String emoji,
    required String title,
    required String subtitle,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Center(child: Text(emoji, style: const TextStyle(fontSize: 44))),
        const SizedBox(height: 20),
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: controller,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Optional — lass dir ruhig Zeit.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    final canProceed = _step == 0 ? _selectedMood != null : true;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(_t('network_back')),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: canProceed ? _nextStep : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _step == 4 ? 'Abschließen' : 'Weiter',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 6),
              Icon(
                  _step == 4
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── SUMMARY ──────────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final moodData = _moods.firstWhere((m) => m['key'] == _selectedMood,
        orElse: () => _moods[1]);
    final moodColor = Color(moodData['color'] as int);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                moodColor.withValues(alpha: 0.08),
                moodColor.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: moodColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(moodData['emoji'] as String,
                  style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                'Deine Woche: ${moodData['label']}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: moodColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                WeeklyReflectionService.currentWeekId(),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Answers
        if (_wellCtrl.text.trim().isNotEmpty)
          _summaryItem('\u{2728}', 'Was gut lief', _wellCtrl.text.trim()),
        if (_challengeCtrl.text.trim().isNotEmpty)
          _summaryItem(
              '\u{1F4AA}', 'Herausforderung', _challengeCtrl.text.trim()),
        if (_learnedCtrl.text.trim().isNotEmpty)
          _summaryItem('\u{1F4A1}', 'Erkenntnis', _learnedCtrl.text.trim()),
        if (_lookingForwardCtrl.text.trim().isNotEmpty)
          _summaryItem(
              '\u{1F31F}', 'Vorfreude', _lookingForwardCtrl.text.trim()),

        const SizedBox(height: 24),

        // AI Feedback
        if (_aiLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'KI denkt über deine Woche nach...',
                    style: TextStyle(
                        color: Color(0xFF6B21A8),
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (_aiFeedback != null && !_aiLoading) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('\u{1F916}', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Dein KI-Feedback',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B21A8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _aiFeedback!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Action buttons
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final prompt = _buildChatPromptFromReflection();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(initialMessage: prompt),
                ),
              );
            },
            icon: const Text('\u{1F4AC}', style: TextStyle(fontSize: 16)),
            label: Text(_t('review_talk_to_ai')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Color(0xFF7C3AED)),
              foregroundColor: const Color(0xFF7C3AED),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _startNewReflection,
            child: Text(_t('review_fill_again'),
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String emoji, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED))),
              ],
            ),
            const SizedBox(height: 8),
            Text(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }

  void _startNewReflection() {
    setState(() {
      _step = 0;
      _selectedMood = null;
      _wellCtrl.clear();
      _challengeCtrl.clear();
      _learnedCtrl.clear();
      _lookingForwardCtrl.clear();
      _aiFeedback = null;
      _currentWeekReflection = null;
      _fadeCtrl.reset();
      _fadeCtrl.forward();
    });
  }

  String _buildChatPromptFromReflection() {
    return 'Ich möchte über meinen Wochenrückblick sprechen.\n'
        'Gesamtgefühl: ${_selectedMood ?? "unbekannt"}\n'
        '${_wellCtrl.text.isNotEmpty ? "Was gut lief: ${_wellCtrl.text}\n" : ""}'
        '${_challengeCtrl.text.isNotEmpty ? "Herausforderung: ${_challengeCtrl.text}\n" : ""}'
        '${_learnedCtrl.text.isNotEmpty ? "Erkenntnis: ${_learnedCtrl.text}\n" : ""}'
        '${_lookingForwardCtrl.text.isNotEmpty ? "Vorfreude: ${_lookingForwardCtrl.text}\n" : ""}'
        'Kannst du mir dabei helfen, das einzuordnen und mir einen Impuls geben?';
  }

  // ─── ARCHIVE ──────────────────────────────────────────────────────────────

  void _showArchiveOptions(WeeklyReflection r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(r.weekId,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(_t('calendar_edit')),
              onTap: () {
                Navigator.pop(ctx);
                _editReflection(r);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
              title: Text(_t('review_delete'),
                  style: TextStyle(color: Color(0xFFDC2626))),
              onTap: () {
                Navigator.pop(ctx);
                _deleteReflection(r);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _editReflection(WeeklyReflection r) {
    setState(() {
      _showArchive = false;
      _step = 0;
      _selectedMood = r.overallMood;
      _wellCtrl.text = r.whatWentWell;
      _challengeCtrl.text = r.whatWasChallenging;
      _learnedCtrl.text = r.whatILearned;
      _lookingForwardCtrl.text = r.lookingForwardTo;
      _aiFeedback = null;
      _currentWeekReflection = null;
      _fadeCtrl.reset();
      _fadeCtrl.forward();
    });
  }

  Future<void> _deleteReflection(WeeklyReflection r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${r.weekId} löschen?'),
        content: Text(_t('review_delete_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'delete_action')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await WeeklyReflectionService.delete(r.weekId);
    final updated = await WeeklyReflectionService.loadAll();
    if (mounted) {
      setState(() => _archive = updated);
    }
  }

  Widget _buildArchive() {
    if (_archive.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{1F4D6}', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(_t('review_no_reviews'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text(
                'Dein erstes Wochen-Review wird hier gespeichert.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<WeeklyReflection>.from(_archive)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _archiveCard(sorted[i]),
    );
  }

  Widget _archiveCard(WeeklyReflection r) {
    final moodData = _moods.firstWhere((m) => m['key'] == r.overallMood,
        orElse: () => _moods[1]);
    final moodColor = Color(moodData['color'] as int);
    final dateStr = DateFormat('d. MMM yyyy', 'de').format(r.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: moodColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(moodData['emoji'] as String,
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.weekId,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(dateStr,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: moodColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  moodData['label'] as String,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: moodColor),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showArchiveOptions(r),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_vert_rounded,
                      size: 18, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
          if (r.whatWentWell.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{2728}', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.whatWentWell,
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (r.aiFeedback != null && r.aiFeedback!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('\u{1F916}', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.aiFeedback!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B21A8), height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
