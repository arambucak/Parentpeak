import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/services/mood_history_service.dart';
import 'package:parentpeak/ui/chat_screen.dart';

class WochenrueckblickScreen extends StatefulWidget {
  const WochenrueckblickScreen({super.key});

  @override
  State<WochenrueckblickScreen> createState() => _WochenrueckblickScreenState();
}

class _WochenrueckblickScreenState extends State<WochenrueckblickScreen> {
  List<MoodEntry> _history = [];
  bool _loading = true;

  static const _dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await MoodHistoryService.loadHistory();
    if (mounted) setState(() { _history = h; _loading = false; });
  }

  // Current ISO week: Monday to Sunday
  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
        7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  MoodEntry? _entryForDay(DateTime day) {
    for (final e in _history) {
      if (e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day) return e;
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _moodColor(String mood) {
    switch (mood) {
      case 'Super': return const Color(0xFF16A34A);
      case 'Gut': return const Color(0xFF2563EB);
      case 'Okay': return const Color(0xFFF97316);
      case 'Mühsam': return const Color(0xFFDC2626);
      case 'Dankbar': return const Color(0xFFEC4899);
      default: return const Color(0xFFE5E7EB);
    }
  }

  String _moodEmoji(String mood) {
    switch (mood) {
      case 'Super': return '😊';
      case 'Gut': return '🙂';
      case 'Okay': return '😐';
      case 'Mühsam': return '😔';
      case 'Dankbar': return '🥰';
      default: return '';
    }
  }

  bool get _wasToughWeek {
    if (_history.isEmpty) return false;
    final tough =
        _history.where((e) => e.mood == 'Mühsam' || e.mood == 'Okay').length;
    return tough > _history.length / 2;
  }

  String _closingMessage() {
    if (_history.isEmpty) {
      return 'Du hast diese Woche noch keine Stimmungen festgehalten. Kein Problem — jeder Tag ist ein Neustart.';
    }
    final tough =
        _history.where((e) => e.mood == 'Mühsam' || e.mood == 'Okay').length;
    final good = _history
        .where((e) =>
            e.mood == 'Super' || e.mood == 'Gut' || e.mood == 'Dankbar')
        .length;
    if (tough > good && tough >= 2) {
      return 'Diese Woche hat dir viel abverlangt. Dass du trotzdem hier bist und in dich hineinhorchst – das ist keine Kleinigkeit. Du bist ein guter Elternteil.';
    } else if (good > tough && good >= 2) {
      return 'Was für eine Woche! Du hast so viel gegeben – und Schönes erlebt. Nimm dieses Gefühl mit in die nächste Woche.';
    } else {
      return 'Jede Woche ist ein Auf und Ab. Du bist durch diese Woche gegangen – mit allem, was dazugehört. Das reicht.';
    }
  }

  String _buildChatPrompt() {
    final moods = _history.map((e) => e.mood).join(', ');
    final moments = _history
        .where((e) => e.moment != null && e.moment!.isNotEmpty)
        .map((e) => '"${e.moment}"')
        .join(', ');
    if (_wasToughWeek) {
      return 'Ich möchte über meine Woche als Elternteil sprechen. Es war eine herausfordernde Woche. '
          'Meine Stimmungen: $moods.${moments.isNotEmpty ? ' Schöne Momente hatte ich trotzdem: $moments.' : ''} '
          'Kannst du mir helfen, das einzuordnen?';
    }
    return 'Ich möchte kurz über meine Woche als Elternteil reflektieren. Meine Stimmungen: $moods.'
        '${moments.isNotEmpty ? ' Besondere Momente: $moments.' : ''} Was siehst du darin?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _weekDays;
    final today = DateTime.now();
    final entriesThisWeek =
        days.where((d) => _entryForDay(d) != null).length;
    final moments = _history
        .where((e) => e.moment != null && e.moment!.isNotEmpty)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Deine Woche',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _weekStrip(theme, days, today, entriesThisWeek),
                  const SizedBox(height: 20),
                  _closingCard(theme),
                  if (moments.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(
                      '✨ Deine Momente diese Woche',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    ...moments.map((e) => _momentCard(theme, e)),
                  ],
                  const SizedBox(height: 32),
                  _chatButton(theme),
                ],
              ),
            ),
    );
  }

  Widget _weekStrip(ThemeData theme, List<DateTime> days, DateTime today,
      int entriesCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = days[i];
              final entry = _entryForDay(day);
              final color = entry != null
                  ? _moodColor(entry.mood)
                  : const Color(0xFFD1D5DB);
              final emoji = entry != null ? _moodEmoji(entry.mood) : '';
              final isToday = _isSameDay(day, today);
              final isFuture = day.isAfter(today);
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      _dayNames[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isToday
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: entry != null
                            ? color.withValues(alpha: 0.15)
                            : isFuture
                                ? Colors.transparent
                                : const Color(0xFFF3F4F6),
                        border: Border.all(
                          color: entry != null
                              ? color
                              : isFuture
                                  ? const Color(0xFFE5E7EB)
                                  : const Color(0xFFD1D5DB),
                          width: isToday ? 2.0 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: emoji.isNotEmpty
                            ? Text(emoji,
                                style: const TextStyle(fontSize: 16))
                            : isFuture
                                ? const SizedBox.shrink()
                                : Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isToday
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$entriesCount von 7 Tagen',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closingCard(ThemeData theme) {
    final tough = _wasToughWeek;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tough ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              tough ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tough ? '💛' : '💚',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _closingMessage(),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: tough
                    ? const Color(0xFF92400E)
                    : const Color(0xFF14532D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _momentCard(ThemeData theme, MoodEntry entry) {
    final color = _moodColor(entry.mood);
    final label = DateFormat('EEEE, d. MMM', 'de').format(entry.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(_moodEmoji(entry.mood),
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(entry.mood,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ]),
                    if (entry.moment != null &&
                        entry.moment!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '"${entry.moment}"',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                            height: 1.45),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _chatButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(initialMessage: _buildChatPrompt()),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              'Mit KI über meine Woche sprechen',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
