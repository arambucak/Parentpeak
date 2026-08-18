import 'package:flutter/material.dart';

/// Entwicklungs-Verlauf-Chart — Balkenvergleich aktuell vs. letzter Check.
///
/// Zeigt pro Domain: Farbiger Balken + Prozentwert + Trend-Icon + empathischer Satz.
/// Farben: 🟢 wächst (grün) | ⚪ stabil (grau) | 🟠 pausiert (orange)
class DevelopmentProgressChart extends StatelessWidget {
  const DevelopmentProgressChart({
    super.key,
    required this.currentScores,
    this.previousScores,
    this.previousDate,
  });

  /// Aktuelle Scores pro Domain (z.B. {'motorik': 0.8, 'sprache': 0.6})
  final Map<String, double> currentScores;

  /// Vorherige Scores (null = erster Check)
  final Map<String, double>? previousScores;

  /// Datum des vorherigen Checks
  final DateTime? previousDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrevious = previousScores != null && previousScores!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entwicklungs-Verlauf',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (hasPrevious && previousDate != null)
                    Text(
                      'Vergleich mit ${_formatDate(previousDate!)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Domain bars
        ...currentScores.entries.map((entry) {
          final domain = entry.key;
          final current = entry.value;
          final previous = previousScores?[domain];
          return _DomainBar(
            domain: domain,
            label: _domainLabel(domain),
            currentScore: current,
            previousScore: previous,
          );
        }),

        // Empathic footer
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
          ),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kinder entwickeln sich in Wellen. Jede Pause ist Vorbereitung auf den nächsten Sprung.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF166534),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ]),
        ),
      ],
    );
  }

  String _domainLabel(String id) {
    const labels = {
      'motorik': 'Motorik',
      'sprache': 'Sprache',
      'sozial': 'Sozial-emotional',
      'kognition': 'Kognition',
      'autonomie': 'Autonomie',
    };
    return labels[id] ?? id;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _DomainBar extends StatelessWidget {
  const _DomainBar({
    required this.domain,
    required this.label,
    required this.currentScore,
    this.previousScore,
  });

  final String domain;
  final String label;
  final double currentScore;
  final double? previousScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (currentScore * 100).round();
    final trend = _getTrend();
    final trendColor = _trendColor(trend);
    final trendIcon = _trendIcon(trend);
    final empathicText = _empathicText(trend);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + trend
          Row(children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(trendIcon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text('$percent%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: trendColor,
                )),
            if (previousScore != null) ...[
              const SizedBox(width: 6),
              Text(
                _diffText(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),

          // Bar
          Stack(children: [
            // Background
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Previous (if exists)
            if (previousScore != null)
              FractionallySizedBox(
                widthFactor: previousScore!.clamp(0, 1),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // Current
            FractionallySizedBox(
              widthFactor: currentScore.clamp(0, 1),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: trendColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),

          // Empathic text
          Text(empathicText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              )),
        ],
      ),
    );
  }

  _Trend _getTrend() {
    if (previousScore == null) return _Trend.first;
    final diff = currentScore - previousScore!;
    if (diff > 0.1) return _Trend.growing;
    if (diff < -0.1) return _Trend.pausing;
    return _Trend.stable;
  }

  Color _trendColor(_Trend trend) {
    switch (trend) {
      case _Trend.growing:
        return const Color(0xFF16A34A);
      case _Trend.stable:
        return const Color(0xFF6B7280);
      case _Trend.pausing:
        return const Color(0xFFF59E0B);
      case _Trend.first:
        return const Color(0xFF8B5CF6);
    }
  }

  String _trendIcon(_Trend trend) {
    switch (trend) {
      case _Trend.growing:
        return '↗️';
      case _Trend.stable:
        return '→';
      case _Trend.pausing:
        return '↘️';
      case _Trend.first:
        return '✨';
    }
  }

  String _empathicText(_Trend trend) {
    switch (trend) {
      case _Trend.growing:
        return 'Wächst gerade stark — toll!';
      case _Trend.stable:
        return 'Stabil seit dem letzten Check.';
      case _Trend.pausing:
        return 'Dein Kind pausiert hier gerade — das ist normal.';
      case _Trend.first:
        return 'Erster Check — beim nächsten Mal siehst du den Verlauf.';
    }
  }

  String _diffText() {
    if (previousScore == null) return '';
    final diff = ((currentScore - previousScore!) * 100).round();
    if (diff > 0) return '+$diff%';
    if (diff < 0) return '$diff%';
    return '±0';
  }
}

enum _Trend { growing, stable, pausing, first }
