import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/product_metrics_service.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

import 'development_schema_data.dart';

String _t(String key) => AppStringsManager.getString(
      languageService.currentLanguage,
      'package2_$key',
    );

String _tf(String key, Map<String, Object> values) => values.entries.fold(
      _t(key),
      (text, entry) => text.replaceAll('{${entry.key}}', '${entry.value}'),
    );

Map<String, String> get kMilestoneStatusLabels => {
      'NOCH_NICHT': _t('development_status_not_yet'),
      'ANSATZWEISE': _t('development_status_emerging'),
      'WEITGEHEND': _t('development_status_mostly'),
      'ZUVERLAESSIG': _t('development_status_reliable'),
    };

Map<int, String> get kSelfCheckOptionLabels => {
      0: _t('development_self_check_not_yet'),
      1: _t('development_self_check_rarely'),
      2: _t('development_self_check_often'),
      3: _t('development_self_check_confident'),
    };

class _DevelopmentDomainProfile {
  final String id;
  final IconData icon;
  final Color color;

  const _DevelopmentDomainProfile({
    required this.id,
    required this.icon,
    required this.color,
  });

  String get title => _t('development_domain_${id}_title');
  String get description => _t('development_domain_${id}_description');
  List<String> get questions => List<String>.generate(
        3,
        (index) => _t('development_domain_${id}_question_${index + 1}'),
      );
  List<String> get parentActions => List<String>.generate(
        2,
        (index) => _t('development_domain_${id}_action_${index + 1}'),
      );
}

const List<_DevelopmentDomainProfile> _kParentSelfCheckDomains = [
  _DevelopmentDomainProfile(
    id: 'motorik',
    icon: Icons.directions_run_rounded,
    color: Color(0xFF0EA5E9),
  ),
  _DevelopmentDomainProfile(
    id: 'sprache',
    icon: Icons.record_voice_over_rounded,
    color: Color(0xFF16A34A),
  ),
  _DevelopmentDomainProfile(
    id: 'denken',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFF59E0B),
  ),
  _DevelopmentDomainProfile(
    id: 'sozial',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEC4899),
  ),
  _DevelopmentDomainProfile(
    id: 'selbst',
    icon: Icons.task_alt_rounded,
    color: Color(0xFF8B5CF6),
  ),
];

List<String> _detailedQuestionsForDomain(String domainId) =>
    List<String>.generate(
      10,
      (index) => _t('development_domain_${domainId}_detailed_${index + 1}'),
    );

const double _kCoreQuestionWeight = 1.35;
const double _kDetailedQuestionWeight = 1.0;
const String _kSelfCheckScoringModelVersion = 'phase_weighted_v3';
const bool _kDebugSuppressIntro =
    bool.fromEnvironment('PP_DEBUG_SUPPRESS_INTRO', defaultValue: false);

const Map<String, Map<String, double>> _kPhaseDomainWeights = {
  'early': {
    'motorik': 1.15,
    'sprache': 1.10,
    'denken': 0.95,
    'sozial': 1.05,
    'selbst': 0.95,
  },
  'middle': {
    'motorik': 1.00,
    'sprache': 1.15,
    'denken': 1.10,
    'sozial': 1.15,
    'selbst': 1.00,
  },
  'late': {
    'motorik': 0.95,
    'sprache': 1.10,
    'denken': 1.20,
    'sozial': 1.05,
    'selbst': 1.20,
  },
};

class _ChildProfile {
  final String id;

  const _ChildProfile({required this.id});

  String get label => _t('development_child_${id.split('_').last}');
}

const List<_ChildProfile> _childProfiles = [
  _ChildProfile(id: 'kind_1'),
  _ChildProfile(id: 'kind_2'),
  _ChildProfile(id: 'kind_3'),
];

class _PhaseTheme {
  final Color color;
  final IconData icon;

  const _PhaseTheme({required this.color, required this.icon});
}

class _PhaseSnapshot {
  final int total;
  final int completed;
  final int inProgress;
  final int notStarted;

  const _PhaseSnapshot({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.notStarted,
  });

  double get progress => total == 0 ? 0 : completed / total;
}

class _TrendItem {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final int? delta;

  const _TrendItem({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.delta,
  });
}

class _TrendSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  const _TrendSparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (size.width * i) / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      points.add(Offset(x, y));
    }

    final areaPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawPath(areaPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = lineColor;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 2.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _BellerModernRadarPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color strokeColor;

  const _BellerModernRadarPainter({
    required this.values,
    required this.colors,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 18;
    const rings = 3;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = strokeColor.withValues(alpha: 0.28);

    for (var ring = 1; ring <= rings; ring++) {
      final ringRadius = radius * (ring / rings);
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final angle = (-90 + (360 / values.length) * i) * (3.1415926535 / 180);
        final point = Offset(
          center.dx + ringRadius * math.cos(angle),
          center.dy + ringRadius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < values.length; i++) {
      final angle = (-90 + (360 / values.length) * i) * (3.1415926535 / 180);
      final edge = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, edge, gridPaint);
    }

    final valuePath = Path();
    for (var i = 0; i < values.length; i++) {
      final clamped = values[i].clamp(0.0, 1.0);
      final valueRadius = radius * clamped;
      final angle = (-90 + (360 / values.length) * i) * (3.1415926535 / 180);
      final point = Offset(
        center.dx + valueRadius * math.cos(angle),
        center.dy + valueRadius * math.sin(angle),
      );
      if (i == 0) {
        valuePath.moveTo(point.dx, point.dy);
      } else {
        valuePath.lineTo(point.dx, point.dy);
      }
    }
    valuePath.close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          const Color(0xFF0EA5E9).withValues(alpha: 0.35),
          const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        ],
      );
    canvas.drawPath(valuePath, fillPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF0F172A);
    canvas.drawPath(valuePath, linePaint);

    for (var i = 0; i < values.length; i++) {
      final clamped = values[i].clamp(0.0, 1.0);
      final valueRadius = radius * clamped;
      final angle = (-90 + (360 / values.length) * i) * (3.1415926535 / 180);
      final point = Offset(
        center.dx + valueRadius * math.cos(angle),
        center.dy + valueRadius * math.sin(angle),
      );
      final color = colors[i % colors.length];
      canvas.drawCircle(point, 4.8, Paint()..color = color);
      canvas.drawCircle(
        point,
        2.2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BellerModernRadarPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.strokeColor != strokeColor;
  }
}

class _StoredMilestoneProgress {
  final String status;
  final DateTime updatedAt;

  const _StoredMilestoneProgress({
    required this.status,
    required this.updatedAt,
  });

  factory _StoredMilestoneProgress.fromJson(Map<String, dynamic> json) {
    return _StoredMilestoneProgress(
      status: json['status'] as String? ?? 'NOCH_NICHT',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class _ProgressEvent {
  final String code;
  final String title;
  final String status;
  final DateTime updatedAt;

  const _ProgressEvent({
    required this.code,
    required this.title,
    required this.status,
    required this.updatedAt,
  });

  factory _ProgressEvent.fromJson(Map<String, dynamic> json) {
    return _ProgressEvent(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'NOCH_NICHT',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'status': status,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class DevelopmentSchemaCard extends StatefulWidget {
  final String childId;

  const DevelopmentSchemaCard({super.key, this.childId = 'default'});

  @override
  State<DevelopmentSchemaCard> createState() => _DevelopmentSchemaCardState();
}

class _DevelopmentSchemaCardState extends State<DevelopmentSchemaCard>
    with SingleTickerProviderStateMixin {
  int _selectedPhaseIndex = 0;
  String _selectedChildId = _childProfiles.first.id;
  bool _isLoading = true;
  bool _showOnlyImprovements = false;
  bool _monthlyCardDarkStyle = false;
  bool _selfCheckQuickMode = true;
  bool _isSixMonthDetailedCheck = false;
  bool _onboardingDismissed = false;
  int _detailedCheckStage = 0;
  bool _introOverlayShownThisSession = false;
  String? _activeQuickDomainId;
  bool _reminderPaused = false;
  DateTime? _reminderSnoozeUntil;
  DateTime? _lastReminderShownAt;
  bool _reminderExposureWritePending = false;
  DateTime? _lastDetailedCheckAt;
  DateTime? _lastMonthlyCardAt;
  Map<String, dynamic>? _lastMonthlyCardSnapshot;
  Map<String, _StoredMilestoneProgress> _progressByCode = {};
  List<_ProgressEvent> _history = [];
  Map<String, int> _selfCheckAnswers = {};
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..forward();
    _loadSelectionAndProgress();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedSection({
    required int order,
    required Widget child,
  }) {
    final start = (order * 0.07).clamp(0.0, 0.82).toDouble();
    final end = (start + 0.24).clamp(start + 0.01, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _revealController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
    );
  }

  String _selectionStorageKey() =>
      'development_selected_child_${widget.childId}';

  String _storageKey() =>
      'development_progress_${widget.childId}_$_selectedChildId';

  String _historyKey() =>
      'development_progress_history_${widget.childId}_$_selectedChildId';

  String _monthlyCardMetaKey() =>
      'development_monthly_card_meta_${widget.childId}';

  String _selfCheckKey() =>
      'development_parent_selfcheck_${widget.childId}_${_selectedChildId}_phase$_selectedPhaseIndex';

  String _onboardingSeenKey() =>
      'development_onboarding_seen_${widget.childId}_$_selectedChildId';

  String _introOverlaySeenKey() =>
      'development_intro_overlay_seen_${widget.childId}_$_selectedChildId';

  String _reminderSettingsKey() =>
      'development_reminder_settings_${widget.childId}_$_selectedChildId';

  String _detailedCheckMetaKey() =>
      'development_detailed_check_meta_${widget.childId}_$_selectedChildId';

  Future<void> _loadSelectionAndProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedChild = prefs.getString(_selectionStorageKey());
    final monthlyCardRaw = prefs.getString(_monthlyCardMetaKey());

    if (selectedChild != null &&
        _childProfiles.any((profile) => profile.id == selectedChild)) {
      _selectedChildId = selectedChild;
    }

    if (monthlyCardRaw != null && monthlyCardRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(monthlyCardRaw) as Map<String, dynamic>;
        _lastMonthlyCardSnapshot = decoded;
        final generatedAt = decoded['generatedAt'] as String?;
        if (generatedAt != null) {
          _lastMonthlyCardAt = DateTime.tryParse(generatedAt)?.toLocal();
        }
      } catch (_) {
        _lastMonthlyCardAt = null;
        _lastMonthlyCardSnapshot = null;
      }
    }

    await _loadProgress();
  }

  Future<void> _selectChild(String childId) async {
    if (_selectedChildId == childId) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectionStorageKey(), childId);

    if (!mounted) return;
    setState(() {
      _selectedChildId = childId;
      _isLoading = true;
      _activeQuickDomainId = null;
      _introOverlayShownThisSession = false;
    });

    await _loadProgress();
  }

  Future<void> _selectPhase(int index) async {
    if (_selectedPhaseIndex == index) return;
    setState(() {
      _selectedPhaseIndex = index;
      _isLoading = true;
      _activeQuickDomainId = null;
    });
    await _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
    final historyRaw = prefs.getString(_historyKey());
    final selfCheckRaw = prefs.getString(_selfCheckKey());
    final reminderRaw = prefs.getString(_reminderSettingsKey());
    final detailedMetaRaw = prefs.getString(_detailedCheckMetaKey());
    final onboardingSeen = prefs.getBool(_onboardingSeenKey()) ?? false;
    final introOverlaySeen = prefs.getBool(_introOverlaySeenKey()) ?? false;
    final loaded = <String, _StoredMilestoneProgress>{};
    final loadedHistory = <_ProgressEvent>[];
    final loadedSelfCheck = <String, int>{};
    var reminderPaused = false;
    DateTime? reminderSnoozeUntil;
    DateTime? lastReminderShownAt;
    DateTime? loadedDetailedCheckAt;

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          loaded[entry.key] = _StoredMilestoneProgress.fromJson(value);
        }
      }
    }

    if (historyRaw != null && historyRaw.isNotEmpty) {
      final decodedHistory = jsonDecode(historyRaw) as List<dynamic>;
      for (final entry in decodedHistory) {
        if (entry is Map<String, dynamic>) {
          loadedHistory.add(_ProgressEvent.fromJson(entry));
        }
      }
      loadedHistory.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    if (selfCheckRaw != null && selfCheckRaw.isNotEmpty) {
      final decodedSelfCheck = jsonDecode(selfCheckRaw) as Map<String, dynamic>;
      for (final entry in decodedSelfCheck.entries) {
        final value = entry.value;
        if (value is num) {
          loadedSelfCheck[entry.key] = value.toInt().clamp(0, 3);
        }
      }
    }

    if (reminderRaw != null && reminderRaw.isNotEmpty) {
      try {
        final decodedReminder = jsonDecode(reminderRaw) as Map<String, dynamic>;
        reminderPaused = decodedReminder['paused'] == true;
        final snoozeText = decodedReminder['snoozeUntil'] as String?;
        if (snoozeText != null) {
          reminderSnoozeUntil = DateTime.tryParse(snoozeText)?.toLocal();
        }
        final lastShownText = decodedReminder['lastShownAt'] as String?;
        if (lastShownText != null) {
          lastReminderShownAt = DateTime.tryParse(lastShownText)?.toLocal();
        }
      } catch (_) {
        reminderPaused = false;
        reminderSnoozeUntil = null;
        lastReminderShownAt = null;
      }
    }

    if (detailedMetaRaw != null && detailedMetaRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(detailedMetaRaw) as Map<String, dynamic>;
        final rawDate = decoded['lastDetailedCheckAt'] as String?;
        if (rawDate != null) {
          loadedDetailedCheckAt = DateTime.tryParse(rawDate)?.toLocal();
        }
      } catch (_) {
        loadedDetailedCheckAt = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _progressByCode = loaded;
      _history = loadedHistory;
      _selfCheckAnswers = loadedSelfCheck;
      _reminderPaused = reminderPaused;
      _reminderSnoozeUntil = reminderSnoozeUntil;
      _lastReminderShownAt = lastReminderShownAt;
      _lastDetailedCheckAt = loadedDetailedCheckAt;
      _onboardingDismissed = onboardingSeen || _kDebugSuppressIntro;
      _isLoading = false;
    });

    if (!_kDebugSuppressIntro && !introOverlaySeen) {
      await _markIntroOverlaySeen();
      _showIntroOverlayIfNeeded();
    }
  }

  Future<void> _markIntroOverlaySeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introOverlaySeenKey(), true);
  }

  void _showIntroOverlayIfNeeded() {
    if (_kDebugSuppressIntro) return;
    if (_introOverlayShownThisSession || !mounted) return;
    _introOverlayShownThisSession = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(_t('development_intro_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('development_intro_subtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(_t('development_intro_step_1')),
                const SizedBox(height: 6),
                Text(_t('development_intro_step_2')),
                const SizedBox(height: 6),
                Text(_t('development_intro_step_3')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t('development_intro_confirm')),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _dismissOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey(), true);
    if (!mounted) return;
    setState(() {
      _onboardingDismissed = true;
    });
  }

  bool _isDetailedCheckDue() {
    if (_lastDetailedCheckAt == null) return true;
    return DateTime.now().difference(_lastDetailedCheckAt!).inDays >= 180;
  }

  List<String> _questionsForDomain(
    _DevelopmentDomainProfile domain, {
    required bool detailed,
  }) {
    if (!detailed) return domain.questions;
    final extra = _detailedQuestionsForDomain(domain.id);
    return [...domain.questions, ...extra];
  }

  int _detailedAnsweredCount() {
    var answered = 0;
    for (final domain in _kParentSelfCheckDomains) {
      final questions = _questionsForDomain(domain, detailed: true);
      for (var i = 0; i < questions.length; i++) {
        if (_selfCheckAnswers.containsKey('${domain.id}::$i')) {
          answered++;
        }
      }
    }
    return answered;
  }

  int _detailedTotalQuestionCount() {
    var total = 0;
    for (final domain in _kParentSelfCheckDomains) {
      total += _questionsForDomain(domain, detailed: true).length;
    }
    return total;
  }

  Future<void> _markDetailedCheckCompleted() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _detailedCheckMetaKey(),
      jsonEncode({'lastDetailedCheckAt': now.toIso8601String()}),
    );
    if (!mounted) return;
    setState(() {
      _lastDetailedCheckAt = now;
      _isSixMonthDetailedCheck = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Detailcheck gespeichert. Nächste Empfehlung ab ${_formatDate(now.add(const Duration(days: 180)))}.'),
      ),
    );
  }

  Future<void> _persistReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _reminderSettingsKey(),
      jsonEncode({
        'paused': _reminderPaused,
        'snoozeUntil': _reminderSnoozeUntil?.toIso8601String(),
        'lastShownAt': _lastReminderShownAt?.toIso8601String(),
      }),
    );
  }

  void _queueReminderExposureStamp() {
    final now = DateTime.now();
    if (_reminderExposureWritePending) return;
    if (_lastReminderShownAt != null &&
        now.difference(_lastReminderShownAt!).inHours < 24) {
      return;
    }

    _reminderExposureWritePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _reminderExposureWritePending = false;
        return;
      }

      final shownAt = DateTime.now();
      setState(() {
        _lastReminderShownAt = shownAt;
      });
      await _persistReminderSettings();
      _reminderExposureWritePending = false;
    });
  }

  Future<void> _snoozeReminder(int days) async {
    final target = DateTime.now().add(Duration(days: days));
    setState(() {
      _reminderPaused = false;
      _reminderSnoozeUntil = target;
    });
    await _persistReminderSettings();
  }

  Future<void> _setReminderPaused(bool paused) async {
    setState(() {
      _reminderPaused = paused;
      if (!paused) {
        _reminderSnoozeUntil = null;
      }
    });
    await _persistReminderSettings();
  }

  bool _isReminderSnoozed() {
    if (_reminderSnoozeUntil == null) return false;
    return DateTime.now().isBefore(_reminderSnoozeUntil!);
  }

  Future<void> _clearReminderSnooze() async {
    setState(() {
      _reminderSnoozeUntil = null;
    });
    await _persistReminderSettings();
  }

  Future<void> _setSelfCheckAnswer(
    _DevelopmentDomainProfile domain,
    int questionIndex,
    int value,
  ) async {
    final key = '${domain.id}::$questionIndex';
    final updated = Map<String, int>.from(_selfCheckAnswers);
    updated[key] = value.clamp(0, 3);

    setState(() {
      _selfCheckAnswers = updated;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selfCheckKey(), jsonEncode(updated));

    await _maybeTrackShortCheckCompletion(
      answeredDomain: domain,
      answers: updated,
    );
  }

  int _shortCheckTargetQuestionCount(_DevelopmentDomainProfile domain) {
    var limit = _selectedPhaseIndex <= 2 ? 1 : 2;
    if (_domainPriorityScore(domain, detailedFlow: false) < 0.45 &&
        _selectedPhaseIndex >= 3) {
      limit = math.min(3, limit + 1);
    }
    return limit;
  }

  Future<void> _maybeTrackShortCheckCompletion({
    required _DevelopmentDomainProfile answeredDomain,
    required Map<String, int> answers,
  }) async {
    if (_isSixMonthDetailedCheck || !_selfCheckQuickMode) return;

    final focusDomain = _focusDomainForSession();
    if (answeredDomain.id != focusDomain.id) return;

    final targetCount = _shortCheckTargetQuestionCount(focusDomain);
    var answeredCount = 0;
    for (var i = 0; i < focusDomain.questions.length; i++) {
      if (answers.containsKey('${focusDomain.id}::$i')) {
        answeredCount++;
      }
    }

    if (answeredCount < targetCount) return;

    await ProductMetricsService.instance.recordShortCheckCompleted(
      childId: _selectedChildId,
      phaseIndex: _selectedPhaseIndex,
      focusDomainId: focusDomain.id,
      answeredCount: answeredCount,
    );
  }

  Future<void> _setMilestoneStatus(
    DevelopmentMilestoneItem item,
    String status,
  ) async {
    final updated = Map<String, _StoredMilestoneProgress>.from(_progressByCode);
    updated[item.code] = _StoredMilestoneProgress(
      status: status,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _progressByCode = updated;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(),
      jsonEncode(updated.map((key, value) => MapEntry(key, value.toJson()))),
    );

    final updatedHistory = <_ProgressEvent>[
      _ProgressEvent(
        code: item.code,
        title: item.title,
        status: status,
        updatedAt: DateTime.now(),
      ),
      ..._history,
    ];
    await prefs.setString(
      _historyKey(),
      jsonEncode(updatedHistory.map((event) => event.toJson()).toList()),
    );

    if (!mounted) return;
    setState(() {
      _history = updatedHistory;
    });
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  Future<void> _storeMonthlyCardMeta(_PhaseSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final selfCheckScores = _selfCheckScoresMap();
    final payload = {
      'generatedAt': now.toIso8601String(),
      'childId': _selectedChildId,
      'phaseIndex': _selectedPhaseIndex,
      'progress': snapshot.progress,
      'completed': snapshot.completed,
      'inProgress': snapshot.inProgress,
      'notStarted': snapshot.notStarted,
      'phaseAgeRange':
          kDevelopmentMilestoneDatabase.phases[_selectedPhaseIndex].ageRange,
      'selfCheckScores': selfCheckScores,
      'selfCheckAverage': _selfCheckAverage(),
      'selfCheckScoringModel': _kSelfCheckScoringModelVersion,
      'selfCheckWeightProfile': _currentWeightProfile(),
    };
    await prefs.setString(
      _monthlyCardMetaKey(),
      jsonEncode(payload),
    );
    final nextReminderAt = now.add(const Duration(days: 24));
    await prefs.setString(
      _reminderSettingsKey(),
      jsonEncode({
        'paused': false,
        'snoozeUntil': nextReminderAt.toIso8601String(),
      }),
    );
    if (!mounted) return;
    setState(() {
      _lastMonthlyCardAt = now;
      _lastMonthlyCardSnapshot = payload;
      _reminderPaused = false;
      _reminderSnoozeUntil = nextReminderAt;
    });
  }

  bool _shouldShowGentleReminder() {
    if (_reminderPaused) return false;
    final now = DateTime.now();
    if (_reminderSnoozeUntil != null && now.isBefore(_reminderSnoozeUntil!)) {
      return false;
    }
    if (_lastReminderShownAt != null &&
        now.difference(_lastReminderShownAt!).inHours < 24) {
      return false;
    }
    if (_lastMonthlyCardAt == null) return true;
    return now.difference(_lastMonthlyCardAt!).inDays >= 32;
  }

  Widget _buildGentleReminderCard(ThemeData theme) {
    _queueReminderExposureStamp();
    final nextDue = _lastMonthlyCardAt?.add(const Duration(days: 32));
    final subtitle = nextDue == null
        ? 'Optionaler Monats-Check-in: kurz, freundlich und ohne Druck.'
        : 'Optionaler Monats-Check-in ab ${_formatDate(nextDue)}. Nur wenn es für euch passt.';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sanfte Erinnerung',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() {
                      _selfCheckQuickMode = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('development_quick_check_enabled')),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded),
                  label: Text(_t('development_start_quick_check')),
                ),
                OutlinedButton(
                  onPressed: () => _snoozeReminder(3),
                  child: Text(_t('development_snooze_3_days')),
                ),
                OutlinedButton(
                  onPressed: () => _snoozeReminder(7),
                  child: Text(_t('development_snooze_1_week')),
                ),
                OutlinedButton(
                  onPressed: () => _snoozeReminder(14),
                  child: Text(_t('development_snooze_2_weeks')),
                ),
                TextButton(
                  onPressed: () => _setReminderPaused(true),
                  child: Text(_t('development_pause_reminders')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _statusRank(String status) {
    switch (status) {
      case 'NOCH_NICHT':
        return 0;
      case 'ANSATZWEISE':
        return 1;
      case 'WEITGEHEND':
        return 2;
      case 'ZUVERLAESSIG':
        return 3;
      default:
        return 0;
    }
  }

  String _currentWeightProfile() {
    final total = kDevelopmentMilestoneDatabase.phases.length;
    if (total <= 1) return 'middle';
    final ratio = _selectedPhaseIndex / (total - 1);
    if (ratio < 0.34) return 'early';
    if (ratio < 0.67) return 'middle';
    return 'late';
  }

  double _domainPhaseWeight(String domainId) {
    final profile = _currentWeightProfile();
    return _kPhaseDomainWeights[profile]?[domainId] ?? 1.0;
  }

  String _weightProfileLabel(String profile) {
    switch (profile) {
      case 'early':
        return _t('development_weight_early');
      case 'late':
        return _t('development_weight_late');
      case 'middle':
      default:
        return _t('development_weight_middle');
    }
  }

  String _weightProfileHint(String profile) {
    switch (profile) {
      case 'early':
        return _t('development_weight_hint_early');
      case 'late':
        return _t('development_weight_hint_late');
      case 'middle':
      default:
        return _t('development_weight_hint_middle');
    }
  }

  int _detailedStageCount() => 3;

  String _detailedStageLabel(int stage) {
    switch (stage) {
      case 0:
        return _t('development_stage_1');
      case 1:
        return _t('development_stage_2');
      default:
        return _t('development_stage_3');
    }
  }

  List<int> _detailedStageQuestionIndices(int totalQuestionCount) {
    final stageCount = _detailedStageCount();
    final stageSize = (totalQuestionCount / stageCount).ceil();
    final start =
        (_detailedCheckStage * stageSize).clamp(0, totalQuestionCount);
    final end = math.min(totalQuestionCount, start + stageSize);
    if (end <= start) return const <int>[];
    return List<int>.generate(end - start, (i) => start + i);
  }

  Widget _buildQuickStartCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_rounded,
                    color: Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('development_quick_start_title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _t('development_hide_hint'),
                  onPressed: _dismissOnboarding,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _t('development_quick_start_steps'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlltagGuidanceCard(ThemeData theme) {
    final focusDomain = _focusDomainForSession();
    final focusScore = _domainPriorityScore(
      focusDomain,
      detailedFlow: _isSixMonthDetailedCheck,
    );
    final topAction = focusDomain.parentActions.isNotEmpty
        ? focusDomain.parentActions.first
        : 'Heute 5 ruhige Minuten für eine gemeinsame Uebung einplanen.';
    final strongDomains = _kParentSelfCheckDomains
        .where((domain) =>
            _domainPriorityScore(
              domain,
              detailedFlow: _isSixMonthDetailedCheck,
            ) >=
            0.75)
        .toList();
    final strongText = strongDomains.isNotEmpty
        ? 'Heute läuft gut: ${strongDomains.first.title}.'
        : 'Heute läuft gut: Ihr bleibt gemeinsam dran.';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dein Wochenkompass',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(strongText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Diese Woche im Blick: ${focusDomain.title} (${_scoreZoneLabel(focusScore)}).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Konkreter 5-Minuten-Schritt: $topAction',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(ThemeData theme, DevelopmentPhase phase) {
    final improvements = _buildTrendItems(phase)
        .where((item) => item.icon == Icons.trending_up_rounded)
        .toList();
    final support = _buildSupportItems(phase);
    final lines = <String>[];

    if (_history.isEmpty) {
      lines.add(
          'Noch keine Verlaufsgeschichte vorhanden. Der erste Eintrag startet eure Entwicklungslinie.');
    } else {
      final thisMonth = DateTime.now().subtract(const Duration(days: 30));
      final recentCount =
          _history.where((event) => event.updatedAt.isAfter(thisMonth)).length;
      lines.add(
          'In den letzten 30 Tagen gab es $recentCount dokumentierte Entwicklungsschritte.');
      if (improvements.isNotEmpty) {
        lines.add('Neu verbessert: ${improvements.first.title}.');
      }
      if (support.isNotEmpty) {
        lines.add('Im Blick behalten: ${support.first.subtitle}.');
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eure Entwicklungsstory',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_tf('development_bullet_line', {'line': line}), style: theme.textTheme.bodyMedium),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transparenz',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Die Grafik zeigt Orientierung aus euren Antworten, keine medizinische Diagnose. Kleine Schwankungen sind normal.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _domainScore(
    _DevelopmentDomainProfile domain, {
    bool? detailedFlow,
  }) {
    final useDetailed = detailedFlow ?? _isSixMonthDetailedCheck;
    final questions = _questionsForDomain(domain, detailed: useDetailed);
    if (questions.isEmpty) return 0;

    var weightedSum = 0.0;
    var maxWeightedSum = 0.0;
    for (var i = 0; i < questions.length; i++) {
      final key = '${domain.id}::$i';
      final answer = (_selfCheckAnswers[key] ?? 0).toDouble();
      final isCoreQuestion = i < domain.questions.length;
      final weight =
          isCoreQuestion ? _kCoreQuestionWeight : _kDetailedQuestionWeight;
      weightedSum += answer * weight;
      maxWeightedSum += 3 * weight;
    }
    if (maxWeightedSum <= 0) return 0;
    return weightedSum / maxWeightedSum;
  }

  double _domainPriorityScore(
    _DevelopmentDomainProfile domain, {
    bool? detailedFlow,
  }) {
    final base = _domainScore(domain, detailedFlow: detailedFlow);
    final phaseWeight = _domainPhaseWeight(domain.id);
    final adjusted = (base * 0.75) + (base * phaseWeight * 0.25);
    return adjusted.clamp(0.0, 1.0).toDouble();
  }

  bool _isSelfCheckComplete(
    _DevelopmentDomainProfile domain, {
    bool? detailedFlow,
  }) {
    final useDetailed = detailedFlow ?? _isSixMonthDetailedCheck;
    final questions = _questionsForDomain(domain, detailed: useDetailed);
    for (var i = 0; i < questions.length; i++) {
      final key = '${domain.id}::$i';
      if (!_selfCheckAnswers.containsKey(key)) {
        return false;
      }
    }
    return true;
  }

  String _scoreZoneLabel(double score) {
    if (score >= 0.75) return 'Stark';
    if (score >= 0.45) return 'Im Aufbau';
    return 'Fokusbereich';
  }

  String _scoreZoneExplanation(double score) {
    if (score >= 0.75) {
      return 'Hier zeigt dein Kind viel Sicherheit. Halte den Alltag stabil und gib gelegentlich neue Impulse.';
    }
    if (score >= 0.45) {
      return 'Dieser Bereich baut sich gerade auf. Kurze Wiederholung und feste Routinen helfen am meisten.';
    }
    return 'Dieser Bereich braucht im Moment mehr Begleitung. Kleine, ruhige Schritte sind jetzt ideal.';
  }

  Map<String, double> _selfCheckScoresMap({
    bool? detailedFlow,
  }) {
    final scores = <String, double>{};
    for (final domain in _kParentSelfCheckDomains) {
      scores[domain.id] = _domainPriorityScore(
        domain,
        detailedFlow: detailedFlow,
      );
    }
    return scores;
  }

  double _selfCheckAverage({
    bool? detailedFlow,
  }) {
    if (_kParentSelfCheckDomains.isEmpty) return 0;
    final sum = _kParentSelfCheckDomains
        .map((domain) =>
            _domainPriorityScore(domain, detailedFlow: detailedFlow))
        .fold<double>(0, (current, value) => current + value);
    return sum / _kParentSelfCheckDomains.length;
  }

  double? _previousSelfCheckScore(String domainId) {
    final snapshot = _lastMonthlyCardSnapshot;
    if (snapshot == null) return null;
    final scoringModel = snapshot['selfCheckScoringModel'] as String?;
    if (scoringModel != null &&
        scoringModel != _kSelfCheckScoringModelVersion) {
      return null;
    }
    final rawScores = snapshot['selfCheckScores'];
    if (rawScores is! Map) return null;
    final value = rawScores[domainId];
    if (value is num) return value.toDouble();
    return null;
  }

  _DevelopmentDomainProfile _focusDomainForSession() {
    if (_activeQuickDomainId != null) {
      final selected = _kParentSelfCheckDomains.where(
        (domain) => domain.id == _activeQuickDomainId,
      );
      if (selected.isNotEmpty) {
        return selected.first;
      }
    }

    final sortedDomains = [..._kParentSelfCheckDomains]..sort(
        (a, b) => _domainPriorityScore(a).compareTo(_domainPriorityScore(b)));
    return sortedDomains.first;
  }

  List<int> _questionIndicesForDomain(
    _DevelopmentDomainProfile domain, {
    required bool quickMode,
    required bool isFocusDomain,
    required int totalQuestionCount,
  }) {
    final ordered = List<int>.generate(totalQuestionCount, (index) => index)
      ..sort((a, b) {
        final aValue = _selfCheckAnswers['${domain.id}::$a'];
        final bValue = _selfCheckAnswers['${domain.id}::$b'];
        final aUnanswered = aValue == null ? 0 : 1;
        final bUnanswered = bValue == null ? 0 : 1;
        if (aUnanswered != bUnanswered) {
          return aUnanswered.compareTo(bUnanswered);
        }
        return (aValue ?? 0).compareTo(bValue ?? 0);
      });
    if (!quickMode) return ordered;
    if (!isFocusDomain) return const <int>[];

    final limit = _shortCheckTargetQuestionCount(domain);
    return ordered.take(limit).toList();
  }

  int _weeklyImprovementCount(DevelopmentPhase phase) {
    final phaseCodes = phase.categories
        .expand((category) => category.items)
        .map((item) => item.code)
        .toSet();
    final events = _history
        .where((event) => phaseCodes.contains(event.code))
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final now = DateTime.now();
    final previousRankByCode = <String, int>{};
    var improvements = 0;

    for (final event in events) {
      final currentRank = _statusRank(event.status);
      final previousRank = previousRankByCode[event.code];
      if (previousRank != null &&
          currentRank > previousRank &&
          now.difference(event.updatedAt).inDays <= 7) {
        improvements += currentRank - previousRank;
      }
      previousRankByCode[event.code] = currentRank;
    }
    return improvements;
  }

  Widget _buildWeeklyWinsCard(
    ThemeData theme,
    DevelopmentPhase phase,
    _PhaseSnapshot snapshot,
  ) {
    final weeklyImprovements = _weeklyImprovementCount(phase);
    final completeSelfCheckDomains = _kParentSelfCheckDomains
        .where((domain) => _isSelfCheckComplete(
              domain,
              detailedFlow: _isSixMonthDetailedCheck,
            ))
        .length;
    final strongDomains = _kParentSelfCheckDomains
        .where((domain) =>
            _domainPriorityScore(
              domain,
              detailedFlow: _isSixMonthDetailedCheck,
            ) >=
            0.75)
        .length;
    final focusDomain = _focusDomainForSession();
    final wins = <String>[];

    if (weeklyImprovements > 0) {
      wins.add(
          'Ihr habt in den letzten 7 Tagen $weeklyImprovements Entwicklungsschritte verbessert.');
    }
    if (snapshot.completed > 0) {
      wins.add(
          '${snapshot.completed} Merkmale wirken aktuell stabil und zuverlässig.');
    }
    if (completeSelfCheckDomains > 0) {
      wins.add(
          'Selbstcheck in $completeSelfCheckDomains/${_kParentSelfCheckDomains.length} Bereichen vollständig ausgefüllt.');
    }
    if (strongDomains > 0) {
      wins.add(
          '$strongDomains Entwicklungsbereiche zeigen bereits ein starkes Profil.');
    }
    if (wins.isEmpty) {
      wins.add(
          'Starker Start: Schon kleine, regelmäßige Schritte machen Entwicklung in kurzer Zeit sichtbar.');
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFFB45309)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Weekly Wins',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Fokus: ${focusDomain.title}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Das lief diese Woche gut. Jeder kleine Schritt stärkt euer Gesamtbild.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ...wins.take(3).map(
                  (win) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $win',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            Text(
              'Nächster Mini-Schritt: 1 kurze Beobachtung heute eintragen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _priorityParentActions() {
    final sortedDomains = [..._kParentSelfCheckDomains]..sort(
        (a, b) => _domainPriorityScore(a).compareTo(_domainPriorityScore(b)));
    final actions = <String>[];
    for (final domain in sortedDomains.take(2)) {
      for (final action in domain.parentActions) {
        actions.add('${domain.title}: $action');
      }
    }
    return actions.take(3).toList();
  }

  List<_TrendItem> _buildTrendItems(DevelopmentPhase phase) {
    final latestByCode = <String, _ProgressEvent>{};
    final previousByCode = <String, _ProgressEvent>{};

    for (final event in _history) {
      latestByCode.putIfAbsent(event.code, () => event);
      previousByCode[event.code] ??= event;
      if (previousByCode[event.code] != event &&
          latestByCode[event.code] != event) {
        previousByCode[event.code] = event;
      }
    }

    final improved = <_TrendItem>[];
    final needsSupport = <_TrendItem>[];

    for (final item in phase.categories.expand((category) => category.items)) {
      final current = _progressByCode[item.code]?.status ?? 'NOCH_NICHT';
      final currentRank = _statusRank(current);
      final previous = previousByCode[item.code]?.status;
      final previousRank = previous == null ? -1 : _statusRank(previous);

      if (previousRank >= 0 && currentRank > previousRank) {
        final delta = currentRank - previousRank;
        improved.add(
          _TrendItem(
            title: item.title,
            subtitle:
                '${kMilestoneStatusLabels[previous] ?? previous} -> ${kMilestoneStatusLabels[current] ?? current}',
            color: const Color(0xFF16A34A),
            icon: Icons.trending_up_rounded,
            delta: delta,
          ),
        );
      } else if (current == 'NOCH_NICHT') {
        needsSupport.add(
          _TrendItem(
            title: item.title,
            subtitle: _t('development_trend_open_now'),
            color: const Color(0xFFF97316),
            icon: Icons.flag_rounded,
            delta: -1,
          ),
        );
      }
    }

    final result = <_TrendItem>[];
    result.addAll(improved.take(2));
    if (result.length < 2) {
      result.addAll(needsSupport.take(2 - result.length));
    }
    if (result.isEmpty) {
      result.add(
        _TrendItem(
            title: _t('development_no_trends_title'),
            subtitle: _t('development_no_trends_subtitle'),
          color: const Color(0xFF0EA5E9),
          icon: Icons.timeline_rounded,
          delta: 0,
        ),
      );
    }
    return result.take(2).toList();
  }

  List<double> _buildWeeklyTrendValues(DevelopmentPhase phase) {
    final phaseCodes = phase.categories
        .expand((category) => category.items)
        .map((item) => item.code)
        .toSet();
    final events = _history
        .where((event) => phaseCodes.contains(event.code))
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final buckets = List<double>.filled(4, 0);
    final previousRankByCode = <String, int>{};
    final now = DateTime.now();

    for (final event in events) {
      final daysAgo = now.difference(event.updatedAt).inDays;
      if (daysAgo < 0 || daysAgo >= 28) {
        continue;
      }
      final weekIndex = 3 - (daysAgo ~/ 7);
      final currentRank = _statusRank(event.status);
      final previousRank = previousRankByCode[event.code] ?? currentRank;
      final delta = (currentRank - previousRank).toDouble();
      buckets[weekIndex] += delta;
      previousRankByCode[event.code] = currentRank;
    }

    var running = 0.0;
    return buckets.map((value) {
      running += value;
      return running;
    }).toList();
  }

  Widget _buildTrendSparkline(ThemeData theme, List<double> values) {
    final weekLabels = List<String>.generate(
      4,
      (index) => _tf('development_week_label', {'week': index + 1}),
    );
    return Container(
      height: 106,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CustomPaint(
                painter: _TrendSparklinePainter(
                  values: values,
                  lineColor: theme.colorScheme.primary,
                  fillColor: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekLabels
                .map((label) => Text(label, style: theme.textTheme.labelSmall))
                .toList(),
          ),
        ],
      ),
    );
  }

  List<_TrendItem> _buildSupportItems(DevelopmentPhase phase) {
    final items = <_TrendItem>[];
    for (final category in phase.categories) {
      final firstOpen = category.items.firstWhere(
        (item) => _statusFor(item.code) == 'NOCH_NICHT',
        orElse: () => category.items.first,
      );
      if (_statusFor(firstOpen.code) == 'NOCH_NICHT') {
        items.add(
          _TrendItem(
            title: category.name,
            subtitle: firstOpen.title,
            color: const Color(0xFFF59E0B),
            icon: Icons.support_agent_rounded,
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        _TrendItem(
          title: _t('development_all_on_track_title'),
          subtitle: _t('development_all_on_track_subtitle'),
          color: const Color(0xFF16A34A),
          icon: Icons.check_circle_rounded,
          delta: 0,
        ),
      );
    }

    return items.take(2).toList();
  }

  Widget _buildTrendCard(
    ThemeData theme,
    String title,
    String subtitle,
    List<_TrendItem> items,
    List<double> trendValues,
  ) {
    final visibleItems = _showOnlyImprovements
        ? items.where((item) => item.icon == Icons.trending_up_rounded).toList()
        : items;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilterChip(
                  selected: _showOnlyImprovements,
                  label: Text(_t('development_only_improved')),
                  onSelected: (selected) {
                    setState(() {
                      _showOnlyImprovements = selected;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildTrendSparkline(theme, trendValues),
            const SizedBox(height: 12),
            ...visibleItems.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: item.color.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.delta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.delta! >= 0
                              ? const Color(0xFF16A34A).withValues(alpha: 0.14)
                              : const Color(0xFFF97316).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.delta! >= 0 ? '+${item.delta}' : '${item.delta}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: item.delta! >= 0
                                ? const Color(0xFF166534)
                                : const Color(0xFF9A3412),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            if (visibleItems.isEmpty)
              Text(
                'Für den gewählten Zeitraum sind noch keine neuen Verbesserungen markiert.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCardPreview(
    ThemeData theme,
    DevelopmentPhase phase,
    _PhaseSnapshot snapshot,
    List<_TrendItem> improvements,
    List<_TrendItem> supportItems,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.auto_graph_rounded,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monatskarte',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedChildLabel()} • ${phase.ageRange}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(snapshot.progress * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Verbessert',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (improvements.isEmpty)
              Text(
                'Noch keine sichtbaren Sprünge gespeichert.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...improvements.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_tf('development_bullet_item', {'title': item.title, 'subtitle': item.subtitle})),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Braucht noch Begleitung',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (supportItems.isEmpty)
              Text(
                'Aktuell keine offenen Bereiche markiert.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...supportItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_tf('development_bullet_item', {'title': item.title, 'subtitle': item.subtitle})),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBellerInspiredRadarCard(ThemeData theme) {
    final isDetailedFlow = _isSixMonthDetailedCheck;
    final weightProfile = _currentWeightProfile();
    final weightedDomains = _kParentSelfCheckDomains
        .map((domain) => MapEntry(domain, _domainPhaseWeight(domain.id)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final strongerWeighted =
        weightedDomains.where((entry) => entry.value > 1.0).toList();
    final lowerWeighted =
        weightedDomains.where((entry) => entry.value < 1.0).toList();
    final values = _kParentSelfCheckDomains
        .map((domain) =>
            _domainPriorityScore(domain, detailedFlow: isDetailedFlow))
        .toList();
    final colors =
        _kParentSelfCheckDomains.map((domain) => domain.color).toList();
    final completeness = _kParentSelfCheckDomains
        .where((domain) => _isSelfCheckComplete(
              domain,
              detailedFlow: isDetailedFlow,
            ))
        .length;
    final actions = _priorityParentActions();
    final weakestDomain = [..._kParentSelfCheckDomains]
      ..sort((a, b) => _domainPriorityScore(
            a,
            detailedFlow: isDetailedFlow,
          ).compareTo(
            _domainPriorityScore(b, detailedFlow: isDetailedFlow),
          ));
    final focusDomain = weakestDomain.first;
    final focusScore = _domainPriorityScore(
      focusDomain,
      detailedFlow: isDetailedFlow,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(Icons.radar_rounded, color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entwicklungsprofil 0-9',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inspiriert von Entwicklungsrastern, elternfreundlich visualisiert.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$completeness/${_kParentSelfCheckDomains.length} vollständig',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF0F9FF),
                    Color(0xFFEFF6FF),
                    Color(0xFFFDF4FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 22,
                    left: 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 260,
                    child: CustomPaint(
                      painter: _BellerModernRadarPainter(
                        values: values,
                        colors: colors,
                        strokeColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (isDetailedFlow)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Detailmodus: Kernfragen werden mit Faktor ${_kCoreQuestionWeight.toStringAsFixed(2)} gewichtet, Zusatzfragen mit ${_kDetailedQuestionWeight.toStringAsFixed(2)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gewichtungsprofil: ${_weightProfileLabel(weightProfile)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weightProfileHint(weightProfile),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (strongerWeighted.isNotEmpty)
                    Text(
                      'Stärker gewichtet: ${strongerWeighted.take(3).map((entry) => entry.key.title).join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF166534),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (lowerWeighted.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Leichter gewichtet: ${lowerWeighted.take(2).map((entry) => entry.key.title).join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kParentSelfCheckDomains.map((domain) {
                final score = _domainPriorityScore(
                  domain,
                  detailedFlow: isDetailedFlow,
                );
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: domain.color.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(domain.icon, size: 16, color: domain.color),
                      const SizedBox(width: 6),
                      Text(
                        '${domain.title}: ${_scoreZoneLabel(score)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: focusDomain.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: focusDomain.color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'So liest du das Profil',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aktueller Fokus: ${focusDomain.title} (${_scoreZoneLabel(focusScore)})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _scoreZoneExplanation(focusScore),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Nächste alltagstaugliche Schritte',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(_tf('development_bullet_line', {'line': action}), style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfCheckMonthlyComparisonCard(ThemeData theme) {
    final hasPrevious = _lastMonthlyCardSnapshot != null;
    final currentAverage = _selfCheckAverage();
    final previousModel = _lastMonthlyCardSnapshot?['selfCheckScoringModel'];
    final isComparable = previousModel == null ||
        previousModel == _kSelfCheckScoringModelVersion;
    final previousAverageRaw =
        isComparable ? (_lastMonthlyCardSnapshot?['selfCheckAverage']) : null;
    final previousAverage =
        previousAverageRaw is num ? previousAverageRaw.toDouble() : null;
    final deltaAverage =
        previousAverage == null ? null : (currentAverage - previousAverage);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selbstcheck Monatsvergleich',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (deltaAverage != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: deltaAverage >= 0
                          ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                          : const Color(0xFFF97316).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${deltaAverage >= 0 ? '+' : ''}${(deltaAverage * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: deltaAverage >= 0
                            ? const Color(0xFF166534)
                            : const Color(0xFF9A3412),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasPrevious
                  ? 'Vergleich zur letzten gespeicherten Monatskarte.'
                  : 'Speichere eine Monatskarte, um ab dem nächsten Monat den Vergleich zu sehen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasPrevious && !isComparable) ...[
              const SizedBox(height: 6),
              Text(
                'Hinweis: Letzte Monatskarte verwendet ein anderes Scoring-Modell. Delta-Werte werden deshalb neutral angezeigt.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ..._kParentSelfCheckDomains.map((domain) {
              final current = _domainPriorityScore(
                domain,
                detailedFlow: _isSixMonthDetailedCheck,
              );
              final previous =
                  isComparable ? _previousSelfCheckScore(domain.id) : null;
              final delta = previous == null ? null : current - previous;
              final widthFactor = current.clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(domain.icon, size: 16, color: domain.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            domain.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${(current * 100).round()}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (delta != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${delta >= 0 ? '+' : ''}${(delta * 100).round()}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: delta >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFF97316),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: widthFactor,
                        minHeight: 8,
                        backgroundColor: domain.color.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation<Color>(domain.color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildParentSelfCheckCard(ThemeData theme) {
    final focusDomain = _focusDomainForSession();
    final isDetailedFlow = _isSixMonthDetailedCheck;
    final visibleDomains = isDetailedFlow
        ? _kParentSelfCheckDomains
        : _selfCheckQuickMode
            ? <_DevelopmentDomainProfile>[focusDomain]
            : _kParentSelfCheckDomains;
    final detailedDue = _isDetailedCheckDue();
    final detailedAnswered = _detailedAnsweredCount();
    final detailedTotal = _detailedTotalQuestionCount();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _t('development_parent_self_check'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: !_isSixMonthDetailedCheck,
                  label: Text(_t('development_monthly_quick_check')),
                  onSelected: (_) {
                    setState(() {
                      _isSixMonthDetailedCheck = false;
                    });
                  },
                ),
                ChoiceChip(
                  selected: _isSixMonthDetailedCheck,
                  label: Text(
                    detailedDue
                        ? _t('development_six_month_detailed_recommended')
                        : _t('development_six_month_detailed'),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _isSixMonthDetailedCheck = true;
                      _selfCheckQuickMode = false;
                    });
                  },
                ),
                if (!_isSixMonthDetailedCheck)
                  FilterChip(
                    selected: _selfCheckQuickMode,
                    label: Text(_t('development_quick_mode')),
                    onSelected: (selected) {
                      setState(() {
                        _selfCheckQuickMode = selected;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isSixMonthDetailedCheck
                    ? _t('development_detailed_check_hint')
                  : _selfCheckQuickMode
                      ? _t('development_quick_mode_hint')
                      : _t('development_full_view_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isSixMonthDetailedCheck) const SizedBox(height: 8),
            if (_isSixMonthDetailedCheck)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.18)),
                ),
                child: Text(
                  _tf('development_detailed_progress', {
                    'answered': detailedAnswered,
                    'total': detailedTotal,
                    'lastCheck': _lastDetailedCheckAt == null ? '' : _tf('development_last_detailed_check', {'date': _formatDate(_lastDetailedCheckAt!)}),
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_isSixMonthDetailedCheck) const SizedBox(height: 8),
            if (_isSixMonthDetailedCheck)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _tf('development_current_stage', {'stage': _detailedStageLabel(_detailedCheckStage), 'total': _detailedStageCount()}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _detailedCheckStage == 0
                        ? null
                        : () {
                            setState(() {
                              _detailedCheckStage -= 1;
                            });
                          },
                    child: Text(_t('development_back')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _detailedCheckStage >= _detailedStageCount() - 1
                        ? null
                        : () {
                            setState(() {
                              _detailedCheckStage += 1;
                            });
                          },
                    child: Text(_t('development_next')),
                  ),
                ],
              ),
            if (_reminderPaused) const SizedBox(height: 8),
            if (_reminderPaused)
              OutlinedButton.icon(
                onPressed: () => _setReminderPaused(false),
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(_t('development_resume_reminders')),
              ),
            if (_isReminderSnoozed()) const SizedBox(height: 8),
            if (_isReminderSnoozed())
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.snooze_rounded,
                        size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tf('development_reminder_paused_until', {'date': _formatDate(_reminderSnoozeUntil!)}),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearReminderSnooze,
                      child: Text(_t('development_activate_now')),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_selfCheckQuickMode && !_isSixMonthDetailedCheck)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kParentSelfCheckDomains.map((domain) {
                  final selected = domain.id == focusDomain.id;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(domain.title),
                    avatar: Icon(domain.icon, size: 16, color: domain.color),
                    onSelected: (_) {
                      setState(() {
                        _activeQuickDomainId = domain.id;
                      });
                    },
                  );
                }).toList(),
              ),
            if (_selfCheckQuickMode && !_isSixMonthDetailedCheck)
              const SizedBox(height: 10),
            ...visibleDomains.map((domain) {
              final score = _domainPriorityScore(
                domain,
                detailedFlow: isDetailedFlow,
              );
              final isFocusDomain = domain.id == focusDomain.id;
              final activeQuestions = _questionsForDomain(
                domain,
                detailed: isDetailedFlow,
              );
              final questionIndices = _questionIndicesForDomain(
                domain,
                quickMode: _selfCheckQuickMode && !isDetailedFlow,
                isFocusDomain: isFocusDomain,
                totalQuestionCount: activeQuestions.length,
              );
              final visibleQuestionIndices = isDetailedFlow
                  ? _detailedStageQuestionIndices(activeQuestions.length)
                  : questionIndices;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: domain.color.withValues(alpha: 0.26)),
                  color: domain.color.withValues(alpha: 0.06),
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
                            color: domain.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(domain.icon, color: domain.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                domain.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                domain.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _scoreZoneLabel(score),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: domain.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: score,
                        minHeight: 7,
                        backgroundColor: domain.color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(domain.color),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_selfCheckQuickMode && !isDetailedFlow)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          isFocusDomain
                              ? _tf('development_focus_today', {'domain': domain.title})
                              : _t('development_domain_hidden'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ...visibleQuestionIndices.map((questionIndex) {
                      final question = activeQuestions[questionIndex];
                      final answerKey = '${domain.id}::$questionIndex';
                      final selected = _selfCheckAnswers[answerKey];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children:
                                  kSelfCheckOptionLabels.entries.map((option) {
                                return ChoiceChip(
                                  selected: selected == option.key,
                                  selectedColor:
                                      domain.color.withValues(alpha: 0.2),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: domain.color.withValues(alpha: 0.4),
                                  ),
                                  label: Text(option.value),
                                  onSelected: (_) => _setSelfCheckAnswer(
                                      domain, questionIndex, option.key),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            if (_isSixMonthDetailedCheck)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed:
                      detailedAnswered == detailedTotal && detailedTotal > 0
                          ? _markDetailedCheckCompleted
                          : null,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: Text(_t('development_complete_detailed_check')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCurrentOverview() async {
    final phase = kDevelopmentMilestoneDatabase.phases[_selectedPhaseIndex];
    final childLabel = _childProfiles
        .firstWhere((profile) => profile.id == _selectedChildId)
        .label;
    final logoBytes = (await rootBundle.load('assets/images/neue logo.png'))
        .buffer
        .asUint8List();
    pw.ThemeData? pdfTheme;
    try {
      final baseFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      pdfTheme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      );
    } catch (e) {
      debugPrint(
          'DevelopmentSchemaFeature._shareCurrentOverview(): PDF font fallback: $e');
      pdfTheme = null;
    }

    final document = pw.Document(
      theme: pdfTheme,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        header: (context) => pw.Container(),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            _t('development_brand'),
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Container(
                  width: 84,
                  height: 84,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Image(pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  _t('development_brand'),
                  style: const pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _t('development_pdf_schema_title'),
                  style: const pw.TextStyle(fontSize: 13),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  _tf('development_pdf_child', {'child': childLabel}),
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  _tf('development_pdf_phase', {'ageRange': phase.ageRange, 'title': phase.title}),
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  _tf('development_progress', {'progress': (_phaseProgress(phase) * 100).round()}),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text(
            _t('development_status_distribution'),
            style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _phaseStatusCounts(phase).entries.map((entry) {
              final label = kMilestoneStatusLabels[entry.key] ?? entry.key;
              return pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: const pw.Border.fromBorderSide(
                    pw.BorderSide(color: pdf.PdfColor.fromInt(0xFFCCCCCC)),
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(_tf('development_label_value', {'label': label, 'value': entry.value})),
              );
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          ...phase.categories.map((category) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  category.name,
                  style: const pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                ...category.items.map((item) {
                  final status =
                      kMilestoneStatusLabels[_statusFor(item.code)] ??
                          _statusFor(item.code);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(_tf('development_pdf_item', {
                      'code': item.code,
                      'title': item.title,
                      'status': status,
                    })),
                  );
                }),
                pw.SizedBox(height: 8),
              ],
            );
          }),
          if (_history.isNotEmpty) ...[
            pw.Text(
              _t('development_latest_changes'),
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ..._history.take(5).map((event) {
              final status =
                  kMilestoneStatusLabels[event.status] ?? event.status;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  _tf('development_pdf_change', {'code': event.code, 'title': event.title, 'status': status, 'date': _formatDate(event.updatedAt)}),
                ),
              );
            }),
          ],
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'entwicklungsschema_${_selectedChildId}_${phase.id}.pdf',
    );
  }

  Future<void> _shareMonthlyCard() async {
    final phase = kDevelopmentMilestoneDatabase.phases[_selectedPhaseIndex];
    final childLabel = _selectedChildLabel();
    final logoBytes = (await rootBundle.load('assets/images/neue logo.png'))
        .buffer
        .asUint8List();
    final snapshot = _phaseSnapshot(phase);
    final improvements = _buildTrendItems(phase);
    final supportItems = _buildSupportItems(phase);
    final currentScores = _selfCheckScoresMap();
    final previousModel = _lastMonthlyCardSnapshot?['selfCheckScoringModel'];
    final isComparable = previousModel == null ||
        previousModel == _kSelfCheckScoringModelVersion;
    final previousScoresRaw = _lastMonthlyCardSnapshot?['selfCheckScores'];
    final previousScores = previousScoresRaw is Map<String, dynamic>
        ? previousScoresRaw
        : <String, dynamic>{};

    pw.ThemeData? pdfTheme;
    try {
      final baseFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      pdfTheme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    } catch (e) {
      debugPrint(
          'DevelopmentSchemaFeature._shareMonthlyCard(): PDF font fallback: $e');
      pdfTheme = null;
    }

    final document = pw.Document(theme: pdfTheme);

    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 54,
                  height: 54,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(16),
                  ),
                  child: pw.Image(pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _t('development_monthly_card'),
                        style: const pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$childLabel • ${phase.ageRange}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: pdf.PdfColor.fromHex('#0EA5E9'),
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Text(
                    '${(snapshot.progress * 100).round()}%',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: pdf.PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: pdf.PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(18),
                border: pw.Border.all(color: pdf.PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _t('development_summary'),
                    style: const pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(_tf('development_progress', {'progress': (snapshot.progress * 100).round()})),
                  pw.Text(_tf('development_strong_count', {'count': snapshot.completed})),
                  pw.Text(_tf('development_building_count', {'count': snapshot.inProgress})),
                  pw.Text(_tf('development_open_count', {'count': snapshot.notStarted})),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              _t('development_improved'),
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...improvements.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(_tf('development_bullet_item', {'title': item.title, 'subtitle': item.subtitle})),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              _t('development_needs_support'),
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...supportItems.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(_tf('development_bullet_item', {'title': item.title, 'subtitle': item.subtitle})),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              _t('development_parent_next_steps'),
              style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(_t('development_next_step_1')),
            pw.Text(_t('development_next_step_2')),
            pw.Text(_t('development_next_step_3')),
          ],
        ),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Eltern-Selbstcheck Monatsvergleich',
              style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(_tf('development_child_age_range', {'child': childLabel, 'ageRange': phase.ageRange})),
            pw.SizedBox(height: 14),
            pw.Text(
              'Vergleich zum letzten gespeicherten Selbstcheck:',
              style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            if (!isComparable) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Hinweis: Letzte Karte nutzt ein anderes Scoring-Modell. Delta-Werte werden ausgeblendet.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 8),
            ..._kParentSelfCheckDomains.map((domain) {
              final current = (currentScores[domain.id] ?? 0) * 100;
              final previousValue =
                  isComparable ? previousScores[domain.id] : null;
              final previous =
                  previousValue is num ? previousValue.toDouble() * 100 : null;
              final delta = previous == null ? null : (current - previous);

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: pdf.PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        domain.title,
                        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                      pw.Text(_tf('development_percent', {'value': current.round()})),
                    if (delta != null) ...[
                      pw.SizedBox(width: 8),
                      pw.Text(
                        '${delta >= 0 ? '+' : ''}${delta.round()}%',
                        style: pw.TextStyle(
                          color: delta >= 0
                              ? pdf.PdfColor.fromHex('#166534')
                              : pdf.PdfColor.fromHex('#9A3412'),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 12),
            pw.Text(
              'Interpretation für Eltern',
              style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
                '• Stark: weiter stabilisieren und neue kleine Impulse geben.'),
            pw.Text(
                '• Im Aufbau: kurze Wiederholung und feste Routinen helfen.'),
            pw.Text(
                '• Fokusbereich: in kleinen Schritten begleiten statt Druck aufzubauen.'),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'monatskarte_${_selectedChildId}_${phase.id}.pdf',
    );
    await _storeMonthlyCardMeta(snapshot);
  }

  Future<void> _shareMonthlyImageCard() async {
    final phase = kDevelopmentMilestoneDatabase.phases[_selectedPhaseIndex];
    final snapshot = _phaseSnapshot(phase);
    final improvements = _buildTrendItems(phase);
    final supportItems = _buildSupportItems(phase);

    final isDark = _monthlyCardDarkStyle;
    final backgroundColor =
        isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor =
        isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    const accentColor = Color(0xFF0EA5E9);

    final recorder = ui.PictureRecorder();
    const width = 1080.0;
    const height = 1350.0;
    final canvas = Canvas(recorder);

    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(64, 72, width - 128, height - 144),
      const Radius.circular(36),
    );
    final cardPaint = Paint()..color = cardColor;
    canvas.drawRRect(cardRect, cardPaint);

    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.24 : 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(100, 118, width - 200, 180),
          const Radius.circular(26)),
      accentPaint,
    );

    void drawText(
      String text,
      double x,
      double y, {
      double size = 32,
      FontWeight weight = FontWeight.w600,
      Color? color,
      double maxWidth = 860,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color ?? textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x, y));
    }

    drawText(_t('development_image_monthly_card'), 120, 146,
        size: 38, weight: FontWeight.w800);
    drawText(_tf('development_child_age_range', {'child': _selectedChildLabel(), 'ageRange': phase.ageRange}), 120, 198,
        size: 24, color: secondaryTextColor);
    drawText(_tf('development_image_progress', {'progress': (snapshot.progress * 100).round()}), 760, 178,
        size: 34, weight: FontWeight.w800, color: accentColor, maxWidth: 220);

    var cursorY = 340.0;
    drawText(_t('development_improved'), 120, cursorY, size: 30, weight: FontWeight.w700);
    cursorY += 52;
    for (final item in improvements.take(3)) {
      drawText(_tf('development_bullet_item', {'title': item.title, 'subtitle': item.subtitle}), 120, cursorY,
          size: 24, weight: FontWeight.w500, color: secondaryTextColor);
      cursorY += 42;
    }

    cursorY += 24;
    drawText(_t('development_needs_support'), 120, cursorY,
        size: 30, weight: FontWeight.w700);
    cursorY += 52;
    for (final item in supportItems.take(3)) {
      drawText(_tf('development_bullet_item', {'title': item.title, 'subtitle': item.subtitle}), 120, cursorY,
          size: 24, weight: FontWeight.w500, color: secondaryTextColor);
      cursorY += 42;
    }

    cursorY += 24;
    drawText(_t('development_next_steps'), 120, cursorY,
        size: 30, weight: FontWeight.w700);
    cursorY += 52;
    drawText(_t('development_image_next_step_1'), 120, cursorY,
        size: 24, weight: FontWeight.w500);
    cursorY += 38;
    drawText(_t('development_image_next_step_2'), 120, cursorY,
        size: 24, weight: FontWeight.w500);
    cursorY += 38;
    drawText(_t('development_image_next_step_3'), 120, cursorY,
        size: 24, weight: FontWeight.w500);

    final image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('development_image_create_failed'))),
      );
      return;
    }

    final bytes = byteData.buffer.asUint8List();
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'monatskarte_${_selectedChildId}_${phase.id}.png',
        ),
      ],
      text: _t('development_image_share_text'),
    );
    await _storeMonthlyCardMeta(snapshot);
  }

  Future<void> _shareMonthlyComparisonCard() async {
    final previous = _lastMonthlyCardSnapshot;
    if (previous == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('development_no_previous_monthly_card'))),
      );
      return;
    }

    final phase = kDevelopmentMilestoneDatabase.phases[_selectedPhaseIndex];
    final current = _phaseSnapshot(phase);
    final previousProgress =
        ((previous['progress'] as num?)?.toDouble() ?? 0) * 100;
    final currentProgress = current.progress * 100;
    final delta = (currentProgress - previousProgress).round();
    final previousDate =
        DateTime.tryParse(previous['generatedAt']?.toString() ?? '')?.toLocal();

    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_t('development_monthly_comparison'),
                style:
                    const pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(_tf('development_child_age_range', {'child': _selectedChildLabel(), 'ageRange': phase.ageRange})),
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: pdf.PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                    pw.Text(_tf('development_previous_progress', {'progress': previousProgress.round(), 'date': previousDate == null ? '' : _tf('development_as_of_date', {'date': _formatDate(previousDate)})})),
                    pw.Text(_tf('development_current_progress', {'progress': currentProgress.round()})),
                    pw.Text(_tf('development_difference', {'value': '${delta >= 0 ? '+' : ''}$delta'})),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(_t('development_current_status')),
            pw.SizedBox(height: 6),
            pw.Text(_tf('development_strong_count', {'count': current.completed})),
            pw.Text(_tf('development_building_count', {'count': current.inProgress})),
            pw.Text(_tf('development_open_count', {'count': current.notStarted})),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'monatsvergleich_${_selectedChildId}_${phase.id}.pdf',
    );
  }

  String _statusFor(String code) {
    return _progressByCode[code]?.status ?? 'NOCH_NICHT';
  }

  double _phaseProgress(DevelopmentPhase phase) {
    final total = phase.categories
        .fold<int>(0, (sum, category) => sum + category.items.length);
    if (total == 0) return 0;

    final completed =
        phase.categories.expand((category) => category.items).where((item) {
      final status = _statusFor(item.code);
      return status == 'WEITGEHEND' || status == 'ZUVERLAESSIG';
    }).length;

    return completed / total;
  }

  Map<String, int> _phaseStatusCounts(DevelopmentPhase phase) {
    final counts = <String, int>{
      'NOCH_NICHT': 0,
      'ANSATZWEISE': 0,
      'WEITGEHEND': 0,
      'ZUVERLAESSIG': 0,
    };

    for (final item in phase.categories.expand((category) => category.items)) {
      counts[_statusFor(item.code)] = (counts[_statusFor(item.code)] ?? 0) + 1;
    }

    return counts;
  }

  _PhaseTheme _phaseThemeForIndex(int index) {
    switch (index) {
      case 0:
        return const _PhaseTheme(
            color: Color(0xFF0EA5E9),
            icon: Icons.baby_changing_station_rounded);
      case 1:
        return const _PhaseTheme(
            color: Color(0xFF16A34A), icon: Icons.child_care_rounded);
      case 2:
        return const _PhaseTheme(
            color: Color(0xFFF97316), icon: Icons.park_rounded);
      case 3:
        return const _PhaseTheme(
            color: Color(0xFF2563EB), icon: Icons.school_rounded);
      case 4:
      default:
        return const _PhaseTheme(
            color: Color(0xFF9333EA), icon: Icons.groups_rounded);
    }
  }

  _PhaseSnapshot _phaseSnapshot(DevelopmentPhase phase) {
    final total = phase.categories
        .fold<int>(0, (sum, category) => sum + category.items.length);
    var completed = 0;
    var inProgress = 0;
    var notStarted = 0;

    for (final item in phase.categories.expand((category) => category.items)) {
      final status = _statusFor(item.code);
      switch (status) {
        case 'WEITGEHEND':
        case 'ZUVERLAESSIG':
          completed++;
          break;
        case 'ANSATZWEISE':
          inProgress++;
          break;
        default:
          notStarted++;
          break;
      }
    }

    return _PhaseSnapshot(
      total: total,
      completed: completed,
      inProgress: inProgress,
      notStarted: notStarted,
    );
  }

  String _selectedChildLabel() {
    return _childProfiles
        .firstWhere((profile) => profile.id == _selectedChildId)
        .label;
  }

  List<String> _phaseHighlights(DevelopmentPhase phase) {
    final strong = <String>[];
    final open = <String>[];

    for (final item in phase.categories.expand((category) => category.items)) {
      final status = _statusFor(item.code);
      if (status == 'WEITGEHEND' || status == 'ZUVERLAESSIG') {
        strong.add(item.title);
      } else if (status == 'NOCH_NICHT') {
        open.add(item.title);
      }
    }

    final highlights = <String>[];
    if (strong.isNotEmpty) {
      highlights.add('Gut sichtbar: ${strong.first}');
    }
    if (open.isNotEmpty) {
      highlights.add('Noch im Blick: ${open.first}');
    }
    if (highlights.isEmpty) {
      highlights.add('Noch keine Bewertung gespeichert.');
    }
    return highlights.take(2).toList();
  }

  Color _statusColor(ThemeData theme, String status) {
    switch (status) {
      case 'ZUVERLAESSIG':
        return const Color(0xFF16A34A);
      case 'WEITGEHEND':
        return const Color(0xFF0EA5E9);
      case 'ANSATZWEISE':
        return const Color(0xFFF59E0B);
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String _categorySummary(DevelopmentCategory category) {
    var strong = 0;
    var open = 0;

    for (final item in category.items) {
      final status = _statusFor(item.code);
      if (status == 'WEITGEHEND' || status == 'ZUVERLAESSIG') {
        strong++;
      } else if (status == 'NOCH_NICHT') {
        open++;
      }
    }

    if (strong > open) {
      return 'läuft gut';
    }
    if (open > 0) {
      return 'braucht Begleitung';
    }
    return 'gerade im Aufbau';
  }

  Widget _buildStatTile(
    ThemeData theme,
    _PhaseTheme phaseTheme,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(
    ThemeData theme,
    _PhaseTheme phaseTheme,
    _PhaseSnapshot snapshot,
  ) {
    final percent = (snapshot.progress * 100).round();
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: snapshot.progress,
            strokeWidth: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Fortschritt',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = kDevelopmentMilestoneDatabase.phases[_selectedPhaseIndex];
    final phaseTheme = _phaseThemeForIndex(_selectedPhaseIndex);
    final snapshot = _phaseSnapshot(phase);
    final childLabel = _selectedChildLabel();
    final highlights = _phaseHighlights(phase);
    final trendItems = _buildTrendItems(phase);
    final supportItems = _buildSupportItems(phase);
    final trendValues = _buildWeeklyTrendValues(phase);
    final ambientStart = phaseTheme.color.withValues(alpha: 0.08);
    final ambientEnd = phaseTheme.color.withValues(alpha: 0.02);

    if (_isLoading) {
      return Card(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_t('development_loading'))),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ambientStart,
            ambientEnd,
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedSection(
            order: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    phaseTheme.color,
                    phaseTheme.color.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: phaseTheme.color.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            phaseTheme.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('development_overview_title'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$childLabel • ${phase.ageRange}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                phase.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildProgressRing(theme, phaseTheme, snapshot),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatTile(
                          theme,
                          phaseTheme,
                          _t('development_strong'),
                          snapshot.completed.toString(),
                          Icons.trending_up_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildStatTile(
                          theme,
                          phaseTheme,
                          _t('development_building'),
                          snapshot.inProgress.toString(),
                          Icons.timelapse_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildStatTile(
                          theme,
                          phaseTheme,
                          _t('development_open'),
                          snapshot.notStarted.toString(),
                          Icons.hourglass_bottom_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: highlights
                          .map(
                            (text) => Chip(
                              label: Text(text),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              side: BorderSide.none,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _shareCurrentOverview,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(_t('development_share_pdf')),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: phaseTheme.color,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _shareMonthlyCard,
                          icon: const Icon(Icons.auto_graph_rounded),
                          label: Text(_t('development_monthly_card')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _history.isEmpty
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(_t('development_history_below')),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.history_rounded),
                          label: Text(_t('development_view_history')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _shareMonthlyImageCard,
                          icon: const Icon(Icons.image_rounded),
                          label: Text(_t('development_share_image')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                        FilterChip(
                          selected: _monthlyCardDarkStyle,
                          label: Text(_t('development_dark_image_card')),
                          onSelected: (selected) {
                            setState(() {
                              _monthlyCardDarkStyle = selected;
                            });
                          },
                          selectedColor: Colors.white.withValues(alpha: 0.22),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.96),
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        OutlinedButton.icon(
                          onPressed: _lastMonthlyCardSnapshot == null
                              ? null
                              : _shareMonthlyComparisonCard,
                          icon: const Icon(Icons.compare_arrows_rounded),
                          label: Text(_t('development_monthly_comparison')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                        if (_lastMonthlyCardAt != null)
                          OutlinedButton.icon(
                            onPressed: _shareMonthlyCard,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                                _tf('development_again_date', {'date': _formatDate(_lastMonthlyCardAt!)})),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.35)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_onboardingDismissed)
            _buildAnimatedSection(order: 1, child: _buildQuickStartCard(theme)),
          if (!_onboardingDismissed) const SizedBox(height: 12),
          _buildAnimatedSection(
            order: 2,
            child: _buildTrendCard(
              theme,
              _t('development_history_overview_title'),
              _t('development_history_overview_subtitle'),
              trendItems,
              trendValues,
            ),
          ),
          const SizedBox(height: 12),
          if (_shouldShowGentleReminder())
            _buildAnimatedSection(
                order: 3, child: _buildGentleReminderCard(theme)),
          if (_shouldShowGentleReminder()) const SizedBox(height: 12),
          _buildAnimatedSection(
            order: 4,
            child: _buildAlltagGuidanceCard(theme),
          ),
          const SizedBox(height: 12),
          _buildAnimatedSection(
            order: 5,
            child: _buildWeeklyWinsCard(
              theme,
              phase,
              snapshot,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnimatedSection(
            order: 6,
            child: _buildStoryCard(theme, phase),
          ),
          const SizedBox(height: 12),
          _buildAnimatedSection(
            order: 7,
            child: _buildMonthlyCardPreview(
              theme,
              phase,
              snapshot,
              trendItems,
              supportItems,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnimatedSection(
              order: 8, child: _buildBellerInspiredRadarCard(theme)),
          const SizedBox(height: 12),
          _buildAnimatedSection(
              order: 9, child: _buildSelfCheckMonthlyComparisonCard(theme)),
          const SizedBox(height: 12),
          _buildAnimatedSection(
              order: 10, child: _buildParentSelfCheckCard(theme)),
          const SizedBox(height: 12),
          _buildAnimatedSection(order: 11, child: _buildTrustCard(theme)),
          const SizedBox(height: 12),
          Text(
            _t('development_choose_child'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _childProfiles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final child = _childProfiles[index];
                final selected = child.id == _selectedChildId;
                return ChoiceChip(
                  selected: selected,
                  label: Text(child.label),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => _selectChild(child.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t('development_choose_age'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kDevelopmentMilestoneDatabase.phases.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final currentPhase =
                    kDevelopmentMilestoneDatabase.phases[index];
                final selected = index == _selectedPhaseIndex;
                return ChoiceChip(
                  selected: selected,
                  label: Text(currentPhase.ageRange),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) {
                    _selectPhase(index);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildAnimatedSection(
            order: 6,
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: phaseTheme.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            phaseTheme.icon,
                            color: phaseTheme.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('development_parent_view_title'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _t('development_parent_view_subtitle'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: _phaseProgress(phase)),
                    const SizedBox(height: 8),
                    Text(
                      _tf('development_progress', {'progress': (_phaseProgress(phase) * 100).round()}),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _phaseStatusCounts(phase).entries.map((entry) {
                        final label =
                            kMilestoneStatusLabels[entry.key] ?? entry.key;
                        return Chip(
                          avatar: CircleAvatar(
                            radius: 8,
                            backgroundColor: _statusColor(theme, entry.key)
                                .withValues(alpha: 0.18),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _statusColor(theme, entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          label: Text(_tf('development_label_value', {'label': label, 'value': entry.value})),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('development_explained_briefly'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('development_explained_briefly_text'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('development_in_practice'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t('development_in_practice_text'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                      ),
                    ),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_tf('development_latest_changes_for_child', {'child': childLabel}),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),
                      ..._history.take(3).map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${event.code} • ${event.title} → ${kMilestoneStatusLabels[event.status] ?? event.status} • ${event.updatedAt.toLocal().day.toString().padLeft(2, '0')}.${event.updatedAt.toLocal().month.toString().padLeft(2, '0')}.${event.updatedAt.toLocal().year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...phase.categories.map((category) {
            final summary = _categorySummary(category);
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: ExpansionTile(
                title: Text(
                  category.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: phaseTheme.color,
                  ),
                ),
                subtitle: Text(_tf('development_category_summary', {'count': category.items.length, 'summary': summary})),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                children: category.items.map((item) {
                  final selectedStatus = _statusFor(item.code);
                  final stored = _progressByCode[item.code];

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin:
                                    const EdgeInsets.only(top: 6, right: 10),
                                decoration: BoxDecoration(
                                  color: _statusColor(theme, selectedStatus),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.code}  ${item.title}',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(item.description),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                kMilestoneStatusLabels.entries.map((entry) {
                              final isSelected = selectedStatus == entry.key;
                              return ChoiceChip(
                                selected: isSelected,
                                label: Text(entry.value),
                                onSelected: (_) =>
                                    _setMilestoneStatus(item, entry.key),
                              );
                            }).toList(),
                          ),
                          if (stored != null &&
                              stored.updatedAt.millisecondsSinceEpoch > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Zuletzt aktualisiert: ${stored.updatedAt.toLocal().day.toString().padLeft(2, '0')}.${stored.updatedAt.toLocal().month.toString().padLeft(2, '0')}.${stored.updatedAt.toLocal().year}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
