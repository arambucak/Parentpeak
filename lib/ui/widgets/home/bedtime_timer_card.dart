import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/notification_service.dart';

/// Schlaf-Routine-Timer mit Phasen-Feedback.
///
/// Nach jeder Phase: Feedback-Frage ("Geschafft?" / "Noch nicht").
/// Bei "Noch nicht": Sanfte Hilfe, Tipps oder Weiterleitung zum KI-Chat.
/// Benachrichtigung bei Phasenwechsel auch wenn App im Hintergrund.
class BedtimeTimerCard extends StatefulWidget {
  final VoidCallback? onOpenChat;

  const BedtimeTimerCard({super.key, this.onOpenChat});

  @override
  State<BedtimeTimerCard> createState() => _BedtimeTimerCardState();
}

class _BedtimeTimerCardState extends State<BedtimeTimerCard>
    with SingleTickerProviderStateMixin {
  bool _isRunning = false;
  bool _showExplanation = false;
  bool _showFeedback = false;
  int _feedbackStepIndex = -1;
  bool _showHelpOptions = false;
  int _remainingSeconds = 0;
  final int _totalSeconds = 30 * 60;
  Timer? _timer;
  int _completedCount = 0;
  int _lastNotifiedStepIndex = -1;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const List<_RoutineStep> _steps = [
    _RoutineStep(
      minutesBefore: 30,
      title: 'Zur Ruhe kommen',
      subtitle: 'Spielzeug wegräumen, Licht dimmen',
      emoji: '\u{1F31C}',
      feedbackPositive: 'Super, ihr seid zur Ruhe gekommen!',
      feedbackQuestion: 'Seid ihr zur Ruhe gekommen?',
      helpTips: [
        'Versuche das Licht noch weiter zu dimmen',
        'Setzt euch zusammen hin und atmet 3x tief ein',
        'Leise Musik oder ein Hörspiel kann helfen',
      ],
    ),
    _RoutineStep(
      minutesBefore: 20,
      title: 'Bettfertig machen',
      subtitle: 'Zähne putzen, Schlafanzug anziehen',
      emoji: '\u{1FAA5}',
      feedbackPositive: 'Toll, bettfertig!',
      feedbackQuestion: 'Ist euer Kind bettfertig?',
      helpTips: [
        'Macht ein Spiel daraus: "Wer ist schneller umgezogen?"',
        'Singt zusammen ein kurzes Zahnputzlied',
        'Lass dein Kind den Schlafanzug selbst wählen',
      ],
    ),
    _RoutineStep(
      minutesBefore: 10,
      title: 'Gute-Nacht-Geschichte',
      subtitle: 'Ein Buch oder eine kurze Geschichte',
      emoji: '\u{1F4D6}',
      feedbackPositive: 'Schöne Geschichte!',
      feedbackQuestion: 'Habt ihr eine Geschichte gelesen?',
      helpTips: [
        'Auch eine ganz kurze Geschichte reicht (2-3 Seiten)',
        'Lass dein Kind eine eigene Geschichte erfinden',
        'Erzähle von deinem Tag — Kinder lieben das',
      ],
    ),
    _RoutineStep(
      minutesBefore: 5,
      title: 'Kuscheln & Einschlafen',
      subtitle: 'Letzte Umarmung, Licht aus',
      emoji: '\u{1F49C}',
      feedbackPositive: 'Gute Nacht! Ihr habt das toll gemacht.',
      feedbackQuestion: 'Ist euer Kind beim Einschlafen?',
      helpTips: [
        'Streichle sanft über den Rücken mit gleichem Rhythmus',
        'Flüstere: "Ich bin da, du bist sicher"',
        'Bleib noch 2 Minuten still sitzen — Präsenz reicht',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadCompletionCount();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletionCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _completedCount = prefs.getInt('bedtime.completed_count') ?? 0;
      });
    }
  }

  Future<void> _incrementCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('bedtime.completed_count') ?? 0) + 1;
    await prefs.setInt('bedtime.completed_count', count);
    if (mounted) setState(() => _completedCount = count);
  }

  int get _currentStepIndex {
    final minutesLeft = _remainingSeconds ~/ 60;
    for (int i = 0; i < _steps.length; i++) {
      final nextThreshold =
          i < _steps.length - 1 ? _steps[i + 1].minutesBefore : 0;
      if (minutesLeft > nextThreshold &&
          minutesLeft <= _steps[i].minutesBefore) {
        return i;
      }
    }
    return _steps.length - 1;
  }

  void _startTimer() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRunning = true;
      _showExplanation = false;
      _showFeedback = false;
      _showHelpOptions = false;
      _remainingSeconds = _totalSeconds;
      _lastNotifiedStepIndex = -1;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _onPhaseComplete(_steps.length - 1);
        return;
      }
      if (mounted) {
        final prevStep = _lastNotifiedStepIndex;
        final currentIdx = _currentStepIndex;

        setState(() => _remainingSeconds--);

        // Phasenwechsel erkannt → Feedback für vorherige Phase zeigen
        if (currentIdx > prevStep && prevStep >= 0 && !_showFeedback) {
          _onPhaseComplete(prevStep);
        }
        _lastNotifiedStepIndex = currentIdx;
      }
    });
    // Starte mit Phase 0
    _lastNotifiedStepIndex = 0;
  }

  void _onPhaseComplete(int stepIndex) {
    _timer?.cancel();
    HapticFeedback.mediumImpact();

    // Sende lokale Benachrichtigung
    _sendPhaseNotification(stepIndex);

    if (mounted) {
      setState(() {
        _showFeedback = true;
        _feedbackStepIndex = stepIndex;
        _showHelpOptions = false;
      });
    }
  }

  Future<void> _sendPhaseNotification(int stepIndex) async {
    final step = _steps[stepIndex];
    try {
      await NotificationService.instance.showLocalNotification(
        title: 'Abendroutine: ${step.title}',
        body: step.feedbackQuestion,
      );
    } catch (_) {
      // Notification-Fehler nicht kritisch
    }
  }

  void _onFeedbackPositive() {
    HapticFeedback.lightImpact();
    final isLastStep = _feedbackStepIndex >= _steps.length - 1;

    if (isLastStep) {
      _completeRoutine();
    } else {
      // Weiter zum nächsten Schritt
      setState(() {
        _showFeedback = false;
        _showHelpOptions = false;
      });
      _resumeTimer();
    }
  }

  void _onFeedbackNegative() {
    HapticFeedback.lightImpact();
    setState(() => _showHelpOptions = true);
  }

  void _resumeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _onPhaseComplete(_steps.length - 1);
        return;
      }
      if (mounted) {
        final prevStep = _lastNotifiedStepIndex;
        final currentIdx = _currentStepIndex;

        setState(() => _remainingSeconds--);

        if (currentIdx > prevStep && prevStep >= 0 && !_showFeedback) {
          _onPhaseComplete(prevStep);
        }
        _lastNotifiedStepIndex = currentIdx;
      }
    });
  }

  void _continueAfterHelp() {
    HapticFeedback.lightImpact();
    final isLastStep = _feedbackStepIndex >= _steps.length - 1;
    if (isLastStep) {
      _completeRoutine();
    } else {
      setState(() {
        _showFeedback = false;
        _showHelpOptions = false;
      });
      _resumeTimer();
    }
  }

  void _completeRoutine() {
    _timer?.cancel();
    _incrementCompletion();
    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _showFeedback = false;
        _remainingSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('\u{2728}', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(child: Text('Gute Nacht! Routine geschafft.')),
            ],
          ),
          backgroundColor: const Color(0xFF312E81),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _showFeedback = false;
        _showHelpOptions = false;
        _remainingSeconds = 0;
      });
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isEvening = now.hour >= 17 || now.hour < 5;

    if (!isEvening && !_isRunning && !_showFeedback) {
      return const SizedBox.shrink();
    }

    if (_showFeedback) {
      return _buildFeedbackCard(theme);
    }

    if (_isRunning) {
      return _buildActiveTimer(theme);
    }

    if (_showExplanation) {
      return _buildExplanation(theme);
    }

    return _buildInvitation(theme);
  }

  // ─── Einladung ──────────────────────────────────────────────────────────────

  Widget _buildInvitation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.06),
            const Color(0xFF312E81).withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF312E81).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF312E81), Color(0xFF4338CA)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('\u{1F31D}', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Abendroutine',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'In 30 Min entspannt ins Bett',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_completedCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_completedCount}x',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: _steps.map((step) {
              return Expanded(
                child: Column(
                  children: [
                    Text(step.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      '${step.minutesBefore}m',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _startTimer,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF312E81),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Starten'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() => _showExplanation = true),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: const Color(0xFF312E81).withValues(alpha: 0.2),
                  ),
                ),
                child: const Text('Wie geht das?'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Feedback-Karte nach Phase ──────────────────────────────────────────────

  Widget _buildFeedbackCard(ThemeData theme) {
    final step = _steps[_feedbackStepIndex];
    final isLastStep = _feedbackStepIndex >= _steps.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF312E81).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phase-Emoji und Frage
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF312E81), Color(0xFF4338CA)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(step.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.feedbackQuestion,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Phase "${step.title}" ist abgeschlossen',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (!_showHelpOptions) ...[
            // Zwei Feedback-Buttons
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _onFeedbackPositive,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(isLastStep
                    ? 'Ja, geschafft! Gute Nacht'
                    : 'Ja, geschafft! Weiter'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _onFeedbackNegative,
                icon: Icon(Icons.support_rounded,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                label: const Text('Noch nicht — ich brauche Hilfe'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ],

          // Hilfe-Optionen wenn "Noch nicht" gewählt
          if (_showHelpOptions) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF312E81).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('\u{1F4A1}', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        'Das kannst du jetzt tun:',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tipps für diese Phase
                  ...step.helpTips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF312E81),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tip,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Aktions-Buttons nach Hilfe
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _continueAfterHelp,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF312E81),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isLastStep ? 'Routine beenden' : 'Weiter'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: widget.onOpenChat,
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('KI fragen'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Erklärung ──────────────────────────────────────────────────────────────

  Widget _buildExplanation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF312E81).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'So funktioniert es',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showExplanation = false),
                child: Icon(Icons.close_rounded,
                    size: 20, color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isLast = idx == _steps.length - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF312E81).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(step.emoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 20,
                            color:
                                const Color(0xFF312E81).withValues(alpha: 0.1),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              step.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${step.minutesBefore} Min',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF312E81),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF312E81).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{2764}\u{FE0F}', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nach jedem Schritt fragt die App kurz: "Geschafft?" '
                    'Falls nicht, bekommst du sofort sanfte Tipps oder kannst die KI um Rat fragen.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _startTimer,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF312E81),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Jetzt ausprobieren'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Aktiver Timer ──────────────────────────────────────────────────────────

  Widget _buildActiveTimer(ThemeData theme) {
    final stepIdx = _currentStepIndex;
    final step = _steps[stepIdx];
    final progress = 1 - (_remainingSeconds / _totalSeconds);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.1),
            const Color(0xFF312E81).withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF312E81).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Aktueller Schritt
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF4338CA)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(step.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    _formatTime(_remainingSeconds),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF312E81),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'verbleibend',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF312E81).withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF312E81)),
            ),
          ),
          const SizedBox(height: 14),
          // Stepper
          Row(
            children: _steps.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final isActive = idx == stepIdx;
              final isDone = idx < stepIdx;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 28 : 22,
                      height: isActive ? 28 : 22,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                            : isActive
                                ? const Color(0xFF312E81)
                                    .withValues(alpha: 0.12)
                                : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: isActive
                            ? Border.all(
                                color: const Color(0xFF312E81), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                size: 12, color: Color(0xFF16A34A))
                            : Text(s.emoji,
                                style: TextStyle(fontSize: isActive ? 14 : 11)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Stop
          GestureDetector(
            onTap: _stopTimer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded,
                      size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Text(
                    'Beenden',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineStep {
  final int minutesBefore;
  final String title;
  final String subtitle;
  final String emoji;
  final String feedbackPositive;
  final String feedbackQuestion;
  final List<String> helpTips;

  const _RoutineStep({
    required this.minutesBefore,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.feedbackPositive,
    required this.feedbackQuestion,
    required this.helpTips,
  });
}
