import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Nächstes-Event-Widget — zeigt den nächsten anstehenden Termin.
///
/// Liest aus dem Kalender-Storage. Wenn nichts ansteht,
/// zeigt es eine motivierende Nachricht.
class NextEventWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const NextEventWidget({super.key, this.onTap});

  @override
  State<NextEventWidget> createState() => _NextEventWidgetState();
}

class _NextEventWidgetState extends State<NextEventWidget> {
  String? _eventTitle;
  DateTime? _eventDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNextEvent();
  }

  Future<void> _loadNextEvent() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsRaw = prefs.getString('calendar.events.v1');

    if (eventsRaw != null && eventsRaw.isNotEmpty) {
      try {
        final events = jsonDecode(eventsRaw) as List;
        final now = DateTime.now();

        // Finde das nächste Event in der Zukunft
        DateTime? closest;
        String? closestTitle;

        for (final event in events) {
          if (event is Map<String, dynamic>) {
            final dateStr = event['date']?.toString() ??
                event['startDate']?.toString() ??
                '';
            final title = event['title']?.toString() ?? '';
            final date = DateTime.tryParse(dateStr);
            if (date != null && date.isAfter(now) && title.isNotEmpty) {
              if (closest == null || date.isBefore(closest)) {
                closest = date;
                closestTitle = title;
              }
            }
          }
        }

        if (closest != null && closestTitle != null) {
          if (mounted) {
            setState(() {
              _eventTitle = closestTitle;
              _eventDate = closest;
              _loading = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diff = eventDay.difference(today).inDays;

    if (diff == 0) return 'Heute';
    if (diff == 1) return 'Morgen';
    if (diff < 7) return 'In $diff Tagen';
    return 'Am ${date.day}.${date.month}.';
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    if (date.hour == 0 && date.minute == 0) return '';
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const SizedBox.shrink();

    // Kein Event → motivierender Hinweis
    if (_eventTitle == null || _eventDate == null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('no_events_this_week'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: theme.colorScheme.outline),
            ],
          ),
        ),
      );
    }

    // Event vorhanden
    final relative = _formatRelativeDate(_eventDate!);
    final time = _formatTime(_eventDate!);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_eventDate!.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2563EB),
                      height: 1,
                    ),
                  ),
                  Text(
                    _monthShort(_eventDate!.month),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF2563EB),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventTitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time.isEmpty ? relative : '$relative um $time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez'
    ];
    return months[month - 1];
  }
}
