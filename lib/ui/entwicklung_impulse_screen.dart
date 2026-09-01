import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/logic/weekly_impulse_service.dart';
import 'package:parentpeak/models_and_widgets/weekly_impulse_feature.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:parentpeak/models/child_development_data.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/ui/widgets/eltern_wissen_widget.dart';
import 'package:parentpeak/ui/widgets/expert_bibliothek_section.dart';
import 'package:parentpeak/ui/widgets/development_progress_chart.dart';
import 'package:parentpeak/logic/development_pdf_service.dart';
import 'package:parentpeak/services/development_report_limit_service.dart';
import 'package:parentpeak/services/premium_service.dart';
import 'package:parentpeak/config/monetization_config.dart';

/// Impulse & Entwicklung — vereinfacht, elternfreundlich, modern.
///
/// Tab 1: Tagesimpuls mit 3 Mini-Formaten (Verstehen, Praxis, Reflexion)
/// Tab 2: Entwicklungs-Check-in (5 Bereiche, Radar-Chart, KI-Tipps)
class EntwicklungImpulseScreen extends StatefulWidget {
  final int initialTabIndex;
  final WeeklyImpulseService? impulseService;

  const EntwicklungImpulseScreen({
    super.key,
    this.initialTabIndex = 0,
    this.impulseService,
  });

  @override
  State<EntwicklungImpulseScreen> createState() =>
      _EntwicklungImpulseScreenState();
}

class _EntwicklungImpulseScreenState extends State<EntwicklungImpulseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FlutterTts _tts = FlutterTts();
  late final WeeklyImpulseService _impulseService;

  WeeklyImpulse? _impulse;
  bool _isLoading = true;
  String? _error;
  bool _isUsingFallbackImpulse = false;
  bool _isPlayingAudio = false;
  int _expandedFormat = -1;

  // Stimmungscheck & Streak
  int _todayMood = 0; // 0=kein Check-in, 1=😮‍💨, 2=😌, 3=🌟
  int _streak = 0; // Tage in Folge
  bool _impulseCompleted = false; // Heutiger Impuls gelesen
  String? _wissenTopic; // Vorausgefülltes Thema für Wissen-Tab (Soforthilfe)

  String _t(String key) => AppStringsManager.getString(
      languageService.currentLanguage,
      key); // welches Mini-Format aufgeklappt ist

  static const Duration _impulseStaleThreshold = Duration(days: 2);

  // Entwicklung Check-in State — managed in TAB 2 section below

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _impulseService = widget.impulseService ??
        BackendServiceFactory.createWeeklyImpulseService();
    _loadImpulse();
    _loadCheckIn();
    _loadStreakAndMood();
  }

  @override
  void dispose() {
    _tts.stop();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadImpulse() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isUsingFallbackImpulse = false;
    });
    try {
      final impulse = await _impulseService.fetchWeeklyImpulse(
        viewerUserId: AuthService.instance.currentUser?.uid ?? 'guest',
      );
      if (mounted)
        setState(() {
          _impulse = impulse;
          _isLoading = false;
          _error = null;
        });
    } catch (e) {
      final fallback = _buildLocalFallbackImpulse();
      if (mounted)
        setState(() {
          _impulse = fallback;
          _error = null;
          _isLoading = false;
          _isUsingFallbackImpulse = true;
        });
    }
  }

  // 7 offline fallback topics, cycled by day-of-year when backend unavailable.
  static const List<(String title, String body, String tip, String reflect)>
      _fallbackTopics = [
    (
      'Grenzen liebevoll setzen',
      'Liebevolle Grenzen sind kein Widerspruch. Kinder brauchen beides: das Gefühl, geliebt zu sein, UND klare Orientierung. Grenzen mit Verbindung wirken wie Leitplanken, nicht wie Mauern.',
      'Benenne heute zuerst das Gefühl deines Kindes, dann die Grenze: "Ich sehe, du bist wütend. Und trotzdem: Hauen geht nicht."',
      'Gab es heute eine Situation, in der eine ruhige Grenze besser funktioniert hat als ein lautes Nein?',
    ),
    (
      'Ich-Botschaften im Alltag',
      'Du-Botschaften lösen Abwehr aus. Ich-Botschaften öffnen Türen. Kinder hören mehr zu, wenn sie sich nicht angegriffen fühlen.',
      'Wähle heute eine Situation, in der du sonst "Du immer..." sagst – und ersetze sie durch "Ich fühle ... weil ich ... brauche."',
      'Hat eine Ich-Botschaft heute eine Reaktion ausgelöst, die dich überrascht hat?',
    ),
    (
      'Kleine Schritte, große Wirkung',
      'Wenn heute alles zu viel ist: Wähle nur einen ruhigen Moment mit deinem Kind und benenne ein Gefühl wertfrei. Dieser kurze Check-in stärkt Verbindung und Sicherheit.',
      '3 Minuten gemeinsam atmen, dann frage: "Was war heute leicht für dich?".',
      'Welcher kleine Moment heute hat euch beiden gutgetan?',
    ),
    (
      'Stärken sehen statt Schwächen bewerten',
      'Jedes Kind hat eine einzigartige Stärken-Konstellation. Oft sehen wir zuerst die Baustellen – dabei wären wir die ersten, die den Rohdiamanten polieren könnten.',
      'Sprich heute mit deinem Kind über eine seiner Stärken – nicht als Lob, sondern als Beobachtung: "Ich habe heute gesehen, wie du..."',
      'Welche Stärke deines Kindes hat dich heute überrascht oder beeindruckt?',
    ),
    (
      'Selbständigkeit – loslassen ist auch Liebe',
      'Kinder werden selbständig, wenn wir ihnen trauen. Die Kunst ist: Schritt für Schritt mehr Verantwortung übergeben, ohne zu früh einzuspringen.',
      'Übergib deinem Kind heute eine Aufgabe, die du bisher selbst gemacht hast – und lass es komplett selbst.',
      'Wann habt ihr heute losgelassen – und wie hat sich das angefühlt?',
    ),
    (
      'Gefühle benennen und anerkennen',
      'Kinder, die ihre Gefühle benennen können, können kommunizieren, was sie brauchen. Dieser Schritt – vom Fühlen zum Sprechen – braucht Übung und deine Unterstützung.',
      'Stell heute Abend die Frage: "Was hat dich froh gemacht? Was hat dich traurig oder wütend gemacht?" – und hör einfach zu.',
      'Welchen Gefühlsmoment eures Kindes wolltet ihr heute festhalten?',
    ),
    (
      'Scheitern als Lernchance sehen',
      'Das Gehirn lernt am stärksten durch Fehler. Wenn dein Kind scheitert und du dabei ruhig bleibst, gibst du das stärkste Signal: Scheitern ist sicher. Ich halte das aus.',
      'Erzähle deinem Kind heute von einem eigenen Misserfolg – und was du daraus gelernt hast.',
      'Gab es heute einen Misserfolg, den dein Kind gut weggesteckt hat? Was hat dabei geholfen?',
    ),
  ];

  WeeklyImpulse _buildLocalFallbackImpulse() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final t = _fallbackTopics[dayOfYear % _fallbackTopics.length];
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return WeeklyImpulse(
      id: 'local_fallback_$dateKey',
      title: t.$1,
      contentBody: t.$2,
      practicalTip: t.$3,
      category: PedagogicalCategory.gfk,
      publishDate: now,
      heroHeadline: 'Tagesimpuls für deinen Alltag',
      heroDescription: t.$2,
      companionImpulses: <WeeklyImpulseCompanion>[
        WeeklyImpulseCompanion(
          id: 'fallback_verstehen_$dateKey',
          title: 'Kurz verstanden',
          summary:
              'Kinder kooperieren besser, wenn sie sich zuerst gesehen fühlen. Verbindung kommt vor Korrektur.',
          durationLabel: '2 min',
          formatLabel: 'Verstehen',
        ),
        WeeklyImpulseCompanion(
          id: 'fallback_praxis_$dateKey',
          title: 'Praxis für heute',
          summary: t.$3,
          durationLabel: '3 min',
          formatLabel: 'Praxis',
        ),
        WeeklyImpulseCompanion(
          id: 'fallback_reflexion_$dateKey',
          title: 'Abend-Reflexion',
          summary: t.$4,
          durationLabel: '1 min',
          formatLabel: 'Reflexion',
        ),
      ],
      discussionPrompt: WeeklyImpulseDiscussionPrompt(
        id: 'fallback_discussion_$dateKey',
        title: 'Gesprächsimpuls',
        body: t.$4,
      ),
    );
  }

  Future<void> _loadStreakAndMood() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    // Mood
    final savedMood = prefs.getInt('impulse.mood.$today') ?? 0;
    // Streak
    final lastDate = prefs.getString('impulse.streak.last_date') ?? '';
    final savedCount = prefs.getInt('impulse.streak.count') ?? 0;
    int streak = savedCount;
    if (lastDate == today) {
      streak = savedCount;
    } else if (lastDate == _yesterdayKey()) {
      streak = savedCount + 1;
      await prefs.setInt('impulse.streak.count', streak);
      await prefs.setString('impulse.streak.last_date', today);
    } else if (lastDate.isEmpty) {
      streak = 1;
      await prefs.setInt('impulse.streak.count', 1);
      await prefs.setString('impulse.streak.last_date', today);
    } else {
      streak = 1;
      await prefs.setInt('impulse.streak.count', 1);
      await prefs.setString('impulse.streak.last_date', today);
    }
    // Impuls erledigt heute?
    final completed = prefs.getBool('impulse.completed.$today') ?? false;
    if (mounted)
      setState(() {
        _todayMood = savedMood;
        _streak = streak;
        _impulseCompleted = completed;
      });
  }

  Future<void> _saveMood(int mood) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('impulse.mood.${_todayKey()}', mood);
    setState(() => _todayMood = mood);
  }

  Future<void> _markImpulseCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('impulse.completed.${_todayKey()}', true);
    setState(() => _impulseCompleted = true);
    HapticFeedback.lightImpact();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _getMoodGreeting() {
    final hour = DateTime.now().hour;
    final timeGreet = hour < 12
        ? _t('greeting_morning')
        : hour < 17
            ? _t('greeting_afternoon')
            : _t('greeting_evening');
    switch (_todayMood) {
      case 1:
        return '$timeGreet${_t('mood_exhausted_suffix')}';
      case 2:
        return '$timeGreet${_t('mood_present_suffix')}';
      case 3:
        return '$timeGreet${_t('mood_energetic_suffix')}';
      default:
        return '$timeGreet${_t('mood_default_suffix')}';
    }
  }

  Future<void> _playAudio(String text) async {
    if (_isPlayingAudio) {
      await _tts.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }
    setState(() => _isPlayingAudio = true);
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  String _formatDateLabel(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day.$month.$year';
  }

  bool _isImpulseStale(WeeklyImpulse impulse) {
    final age = DateTime.now().toUtc().difference(impulse.publishDate.toUtc());
    return age > _impulseStaleThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'impulse_title')),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: theme.colorScheme.onPrimaryContainer,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                tabs: [
                  Tab(
                      text: AppStringsManager.getString(
                          languageService.currentLanguage, 'weekly_impulse')),
                  Tab(
                      text: AppStringsManager.getString(
                          languageService.currentLanguage, 'development')),
                  const Tab(text: 'Wissen'),
                ],
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImpulseTab(theme),
                _buildDevelopmentTab(theme),
                _buildWissenTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: TAGESIMPULS — 3 Mini-Formate
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildImpulseTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _impulse == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 14),
              Text(_error ?? 'Nicht verfügbar', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: _loadImpulse,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'reload_btn')),
              ),
            ],
          ),
        ),
      );
    }

    final impulse = _impulse!;
    final companions = impulse.companionImpulses;
    final impulseIsStale = _isImpulseStale(impulse);

    return RefreshIndicator(
      onRefresh: _loadImpulse,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Täglicher Header: Begrüßung + Streak + Stimmungscheck
            _buildDailyHeader(theme),
            if (_isUsingFallbackImpulse)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Text(_t('offline_impulse'),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            // Soforthilfe — "Was ist gerade los?"
            _buildSoforthilfe(theme),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: impulseIsStale
                    ? const Color(0xFFFFF4E5)
                    : const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: impulseIsStale
                      ? const Color(0xFFFFD79A)
                      : const Color(0xFFB8DAF6),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    impulseIsStale
                        ? Icons.schedule_rounded
                        : Icons.update_rounded,
                    size: 18,
                    color: impulseIsStale
                        ? const Color(0xFF8A4B00)
                        : const Color(0xFF155E75),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      impulseIsStale
                          ? '${_t('status_as_of')} ${_formatDateLabel(impulse.publishDate)} - ${_t('stale_days_warning').replaceAll('{days}', '${_impulseStaleThreshold.inDays}')}'
                          : '${_t('status_as_of')} ${_formatDateLabel(impulse.publishDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: impulseIsStale
                            ? const Color(0xFF8A4B00)
                            : const Color(0xFF155E75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Thema der Woche
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('\u{1F4D6}', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t('topic_of_week'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      // Audio Button
                      if (impulse.audioScript != null)
                        GestureDetector(
                          onTap: () => _playAudio(
                              impulse.audioScript ?? impulse.contentBody),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isPlayingAudio
                                  ? Icons.stop_rounded
                                  : Icons.headphones_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    impulse.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    impulse.heroDescription ??
                        impulse.contentBody.split('\n').first,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Schriftlicher Inhalt — aufklappbar
            _buildContentSection(theme, impulse),
            const SizedBox(height: 20),

            // 3 Mini-Formate
            _buildMiniFormat(
              theme,
              index: 0,
              emoji: '\u{26A1}',
              title: companions.isNotEmpty
                  ? companions[0].title
                  : 'Kurz verstanden',
              duration:
                  companions.isNotEmpty ? companions[0].durationLabel : '2 Min',
              content: companions.isNotEmpty
                  ? companions[0].summary
                  : impulse.contentBody.split('\n').first,
              color: const Color(0xFF0EA5E9),
            ),
            const SizedBox(height: 10),
            _buildMiniFormat(
              theme,
              index: 1,
              emoji: '\u{1F3AF}',
              title: companions.length > 2
                  ? companions[2].title
                  : 'Praxis für heute',
              duration:
                  companions.length > 2 ? companions[2].durationLabel : '5 Min',
              content: impulse.practicalTip,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 10),
            _buildMiniFormat(
              theme,
              index: 2,
              emoji: '\u{1F31F}',
              title: companions.length > 3
                  ? companions[3].title
                  : 'Abend-Reflexion',
              duration:
                  companions.length > 3 ? companions[3].durationLabel : '2 Min',
              content: companions.length > 3
                  ? companions[3].summary
                  : 'Was hat heute gut funktioniert? Welchen Moment mit deinem Kind willst du festhalten?',
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 20),

            // KI-Vertiefung
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      initialMessage:
                          '___TIP_EXPAND___${impulse.title}: ${impulse.practicalTip}',
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('learn_more'),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(_t('ai_explains_personal'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // "Für heute gelesen" Completion Button
            if (!_impulseCompleted)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _markImpulseCompleted,
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(_t('daily_done_mark')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side:
                        const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Text(
                      AppStringsManager.getString(
                          languageService.currentLanguage,
                          'daily_done_message'),
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF166534))),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniFormat(
    ThemeData theme, {
    required int index,
    required String emoji,
    required String title,
    required String duration,
    required String content,
    required Color color,
  }) {
    final isExpanded = _expandedFormat == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _expandedFormat = isExpanded ? -1 : index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpanded
              ? color.withValues(alpha: 0.06)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.2)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Audio für diesen Abschnitt
              GestureDetector(
                onTap: () => _playAudio(content),
                child: Row(
                  children: [
                    Icon(
                      _isPlayingAudio
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPlayingAudio ? _t('stop') : _t('listen'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Schriftlicher Inhalt des Tagesimpulses ─────────────────────────────────

  bool _contentExpanded = false;

  Widget _buildContentSection(ThemeData theme, WeeklyImpulse impulse) {
    final content = impulse.contentBody;
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final preview = lines.take(3).join('\n');
    final hasMore = lines.length > 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F4DD}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t('read_content'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (impulse.audioScript != null)
                GestureDetector(
                  onTap: () => _playAudio(impulse.audioScript ?? content),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlayingAudio
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isPlayingAudio ? _t('stop') : _t('listen'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _contentExpanded ? content : preview,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (hasMore) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _contentExpanded = !_contentExpanded),
              child: Row(
                children: [
                  Text(
                    _contentExpanded ? _t('show_less') : _t('read_more'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _contentExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: ENTWICKLUNG — Kind-Profil + Altersgerechte Fragen + KI-Bericht
  // ═══════════════════════════════════════════════════════════════════════════

  ChildProfile? _childProfile;
  List<DevDomain> _devDomains = [];
  final Map<String, int> _devAnswers = {};
  bool _devDone = false;
  bool _hasSpecialNeeds = false;
  String? _aiReport;
  bool _generatingReport = false;

  Future<void> _loadCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('dev.child_name');
    final birthStr = prefs.getString('dev.child_birth');
    final care = prefs.getString('dev.child_care');
    if (name != null && birthStr != null) {
      final birth = DateTime.tryParse(birthStr);
      if (birth != null) {
        _childProfile = ChildProfile(
            name: name, birthDate: birth, careType: care ?? 'zuhause');
        _hasSpecialNeeds = prefs.getBool('dev.child_special_needs') ?? false;
        _devDomains = DevelopmentQuestionBank.getQuestionsForAge(
            _childProfile!.ageGroupId);
      }
    }
    final saved = prefs.getString('dev.answers.v3');
    if (saved != null && saved.isNotEmpty) {
      for (final part in saved.split(',')) {
        final kv = part.split(':');
        if (kv.length == 2) _devAnswers[kv[0]] = int.tryParse(kv[1]) ?? 0;
      }
      final tQ = _devDomains.fold(0, (int s, d) => s + d.questions.length);
      _devDone = _devAnswers.length >= tQ;
    }
    _aiReport = prefs.getString('dev.ai_report.v3');
    if (mounted) setState(() {});
  }

  Future<void> _saveDevAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dev.answers.v3',
        _devAnswers.entries.map((e) => '${e.key}:${e.value}').join(','));
  }

  Future<void> _saveChildProfile(String name, DateTime birth, String care,
      {bool hasSpecialNeeds = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dev.child_name', name);
    await prefs.setString('dev.child_birth', birth.toIso8601String());
    await prefs.setString('dev.child_care', care);
    await prefs.setBool('dev.child_special_needs', hasSpecialNeeds);
    setState(() {
      _childProfile =
          ChildProfile(name: name, birthDate: birth, careType: care);
      _hasSpecialNeeds = hasSpecialNeeds;
      _devDomains =
          DevelopmentQuestionBank.getQuestionsForAge(_childProfile!.ageGroupId);
      _devAnswers.clear();
      _devDone = false;
      _aiReport = null;
    });
  }

  Future<void> _generateAIReport() async {
    if (_childProfile == null) return;

    // Report-Limit prüfen
    final limitService = DevelopmentReportLimitService.instance;
    if (limitService.isLimitReached) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dein kostenloser Bericht für dieses Jahr wurde bereits erstellt. '
            '${limitService.nextFreeReportInfo}',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Premium',
            onPressed: () {
              // TODO: Open Premium sheet
            },
          ),
        ),
      );
      return;
    }

    setState(() => _generatingReport = true);
    final p = _childProfile!;
    final sb = StringBuffer();
    sb.writeln(
        'Kind: ${p.name}, Alter: ${p.ageLabel}, Betreuung: ${p.careType}');
    sb.writeln('Altersgruppe: ${p.ageGroupId}\n');
    for (final d in _devDomains) {
      sb.writeln('${d.title}:');
      for (int i = 0; i < d.questions.length; i++) {
        final a = _devAnswers['${d.id}_$i'] ?? 0;
        final label = a == 2
            ? 'Ja'
            : a == 1
                ? 'Manchmal'
                : 'Noch nicht';
        sb.writeln('  ${d.questions[i]} -> $label');
      }
      sb.writeln('');
    }
    final specialNeedsNote = _hasSpecialNeeds
        ? '\n- WICHTIG: Dieses Kind hat besondere Bedürfnisse. Vergleiche NICHT mit Altersnormen. '
            'Beschreibe nur den individuellen Fortschritt. Statt "Förderbedarf" sage "wächst in eigenem Tempo". '
            'Sei besonders wertschätzend und stärkend.\n'
        : '';
    final prompt =
        'Du schreibst eine pädagogische Entwicklungseinschätzung für Eltern. '
        'WICHTIGE REGELN:\n'
        '- Schreibe AUS DER PERSPEKTIVE DER APP (nicht Kita, nicht Erzieher).\n'
        '- Erster Satz: "Basierend auf euren Angaben zeigt [Name] folgendes Entwicklungsprofil:"\n'
        '- KEINE Bewertungswörter wie "toll", "super", "gut", "wunderbar", "schlecht", "sehr gut".\n'
        '- Stattdessen: fachlich, objektiv, wertschätzend. Beschreibe WAS das Kind zeigt, nicht WIE GUT.\n'
        '- Benutze Formulierungen wie: "zeigt sich sicher in...", "befindet sich im typischen Entwicklungsfenster für...", "beginnt zunehmend...", "übt aktuell..."\n'
        '- Struktur: 1) Sichtbare Kompetenzen (was das Kind bereits zeigt), 2) Aktuelle Entwicklungsfelder (woran es gerade wächst), 3) Impulse für den Alltag (2-3 konkrete Ideen)\n'
        '- Maximal 180 Wörter. Keine Emojis. Keine Sterne-Formatierung.\n'
        '- Kein "Liebe Eltern" am Anfang.\n'
        '$specialNeedsNote\n$sb';

    try {
      final text = await GeminiAIService().generateText(prompt);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dev.ai_report.v3', text);
      // Bericht-Historie speichern
      final historyRaw = prefs.getStringList('dev.report_history') ?? [];
      final entry = '${DateTime.now().toIso8601String()}|||$text';
      historyRaw.insert(0, entry);
      if (historyRaw.length > 12) historyRaw.removeRange(12, historyRaw.length);
      await prefs.setStringList('dev.report_history', historyRaw);
      // Report-Limit tracken
      await DevelopmentReportLimitService.instance.recordReportCreated();
      if (mounted)
        setState(() {
          _aiReport = text;
          _generatingReport = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _aiReport = 'Bericht konnte nicht erstellt werden: $e';
          _generatingReport = false;
        });
    }
  }

  Future<void> _downloadPDF() async {
    HapticFeedback.mediumImpact();
    await _exportPdf();
  }

  Widget _buildHistoryButton(ThemeData theme) {
    return GestureDetector(
      onTap: _showReportHistory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(Icons.history_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_t('previous_reports'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: theme.colorScheme.outline),
        ]),
      ),
    );
  }

  Future<void> _showReportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyRaw = prefs.getStringList('dev.report_history') ?? [];
    if (!mounted) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(children: [
                const Text('\u{1F4C5}', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(_t('report_history'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close_rounded,
                        color: theme.colorScheme.outline)),
              ])),
          const Divider(height: 1),
          if (historyRaw.isEmpty)
            Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_t('no_reports_yet'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
          else
            Flexible(
                child: ListView.builder(
              shrinkWrap: true,
              itemCount: historyRaw.length,
              itemBuilder: (_, i) {
                final parts = historyRaw[i].split('|||');
                final date = DateTime.tryParse(parts[0]) ?? DateTime.now();
                final text = parts.length > 1 ? parts[1] : '';
                final dateLabel = '${date.day}.${date.month}.${date.year}';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.description_rounded,
                                size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(dateLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary)),
                            if (i == 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(_t('current'),
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary)))
                            ],
                          ]),
                          const SizedBox(height: 8),
                          Text(text,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(height: 1.4),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis),
                        ]),
                  ),
                );
              },
            )),
        ]),
      ),
    );
  }

  void _resetDev() {
    HapticFeedback.mediumImpact();
    setState(() {
      _devAnswers.clear();
      _devDone = false;
      _aiReport = null;
    });
    _saveDevAnswers();
  }

  Widget _buildDevelopmentTab(ThemeData theme) {
    if (_childProfile == null) return _buildProfileSetup(theme);
    final tQ = _devDomains.fold(0, (int s, d) => s + d.questions.length);
    final answered = _devAnswers.length;
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildChildHeader(theme),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: tQ > 0 ? answered / tQ : 0,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary)))),
            const SizedBox(width: 10),
            Text('$answered/$tQ',
                style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary))
          ]),
          const SizedBox(height: 18),
          ..._devDomains.map((d) => _buildDevDomain(theme, d)),
          // Hinweis wenn nicht alle Fragen beantwortet
          if (!_devDone &&
              answered > 0 &&
              !_generatingReport &&
              _aiReport == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: 0.2)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        'Noch ${tQ - answered} Fragen offen. Beantworte alle Fragen um deinen persönlichen KI-Bericht zu erhalten.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9A3412), height: 1.4),
                      )),
                    ]),
              ),
            ),
          if (_devDone && _aiReport == null && !_generatingReport)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: _generateAIReport,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(_t('generate_report')),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)))))),
          if (_generatingReport)
            Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(_t('generating_report'))
                ]))),
          if (_aiReport != null) ...[
            const SizedBox(height: 20),
            _buildReportCard(theme),
            const SizedBox(height: 10),
            _buildHistoryButton(theme),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: _downloadPDF,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(_t('save_as_pdf')),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)))))
          ],
          const SizedBox(height: 20),
          if (_devAnswers.isNotEmpty)
            Center(
                child: TextButton.icon(
                    onPressed: _resetDev,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_t('do_again')))),
          Center(
              child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('dev.child_name');
                    setState(() {
                      _childProfile = null;
                      _devDomains = [];
                      _devAnswers.clear();
                      _devDone = false;
                      _aiReport = null;
                    });
                  },
                  child: Text(_t('other_child')))),
        ]));
  }

  Widget _buildProfileSetup(ThemeData theme) {
    final nameCtrl = TextEditingController();
    DateTime? selectedDate;
    String selectedCare = 'kita';
    bool hasSpecialNeeds = false;
    return StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 24),
              Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary
                      ]),
                      borderRadius: BorderRadius.circular(22)),
                  child: const Center(
                      child:
                          Text('\u{1F9D2}', style: TextStyle(fontSize: 34)))),
              const SizedBox(height: 20),
              Text(_t('about_your_child'),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'fits_age'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText: 'Name des Kindes',
                      hintText: 'z.B. Emma',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now()
                                .subtract(const Duration(days: 900)),
                            firstDate: DateTime(2006),
                            lastDate: DateTime.now());
                        if (d != null) setLocal(() => selectedDate = d);
                      },
                      icon: const Icon(Icons.cake_rounded, size: 18),
                      label: Text(selectedDate != null
                          ? '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year}'
                          : 'Geburtsdatum wählen'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))))),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                  value: selectedCare,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: _t('care_type'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14))),
                  items: [
                    DropdownMenuItem(
                        value: 'kita', child: Text(_t('care_kita'))),
                    DropdownMenuItem(
                        value: 'tagesmutter',
                        child: Text(_t('care_tagesmutter'))),
                    DropdownMenuItem(
                        value: 'zuhause', child: Text(_t('care_home'))),
                    DropdownMenuItem(
                        value: 'andere', child: Text(_t('care_other')))
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => selectedCare = v);
                  }),
              const SizedBox(height: 14),
              // Besondere Bedürfnisse
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                ),
                child: CheckboxListTile(
                  value: hasSpecialNeeds,
                  onChanged: (v) =>
                      setLocal(() => hasSpecialNeeds = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF8B5CF6),
                  title: const Text('Mein Kind hat besondere Bedürfnisse',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'z.B. Entwicklungsverzögerung, Behinderung, chronische Erkrankung. '
                    'Der Bericht vergleicht dann mit dem eigenen Fortschritt — nicht mit Altersnormen.',
                    style: TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty ||
                            selectedDate == null) return;
                        _saveChildProfile(
                            nameCtrl.text.trim(), selectedDate!, selectedCare,
                            hasSpecialNeeds: hasSpecialNeeds);
                      },
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: Text(_t('next')))),
            ])));
  }

  Widget _buildChildHeader(ThemeData theme) {
    final p = _childProfile!;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(
                  child: Text('\u{1F9D2}', style: TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(p.ageLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              ]))
        ]));
  }

  Widget _buildDevDomain(ThemeData theme, DevDomain domain) {
    final answered = domain.questions
        .asMap()
        .entries
        .where((e) => _devAnswers.containsKey('${domain.id}_${e.key}'))
        .length;
    final done = answered == domain.questions.length;
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: done
                        ? domain.color.withValues(alpha: 0.3)
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(domain.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(domain.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(domain.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11))
                    ])),
                if (done)
                  Icon(Icons.check_circle_rounded,
                      color: domain.color, size: 20),
                Text('$answered/${domain.questions.length}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline))
              ]),
              const SizedBox(height: 14),
              ...domain.questions.asMap().entries.map((e) {
                final key = '${domain.id}_${e.key}';
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(height: 1.4)),
                          const SizedBox(height: 8),
                          Row(children: [
                            _answerChip(
                                theme, key, 2, 'Ja', const Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            _answerChip(theme, key, 1, 'Manchmal',
                                const Color(0xFFF59E0B)),
                            const SizedBox(width: 6),
                            _answerChip(theme, key, 0, 'Noch nicht',
                                const Color(0xFFEF4444))
                          ]),
                        ]));
              }),
              if (done)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: domain.color.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  AppStringsManager.getString(
                                      languageService.currentLanguage,
                                      'tip_label'),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: domain.color)),
                              ...domain.tips.map((t) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('\u{2022} $t',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontSize: 11, height: 1.3))))
                            ]))),
            ])));
  }

  Widget _answerChip(
      ThemeData theme, String key, int val, String label, Color color) {
    final sel = _devAnswers[key] == val;
    return Expanded(
        child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _devAnswers[key] = val;
                final tQ =
                    _devDomains.fold(0, (int s, d) => s + d.questions.length);
                _devDone = _devAnswers.length >= tQ;
              });
              _saveDevAnswers();
            },
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                    color: sel
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? color : theme.colorScheme.outlineVariant,
                        width: sel ? 2 : 1)),
                child: Center(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? color
                                : theme.colorScheme.onSurfaceVariant))))));
  }

  Widget _buildReportCard(ThemeData theme) {
    return Column(children: [
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('\u{1F4CB}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    AppStringsManager.getString(languageService.currentLanguage,
                        'pedagogical_assessment'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              // PDF Export button (Premium)
              if (PremiumService.instance.isPremium ||
                  !MonetizationConfig.enabled)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  tooltip: 'Als PDF speichern',
                  color: const Color(0xFFDC2626),
                  onPressed: _exportPdf,
                ),
            ]),
            const SizedBox(height: 4),
            Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'ai_based_report'),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
            const SizedBox(height: 14),
            Text(_aiReport ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
          ])),
      // Entwicklungs-Verlauf-Chart (Premium oder Beta)
      if (PremiumService.instance.isPremium || !MonetizationConfig.enabled) ...[
        const SizedBox(height: 16),
        DevelopmentProgressChart(
          currentScores: _currentDevScores(),
          previousScores: _previousDevScores(),
          previousDate: _previousCheckDate(),
        ),
      ],
    ]);
  }

  Map<String, double> _currentDevScores() {
    final scores = <String, double>{};
    for (final domain in _devDomains) {
      final questions = domain.questions;
      if (questions.isEmpty) continue;
      int answered = 0;
      int positive = 0;
      for (int i = 0; i < questions.length; i++) {
        final key = '${domain.id}_$i';
        final answer = _devAnswers[key];
        if (answer != null) {
          answered++;
          if (answer >= 1) positive++;
        }
      }
      if (answered > 0) {
        scores[domain.id] = positive / answered;
      }
    }
    return scores;
  }

  Map<String, double>? _previousDevScores() {
    // Laden aus dem MonthlyCardMeta (letzter gespeicherter Check)
    // Wird beim nächsten Check verfügbar
    return null; // TODO: Load from SharedPreferences when history exists
  }

  DateTime? _previousCheckDate() {
    return null; // TODO: Load from SharedPreferences
  }

  Future<void> _exportPdf() async {
    if (_childProfile == null) return;
    final childName =
        _childProfile!.name.isNotEmpty ? _childProfile!.name : 'Kind';
    final ageMonths = _childProfile!.ageInMonths;
    final years = ageMonths ~/ 12;
    final months = ageMonths % 12;
    final ageText =
        months > 0 ? '$years Jahre, $months Monate' : '$years Jahre';

    await DevelopmentPdfService.generateAndShow(
      childName: childName,
      childAge: ageText,
      currentScores: _currentDevScores(),
      previousScores: _previousDevScores(),
      previousDate: _previousCheckDate(),
      aiReportText: _aiReport,
    );
  }

  // ─── TAB 3: WISSEN ────────────────────────────────────────────────────────
  Widget _buildWissenTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElternWissenWidget(
            key: ValueKey(_wissenTopic), // rebuild when topic changes
            initialTopic: _wissenTopic,
            onOpenChat: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),
          const ExpertBibliothekSection(),
        ],
      ),
    );
  }

  // ─── Header: Begrüßung + Streak + Stimmungscheck ──────────────────────────
  Widget _buildDailyHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting + Streak Row
        Row(
          children: [
            Expanded(
              child: Text(
                _getMoodGreeting(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (_streak > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD79A)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔥', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('$_streak Tage',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A4B00))),
                ]),
              ),
            ],
          ],
        ),
        // Mood Check-in
        if (_todayMood == 0) ...[
          const SizedBox(height: 10),
          _buildMoodCheckIn(theme),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildMoodCheckIn(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'how_are_you'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          ...[
            ('😮‍💨', 'Erschöpft', 1),
            ('😌', 'Okay', 2),
            ('🌟', 'Top', 3),
          ].map((item) => GestureDetector(
                onTap: () => _saveMood(item.$3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.$1, style: const TextStyle(fontSize: 22)),
                    Text(item.$2,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9)),
                  ]),
                ),
              )),
        ],
      ),
    );
  }

  // ─── Soforthilfe — "Was ist gerade los?" ─────────────────────────────────
  Widget _buildSoforthilfe(ThemeData theme) {
    final cards = [
      (
        emoji: '😤',
        label: _t('topic_defiance_anger'),
        topic: 'trotz',
        color: const Color(0xFFDC2626)
      ),
      (
        emoji: '😴',
        label: _t('topic_sleep_issues'),
        topic: 'schlafen',
        color: const Color(0xFF7C3AED)
      ),
      (
        emoji: '✋',
        label: _t('topic_hits_bites'),
        topic: 'haut',
        color: const Color(0xFFEA580C)
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'whats_going_on'),
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: cards.map((card) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: card.topic == cards.last.topic ? 0 : 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _wissenTopic = card.topic);
                    _tabController.animateTo(2);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: card.color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(card.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(card.label,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: card.color,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
