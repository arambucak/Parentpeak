import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Familien-Energie-Check — moderner, spielerischer Tages-Puls.
///
/// 5 Stimmungslevel mit Slider statt nur 3 Buttons.
/// Nach dem Check: personalisierter Mini-Tipp basierend auf Stimmung.
/// Wochen-Verlauf als schöne Gradient-Kurve.
class MoodCheckWidget extends StatefulWidget {
  final VoidCallback? onNeedSupport;

  const MoodCheckWidget({super.key, this.onNeedSupport});

  @override
  State<MoodCheckWidget> createState() => _MoodCheckWidgetState();
}

class _MoodCheckWidgetState extends State<MoodCheckWidget>
    with SingleTickerProviderStateMixin {
  static const String _storagePrefix = 'mood.daily.';
  static const String _notePrefix = 'mood.note.';

  int? _todayLevel; // 1-5 (1=schwierig, 5=super)
  List<int?> _weekLevels = List.filled(7, null);
  bool _justRecorded = false;
  String? _todayNote;

  late final AnimationController _celebrateController;

  static const List<_MoodLevel> _levels = [
    _MoodLevel(
      value: 1,
      emoji: '\u{1F62E}\u{200D}\u{1F4A8}',
      labelKey: 'mood_level_1',
      color: Color(0xFFEF4444),
      tipKey: 'mood_tip_1',
    ),
    _MoodLevel(
      value: 2,
      emoji: '\u{1F615}',
      labelKey: 'mood_level_2',
      color: Color(0xFFF97316),
      tipKey: 'mood_tip_2',
    ),
    _MoodLevel(
      value: 3,
      emoji: '\u{1F60C}',
      labelKey: 'mood_level_3',
      color: Color(0xFFF59E0B),
      tipKey: 'mood_tip_3',
    ),
    _MoodLevel(
      value: 4,
      emoji: '\u{1F60A}',
      labelKey: 'mood_level_4',
      color: Color(0xFF22C55E),
      tipKey: 'mood_tip_4',
    ),
    _MoodLevel(
      value: 5,
      emoji: '\u{1F929}',
      labelKey: 'mood_level_5',
      color: Color(0xFF16A34A),
      tipKey: 'mood_tip_5',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadMoodData();
  }

  @override
  void dispose() {
    _celebrateController.dispose();
    super.dispose();
  }

  String _dayKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadMoodData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dayKey(now);
    final todayStr = prefs.getString('$_storagePrefix$today');
    final note = prefs.getString('$_notePrefix$today');

    final weekLevels = <int?>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = _dayKey(day);
      final val = prefs.getString('$_storagePrefix$key');
      weekLevels.add(val != null ? int.tryParse(val) : null);
    }

    if (mounted) {
      setState(() {
        _todayLevel = todayStr != null ? int.tryParse(todayStr) : null;
        _weekLevels = weekLevels;
        _todayNote = note;
      });
    }
  }

  Future<void> _recordMood(int level) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    await prefs.setString('$_storagePrefix$today', level.toString());

    _celebrateController.forward(from: 0);

    if (mounted) {
      setState(() {
        _todayLevel = level;
        _weekLevels[6] = level;
        _justRecorded = true;
      });
    }

    // Bei niedrigem Level → Unterstützung anbieten
    if (level <= 2 && widget.onNeedSupport != null) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) _showSupportOffer();
    }
  }

  void _showSupportOffer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('\u{1F49C}', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 14),
              Text(
                context.tr('mood_support_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('mood_support_message'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onNeedSupport?.call();
                  },
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text(context.tr('mood_support_action')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('common_not_now')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecorded = _todayLevel != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: hasRecorded
            ? LinearGradient(
                colors: [
                  _getColorForLevel(_todayLevel!).withValues(alpha: 0.06),
                  _getColorForLevel(_todayLevel!).withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasRecorded ? null : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasRecorded
              ? _getColorForLevel(_todayLevel!).withValues(alpha: 0.15)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: hasRecorded ? _buildRecordedState(theme) : _buildInputState(theme),
    );
  }

  /// Zustand: Noch nicht eingetragen — Auswahl zeigen
  Widget _buildInputState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Center(
                child: Text('\u{1F3E1}', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('mood_today_title'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 5 Mood-Optionen als Tap-Reihe
        Row(
          children: _levels.map((level) {
            return Expanded(
              child: GestureDetector(
                onTap: () => _recordMood(level.value),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: level.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(level.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(level.labelKey),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Zustand: Bereits eingetragen — Zusammenfassung + Woche
  Widget _buildRecordedState(ThemeData theme) {
    final level = _levels.firstWhere((l) => l.value == _todayLevel,
        orElse: () => _levels[2]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header mit heutigem Ergebnis
        Row(
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                CurvedAnimation(
                  parent: _celebrateController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: Text(level.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.tr('mood_today_prefix'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        context.tr(level.labelKey),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: level.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(level.tipKey),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_justRecorded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 14, color: Color(0xFF16A34A)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Wochen-Verlauf als Bar-Chart
        _buildWeekBars(theme),
      ],
    );
  }

  Widget _buildWeekBars(ThemeData theme) {
    final days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final level = _weekLevels[i];
        final isToday = i == 6;
        final barHeight = level != null ? (level / 5.0) * 32.0 + 4.0 : 4.0;
        final color = level != null
            ? _getColorForLevel(level)
            : theme.colorScheme.outlineVariant;

        return Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: isToday ? 14 : 10,
                height: barHeight,
                decoration: BoxDecoration(
                  color: level != null
                      ? color.withValues(alpha: isToday ? 1.0 : 0.6)
                      : color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: isToday ? Border.all(color: color, width: 1.5) : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                days[(todayWeekday - 7 + i) % 7],
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: isToday
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 1:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF97316);
      case 3:
        return const Color(0xFFF59E0B);
      case 4:
        return const Color(0xFF22C55E);
      case 5:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

class _MoodLevel {
  final int value;
  final String emoji;
  final String labelKey;
  final Color color;
  final String tipKey;

  const _MoodLevel({
    required this.value,
    required this.emoji,
    required this.labelKey,
    required this.color,
    required this.tipKey,
  });
}
