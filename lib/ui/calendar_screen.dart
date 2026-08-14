import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/calendar_backend_service.dart';
import 'package:parentpeak/logic/notification_service.dart';
import 'package:parentpeak/widgets/language_change_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with LanguageChangeMixin<CalendarScreen> {
  final List<_CalendarEvent> _events = [];
  final CalendarBackendService _calendarService =
      BackendServiceFactory.createCalendarService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _quickAddController = TextEditingController();
  String? _syncError;
  String _filterPerson = 'Alle';
  static const int _smartReminderValue = -1;
  final List<int> _reminderOptions = [_smartReminderValue, 0, 10, 30, 60];
  final List<String> _recurrenceOptions = [
    'Einmalig',
    'Täglich',
    'Wöchentlich',
    'Monatlich',
    'Jährlich',
  ];
  final List<String> _recurrenceEndOptions = [
    'Kein Ende',
    '5 Termine',
    '10 Termine',
    'Datum wählen'
  ];
  final String _recurrenceEndMode = 'Kein Ende';
  List<String> _customPersons = [];
  DateTime? _recurrenceEndDate;
  final int _recurrenceCount = 5;

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  // Child colors cycle — index matches child position in profile
  static const List<Color> _childColorPalette = [
    Color(0xFFFF6B6B),
    Color(0xFF6C63FF),
    Color(0xFFFF9F43),
    Color(0xFF48DBFB),
    Color(0xFFFF6B9D),
  ];

  Map<String, Color> _personColors = {
    'Eltern': const Color(0xFF4CAF50),
    'Kindergarten': const Color(0xFFFFC107),
    '\u{1F382} Geburtstag': const Color(0xFFE91E63),
  };

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay =
        DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    _loadCustomPersons();
    _loadPersonColors();
    _loadEvents();
  }

  static const String _customPersonsKey = 'calendar_custom_persons';

  Future<void> _loadCustomPersons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customPersonsKey);
    if (raw != null && mounted) {
      setState(() {
        _customPersons = List<String>.from(jsonDecode(raw) as List);
      });
    }
  }

  Future<void> _saveCustomPersons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPersonsKey, jsonEncode(_customPersons));
  }

  Future<void> _loadPersonColors() async {
    final profile = await FamilyMatchProfile.load();
    if (!mounted) return;
    final children = profile?.children ?? [];
    final Map<String, Color> colors = {
      'Eltern': const Color(0xFF4CAF50),
    };
    for (var i = 0; i < children.length; i++) {
      final name = children[i].name.trim();
      if (name.isNotEmpty) {
        colors[name] = _childColorPalette[i % _childColorPalette.length];
      }
    }
    // Merge custom persons with distinct colors
    for (var i = 0; i < _customPersons.length; i++) {
      final name = _customPersons[i];
      if (!colors.containsKey(name)) {
        colors[name] = _childColorPalette[
            (children.length + i) % _childColorPalette.length];
      }
    }
    colors['Kindergarten'] = const Color(0xFFFFC107);
    colors['\u{1F382} Geburtstag'] = const Color(0xFFE91E63);
    setState(() => _personColors = colors);
  }

  Future<void> _showAddPersonDialog(
      {required void Function(String) onAdded}) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Person hinzufügen'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'z.B. Lena, Oma, Sportverein',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    if (_personColors.containsKey(name)) {
      onAdded(name);
      return;
    }
    setState(() {
      _customPersons.add(name);
      final idx = _personColors.length - 1; // before Kindergarten
      _personColors[name] = _childColorPalette[idx % _childColorPalette.length];
    });
    await _saveCustomPersons();
    onAdded(name);
  }

  Future<void> _loadEvents() async {
    final saved = await _calendarService.fetchEvents();
    final syncError = _calendarService.lastSyncError;
    if (!mounted) return;

    // Gelöschte IDs laden (damit Backend-Events die lokal gelöscht wurden nicht zurückkommen)
    final prefs = await SharedPreferences.getInstance();
    final deletedIds =
        (prefs.getStringList('calendar.deleted_ids') ?? []).toSet();

    if (saved.isEmpty) {
      // Versuche lokale Events zu laden
      final localRaw = prefs.getString('calendar.events');
      if (localRaw != null && localRaw.isNotEmpty) {
        try {
          final localEvents = (jsonDecode(localRaw) as List)
              .map((e) => _CalendarEvent.fromJson(e as Map<String, dynamic>))
              .where((e) => !deletedIds.contains(e.id))
              .toList();
          if (mounted) {
            setState(() {
              _events
                ..clear()
                ..addAll(localEvents);
              _syncError = syncError;
            });
          }
        } catch (_) {}
      } else {
        if (mounted)
          setState(() {
            _events.clear();
            _syncError = syncError;
          });
      }
      await _scheduleRemindersFor(_events);
      return;
    }

    setState(() {
      _events
        ..clear()
        ..addAll(saved
            .map(_CalendarEvent.fromJson)
            .where((e) => !deletedIds.contains(e.id)));
      _syncError = syncError;
    });

    // Lokal auch aktualisieren
    await _persistEvents();
    await _scheduleRemindersFor(_events);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  List<_CalendarEvent> _expandRecurrence(_CalendarEvent base) {
    final List<_CalendarEvent> list = [base];
    Duration step;
    int occurrences = base.recurrenceCount ?? 3; // default fallback
    switch (base.recurrence) {
      case 'Täglich':
        step = const Duration(days: 1);
        break;
      case 'Wöchentlich':
        step = const Duration(days: 7);
        break;
      case 'Monatlich':
        // approximate by 30 days for demo
        step = const Duration(days: 30);
        break;
      case 'Jährlich':
        step = const Duration(days: 365);
        break;
      default:
        return list;
    }

    int added = 0;
    DateTime nextStart = base.start.add(step);
    DateTime nextEnd = base.end.add(step);

    bool useCount = base.recurrenceEndMode.contains('Termine');
    bool useDate = base.recurrenceEndMode == 'Datum wählen';
    final endDate = base.recurrenceEndDate;

    while (true) {
      if (useCount && added >= (occurrences - 1)) break;
      if (useDate && endDate != null && nextStart.isAfter(endDate)) break;
      list.add(
        base.copyWith(
          id: '${base.id}_$added',
          start: nextStart,
          end: nextEnd,
        ),
      );
      added++;
      nextStart = nextStart.add(step);
      nextEnd = nextEnd.add(step);

      // falls weder Datum noch Count explizit: wenige Events erzeugen
      if (!useCount && !useDate && added >= 4) break;
    }
    return list;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<_CalendarEvent> get _eventsForSelectedDay {
    return _events
        .where((e) => _isSameDay(e.start, _selectedDay))
        .where((e) => _filterPerson == 'Alle' || e.person == _filterPerson)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  int _countEventsForDay(DateTime day) {
    return _events
        .where((e) => _isSameDay(e.start, day))
        .where((e) => _filterPerson == 'Alle' || e.person == _filterPerson)
        .length;
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
      _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = DateTime(day.year, day.month, 1);
    });
  }

  // Quick templates — person will be replaced by first real child or 'Eltern'
  static const List<Map<String, String>> _eventTemplates = [
    {'emoji': '\u{1F3E5}', 'label': 'Kinderarzt', 'person': 'Eltern'},
    {'emoji': '\u{1F9B7}', 'label': 'Zahnarzt', 'person': 'Eltern'},
    {'emoji': '\u{1F4DA}', 'label': 'Elternsprechtag', 'person': 'Eltern'},
    {'emoji': '\u{1F382}', 'label': 'Geburtstag', 'person': 'Eltern'},
    {'emoji': '\u{1F3CA}', 'label': 'Schwimmen', 'person': 'Kind'},
    {'emoji': '\u{1F393}', 'label': 'Kita-Fest', 'person': 'Kindergarten'},
    {'emoji': '\u{1F3C3}', 'label': 'Sport', 'person': 'Kind'},
    {'emoji': '\u{1F489}', 'label': 'Impfung', 'person': 'Eltern'},
  ];

  /// Returns first real child name, or 'Eltern' as fallback.
  String _resolveTemplatePerson(String placeholder) {
    if (placeholder != 'Kind') return placeholder;
    final firstChild = _personColors.keys.firstWhere(
      (k) => k != 'Eltern' && k != 'Kindergarten',
      orElse: () => 'Eltern',
    );
    return firstChild;
  }

  Future<void> _deleteEvent(_CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Termin löschen?'),
        content: Text('„${event.title}" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _events.removeWhere((e) => e.id == event.id);
      });
      await _persistEvents();
      // Auf die "gelöscht" Liste setzen (damit Backend-Events nicht zurückkommen)
      final prefs = await SharedPreferences.getInstance();
      final deletedIds = prefs.getStringList('calendar.deleted_ids') ?? [];
      deletedIds.add(event.id);
      await prefs.setStringList('calendar.deleted_ids', deletedIds);
      // Auch vom Backend löschen
      try {
        await _calendarService.deleteEvent(event.id);
      } catch (_) {
        // Lokal gelöscht reicht als Fallback
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Termin gelöscht.')),
        );
      }
    }
  }

  Future<void> _editEvent(_CalendarEvent event) async {
    setState(() {
      _events.removeWhere((e) => e.id == event.id);
      _titleController.text = event.title;
      _filterPerson = event.person;
    });
    await _persistEvents();
    _openAddSheet(prefillTitle: event.title);
  }

  Future<void> _persistEvents() async {
    // Save lokal via SharedPreferences (Fallback)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'calendar.events', jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Quick-Add: Natural Language Parsing
  // ═══════════════════════════════════════════════════════════════════════
  void _handleQuickAdd(String input) {
    if (input.trim().isEmpty) return;

    final parsed = _parseQuickInput(input.trim());
    final now = DateTime.now();

    final event = _CalendarEvent(
      id: 'event_${now.millisecondsSinceEpoch}',
      title: parsed.title,
      start: parsed.dateTime,
      end: parsed.dateTime.add(const Duration(hours: 1)),
      person:
          parsed.person ?? (_filterPerson != 'Alle' ? _filterPerson : 'Eltern'),
      location: 'Familienkalender',
      recurrence: parsed.isBirthday ? 'Jährlich' : 'Einmalig',
      reminderMinutes: _smartReminderValue,
    );

    setState(() {
      _events.add(event);
      _selectedDay = DateTime(
          parsed.dateTime.year, parsed.dateTime.month, parsed.dateTime.day);
      _focusedDay = DateTime(parsed.dateTime.year, parsed.dateTime.month, 1);
    });
    _persistEvents();
    _quickAddController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'event_added')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  _QuickAddResult _parseQuickInput(String input) {
    String title = input;
    DateTime dateTime = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day, 10, 0);
    String? person;
    bool isBirthday = false;

    // Check for birthday keywords
    final birthdayPatterns = ['geburtstag', 'birthday', 'bday'];
    for (final bp in birthdayPatterns) {
      if (input.toLowerCase().contains(bp)) {
        isBirthday = true;
        person = '\u{1F382} Geburtstag';
        break;
      }
    }

    // Parse time: "10:00" or "10 Uhr" or "14:30"
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final timeUhrRegex = RegExp(r'(\d{1,2})\s*[Uu]hr');
    final timeMatch = timeRegex.firstMatch(input);
    final timeUhrMatch = timeUhrRegex.firstMatch(input);

    int hour = 10;
    int minute = 0;

    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2)!);
      title = title.replaceFirst(timeMatch.group(0)!, '').trim();
    } else if (timeUhrMatch != null) {
      hour = int.parse(timeUhrMatch.group(1)!);
      title = title.replaceFirst(timeUhrMatch.group(0)!, '').trim();
    }

    // Parse day name: Mo, Di, Mi, Do, Fr, Sa, So (or full names)
    final dayMap = {
      'mo': 1,
      'montag': 1,
      'di': 2,
      'dienstag': 2,
      'mi': 3,
      'mittwoch': 3,
      'do': 4,
      'donnerstag': 4,
      'fr': 5,
      'freitag': 5,
      'sa': 6,
      'samstag': 6,
      'so': 7,
      'sonntag': 7,
      'mon': 1,
      'tue': 2,
      'wed': 3,
      'thu': 4,
      'fri': 5,
      'sat': 6,
      'sun': 7,
    };

    DateTime targetDate = _selectedDay;
    final now = DateTime.now();

    for (final entry in dayMap.entries) {
      final pattern = RegExp('\\b${entry.key}\\b', caseSensitive: false);
      if (pattern.hasMatch(input)) {
        // Find next occurrence of this weekday
        final targetWeekday = entry.value;
        int daysAhead = targetWeekday - now.weekday;
        if (daysAhead <= 0) daysAhead += 7;
        targetDate = DateTime(now.year, now.month, now.day + daysAhead);
        title = title.replaceFirst(pattern, '').trim();
        break;
      }
    }

    // Parse date: "25.12." or "25.12.2026"
    final dateRegex = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})?');
    final dateMatch = dateRegex.firstMatch(input);
    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final year = dateMatch.group(3) != null
          ? int.parse(dateMatch.group(3)!)
          : now.year;
      targetDate = DateTime(year, month, day);
      title = title.replaceFirst(dateMatch.group(0)!, '').trim();
    }

    // Clean up title
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) title = input.split(' ').first;

    dateTime = DateTime(
        targetDate.year, targetDate.month, targetDate.day, hour, minute);

    return _QuickAddResult(
      title: title,
      dateTime: dateTime,
      person: person,
      isBirthday: isBirthday,
    );
  }

  Future<void> _openAddSheet({String? prefillTitle}) async {
    if (prefillTitle == null) _titleController.clear();
    String person = _filterPerson != 'Alle' ? _filterPerson : 'Eltern';
    TimeOfDay start = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 11, minute: 0);
    String recurrence = 'Einmalig';
    int reminder = _smartReminderValue;
    String endMode = _recurrenceEndMode;
    DateTime? recurrenceEndDate =
        _recurrenceEndDate ?? _selectedDay.add(const Duration(days: 30));
    int endCount = _recurrenceCount;
    String packReminderText = '';
    String bringer = '';
    String abholer = '';
    final packReminderCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final viewInsets = MediaQuery.of(ctx).viewInsets;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage, 'new_event'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Feature 4: Schnell-Vorlagen
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage,
                              'quick_template'),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _eventTemplates.length,
                        itemBuilder: (_, i) {
                          final t = _eventTemplates[i];
                          return GestureDetector(
                            onTap: () {
                              _titleController.text = t['label']!;
                              setSheetState(() => person =
                                  _resolveTemplatePerson(t['person']!));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5EFE7),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFD6C8B4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(t['emoji']!,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 5),
                                  Text(t['label']!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4A5568))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Titel',
                                hintText: 'z.B. Elternabend',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(person),
                              value: person,
                              decoration: const InputDecoration(
                                  labelText: 'F\u00fcr wen?'),
                              isExpanded: true,
                              items: [
                                ..._personColors.keys.map((p) =>
                                    DropdownMenuItem(value: p, child: Text(p))),
                                const DropdownMenuItem(
                                  value: '__add__',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded,
                                          size: 16, color: Color(0xFF4CAF50)),
                                      SizedBox(width: 6),
                                      Text('Neue Person…',
                                          style: TextStyle(
                                              color: Color(0xFF4CAF50),
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == '__add__') {
                                  _showAddPersonDialog(onAdded: (name) {
                                    setSheetState(() => person = name);
                                  });
                                } else if (v != null) {
                                  setSheetState(() {
                                    person = v;
                                    // Auto-set recurrence to yearly for birthdays
                                    if (v == '\u{1F382} Geburtstag') {
                                      recurrence = 'Jährlich';
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimeButton(
                                    label: 'Start',
                                    initial: start,
                                    onPicked: (t) => start = t,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TimeButton(
                                    label: 'Ende',
                                    initial: end,
                                    onPicked: (t) => end = t,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Feature 3: Wer bringt / Wer holt
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: bringer.isEmpty ? '' : bringer,
                                    decoration: const InputDecoration(
                                        labelText: '\u{1F697} Bringt'),
                                    isExpanded: true,
                                    items: [
                                      '',
                                      'Mama',
                                      'Papa',
                                      'Oma',
                                      'Opa',
                                      'Andere'
                                    ]
                                        .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(
                                                p.isEmpty ? 'Niemand' : p)))
                                        .toList(),
                                    onChanged: (v) => bringer = v ?? '',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: abholer.isEmpty ? '' : abholer,
                                    decoration: const InputDecoration(
                                        labelText: '\u{1F3E0} Holt'),
                                    isExpanded: true,
                                    items: [
                                      '',
                                      'Mama',
                                      'Papa',
                                      'Oma',
                                      'Opa',
                                      'Andere'
                                    ]
                                        .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(
                                                p.isEmpty ? 'Niemand' : p)))
                                        .toList(),
                                    onChanged: (v) => abholer = v ?? '',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Feature 2: Pack-Reminder
                            TextField(
                              controller: packReminderCtrl,
                              decoration: const InputDecoration(
                                labelText: '\u{1F392} Vorbereitung (optional)',
                                hintText:
                                    'z.B. Schwimmsachen, Turnzeug einpacken',
                              ),
                              onChanged: (v) => packReminderText = v,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: recurrence,
                              decoration: const InputDecoration(
                                  labelText: 'Wiederholung'),
                              isExpanded: true,
                              items: _recurrenceOptions
                                  .map((p) => DropdownMenuItem(
                                      value: p, child: Text(p)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) recurrence = v;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: reminder,
                              decoration: const InputDecoration(
                                  labelText: 'Erinnerung'),
                              isExpanded: true,
                              items: _reminderOptions
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(
                                          m == _smartReminderValue
                                              ? 'Smart (1W, 1T, am Tag)'
                                              : m == 0
                                                  ? 'Keine'
                                                  : '$m Min vorher',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) reminder = v;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: endMode,
                              decoration:
                                  const InputDecoration(labelText: 'Endet'),
                              isExpanded: true,
                              items: _recurrenceEndOptions
                                  .map((p) => DropdownMenuItem(
                                      value: p, child: Text(p)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null)
                                  setSheetState(() {
                                    endMode = v;
                                    if (endMode == '5 Termine') endCount = 5;
                                    if (endMode == '10 Termine') endCount = 10;
                                  });
                              },
                            ),
                            if (endMode == 'Datum w\u00e4hlen') ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate:
                                        recurrenceEndDate ?? _selectedDay,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 1)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365 * 2)),
                                  );
                                  if (picked != null) {
                                    setSheetState(
                                        () => recurrenceEndDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.event_available_rounded),
                                label: Text(recurrenceEndDate == null
                                    ? 'Enddatum w\u00e4hlen'
                                    : 'Endet am ${DateFormat.yMMMd('de').format(recurrenceEndDate!)}'),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: Text(AppStringsManager.getString(
                            languageService.currentLanguage, 'save_btn')),
                        onPressed: () async {
                          if (_titleController.text.trim().isEmpty) return;
                          final startDate = DateTime(
                            _selectedDay.year,
                            _selectedDay.month,
                            _selectedDay.day,
                            start.hour,
                            start.minute,
                          );
                          final endDateTime = DateTime(
                            _selectedDay.year,
                            _selectedDay.month,
                            _selectedDay.day,
                            end.hour,
                            end.minute,
                          );
                          final base = _CalendarEvent(
                            id: 'event_${DateTime.now().millisecondsSinceEpoch}',
                            title: _titleController.text.trim(),
                            start: startDate,
                            end: endDateTime.isAfter(startDate)
                                ? endDateTime
                                : startDate.add(const Duration(hours: 1)),
                            person: person,
                            location: 'Familienkalender',
                            recurrence: recurrence,
                            reminderMinutes: reminder,
                            recurrenceEndMode: endMode,
                            recurrenceEndDate: endMode == 'Datum w\u00e4hlen'
                                ? recurrenceEndDate
                                : null,
                            recurrenceCount:
                                endMode.contains('Termine') ? endCount : null,
                            packReminder: packReminderText.trim().isEmpty
                                ? null
                                : packReminderText.trim(),
                            bringer: bringer.isEmpty ? null : bringer,
                            abholer: abholer.isEmpty ? null : abholer,
                          );
                          final expanded = _expandRecurrence(base);
                          try {
                            for (final e in expanded) {
                              await _calendarService.addEvent(e.toJson());
                            }
                          } catch (_) {
                            if (!mounted) return;
                            setState(() {
                              _syncError = _calendarService.lastSyncError;
                            });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _syncError ??
                                      'Termin konnte nicht gespeichert werden.',
                                ),
                              ),
                            );
                            packReminderCtrl.dispose();
                            return;
                          }
                          setState(() {
                            _events.addAll(expanded);
                            _syncError = _calendarService.lastSyncError;
                          });
                          _scheduleRemindersFor(expanded);
                          packReminderCtrl.dispose();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthTitle = DateFormat.yMMMM('de').format(_focusedDay);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'calendar')),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadEvents,
            tooltip: 'Sync',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_syncError != null && APIConfig.isBackendConfigured())
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 16, color: Colors.amber[800]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline-Modus — Termine werden lokal gespeichert',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[900],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadEvents,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                              AppStringsManager.getString(
                                  languageService.currentLanguage, 'sync_btn'),
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Diese Woche Vorschau — compact
            _WeekPreview(
              events: _events
                  .where((e) =>
                      _filterPerson == 'Alle' || e.person == _filterPerson)
                  .toList(),
              personColors: _personColors,
              onDayTap: _selectDay,
              onDeleteEvent: _deleteEvent,
            ),
            const SizedBox(height: 16),
            // Filter chips — single horizontal scroll line
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('Alle'),
                  const SizedBox(width: 6),
                  ..._personColors.keys.expand((k) => [
                        _buildFilterChip(k),
                        const SizedBox(width: 6),
                      ]),
                  // Add person chip
                  GestureDetector(
                    onTap: () => _showAddPersonDialog(
                        onAdded: (name) =>
                            setState(() => _filterPerson = name)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF4CAF50), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 13, color: Color(0xFF4CAF50)),
                          SizedBox(width: 3),
                          Text('Person',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Month navigation bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    onPressed: () => _changeMonth(-1),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        monthTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  // Heute-Button
                  if (!_isSameDay(_selectedDay, DateTime.now()))
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: FilledButton.tonal(
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _focusedDay = now;
                            _selectedDay =
                                DateTime(now.year, now.month, now.day);
                          });
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.today_rounded, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              AppStringsManager.getString(
                                  languageService.currentLanguage,
                                  'today_button'),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: () => _changeMonth(1),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Month Grid
            _MonthGrid(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              onSelectDay: _selectDay,
              eventCounter: _countEventsForDay,
            ),
            const SizedBox(height: 16),
            // Quick-Add Natural Language Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _quickAddController,
                decoration: InputDecoration(
                  hintText: AppStringsManager.getString(
                      languageService.currentLanguage, 'quick_add_hint'),
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.bolt_rounded,
                    color: Colors.amber[600],
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, size: 20),
                    color: const Color(0xFF8B5CF6),
                    onPressed: () => _handleQuickAdd(_quickAddController.text),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: _handleQuickAdd,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  DateFormat.EEEE('de').add_d().format(_selectedDay),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                Text(
                  _eventsForSelectedDay.isEmpty
                      ? 'Keine Termine'
                      : '${_eventsForSelectedDay.length} Termine',
                  style:
                      const TextStyle(color: Color(0xFF718096), fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._eventsForSelectedDay.map((e) => _EventCard(
                event: e,
                color: _personColors[e.person] ?? theme.colorScheme.primary,
                onDelete: () => _deleteEvent(e),
                onEdit: () => _editEvent(e))),
            if (_eventsForSelectedDay.isEmpty)
              GestureDetector(
                onTap: _openAddSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      style: BorderStyle.solid,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '\u{1F33F}',
                        style: TextStyle(fontSize: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppStringsManager.getString(
                            languageService.currentLanguage, 'no_events_today'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tippe hier um einen Termin hinzuzufügen',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_eventsForSelectedDay.isNotEmpty)
              const SizedBox(height: 80), // Space for FAB
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _openAddSheet,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  void _showPersonOptions(String personName) {
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
              child: Text(personName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Umbenennen'),
              onTap: () {
                Navigator.pop(ctx);
                _renameCustomPerson(personName);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Löschen',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCustomPerson(personName);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _renameCustomPerson(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Person umbenennen'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Neuer Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    setState(() {
      // Custom-Personen Liste updaten
      final idx = _customPersons.indexOf(oldName);
      if (idx != -1) _customPersons[idx] = newName;
      // Farbe übertragen
      final color = _personColors.remove(oldName);
      if (color != null) _personColors[newName] = color;
      // Alle Events mit altem Namen updaten
      for (int i = 0; i < _events.length; i++) {
        if (_events[i].person == oldName) {
          _events[i] = _events[i].copyWith(person: newName);
        }
      }
      // Filter updaten
      if (_filterPerson == oldName) _filterPerson = newName;
    });
    await _saveCustomPersons();
    await _persistEvents();
  }

  Future<void> _deleteCustomPerson(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('"$name" löschen?'),
        content: const Text(
            'Die Person wird aus dem Kalender entfernt. Zugehörige Termine werden zu "Eltern" verschoben.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _customPersons.remove(name);
      _personColors.remove(name);
      // Events dieser Person zu "Eltern" verschieben
      for (int i = 0; i < _events.length; i++) {
        if (_events[i].person == name) {
          _events[i] = _events[i].copyWith(person: 'Eltern');
        }
      }
      if (_filterPerson == name) _filterPerson = 'Alle';
    });
    await _saveCustomPersons();
    await _persistEvents();
  }

  Widget _buildFilterChip(String label) {
    final selected = _filterPerson == label;
    final color = label == 'Alle'
        ? const Color(0xFF2D3748)
        : _personColors[label] ?? const Color(0xFF4CAF50);
    final isCustom = _customPersons.contains(label);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _filterPerson = label),
      onLongPress: isCustom ? () => _showPersonOptions(label) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? color : const Color(0xFF4A5568),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (isCustom && selected) ...[
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showPersonOptions(label),
              child: Icon(Icons.more_vert_rounded,
                  size: 12, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedDay,
    required this.selectedDay,
    required this.onSelectDay,
    required this.eventCounter,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime day) onSelectDay;
  final int Function(DateTime day) eventCounter;

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysBefore = first.weekday % 7; // Monday = 1
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final List<DateTime> days = [];
    for (int i = 0; i < daysBefore; i++) {
      days.add(first.subtract(Duration(days: daysBefore - i)));
    }
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    return days;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(focusedDay);
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_mo'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_di'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_mi'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_do'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_fr'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_sa'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'day_so'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF718096))),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, i) {
              final day = days[i];
              final isCurrentMonth = day.month == focusedDay.month;
              final isSelected = _isSameDay(day, selectedDay);
              final isToday = _isSameDay(day, now);
              final eventCount = eventCounter(day);

              Color textColor = const Color(0xFF2D3748);
              if (!isCurrentMonth) textColor = Colors.grey[350]!;
              if (isToday && !isSelected) textColor = Colors.white;
              if (isSelected) textColor = const Color(0xFF8B5CF6);

              return GestureDetector(
                onTap: () => onSelectDay(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isToday && !isSelected
                        ? const Color(0xFF8B5CF6)
                        : isSelected
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (eventCount > 0) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isToday && !isSelected
                                ? Colors.white
                                : const Color(0xFF8B5CF6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(
      {required this.event, required this.color, this.onDelete, this.onEdit});

  final _CalendarEvent event;
  final Color color;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  String _fmt(DateTime dt) {
    return DateFormat.Hm('de').format(dt);
  }

  bool get _isBirthday => event.person == '\u{1F382} Geburtstag';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showOptions(context),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gradient left bar — thinner
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color,
                        color.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                event.person,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (_isBirthday) ...[
                              const SizedBox(width: 6),
                              const Text('\u{1F382}',
                                  style: TextStyle(fontSize: 14)),
                            ],
                            const Spacer(),
                            Text(
                              '${_fmt(event.start)} - ${_fmt(event.end)}',
                              style: const TextStyle(
                                color: Color(0xFF4A5568),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 2),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showOptions(context),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.more_vert_rounded,
                                    size: 16, color: Color(0xFF718096)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (event.recurrence != 'Einmalig')
                              _Badge(
                                label: event.recurrence,
                                color: color,
                                icon: Icons.loop_rounded,
                              ),
                            if (event.reminderMinutes ==
                                _CalendarScreenState._smartReminderValue)
                              const _Badge(
                                label: 'Smart: 1W • 1T • Heute',
                                color: Color(0xFF5B7FFF),
                                icon: Icons.auto_awesome_rounded,
                              ),
                            if (event.reminderMinutes > 0)
                              _Badge(
                                label: '${event.reminderMinutes} Min vorher',
                                color: const Color(0xFF718096),
                                icon: Icons.alarm_rounded,
                              ),
                            if (event.recurrenceEndMode.contains('Termine') &&
                                event.recurrenceCount != null)
                              _Badge(
                                label:
                                    'Endet nach ${event.recurrenceCount} Terminen',
                                color: const Color(0xFF718096),
                                icon: Icons.flag_rounded,
                              ),
                            if (event.recurrenceEndMode == 'Datum wählen' &&
                                event.recurrenceEndDate != null)
                              _Badge(
                                label:
                                    'Endet ${DateFormat.yMMMd('de').format(event.recurrenceEndDate!)}',
                                color: const Color(0xFF718096),
                                icon: Icons.event_available_rounded,
                              ),
                          ],
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 16, color: Color(0xFF718096)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style:
                                      const TextStyle(color: Color(0xFF4A5568)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Feature 3: Wer bringt / Wer holt
                        if ((event.bringer != null &&
                                event.bringer!.isNotEmpty) ||
                            (event.abholer != null &&
                                event.abholer!.isNotEmpty)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (event.bringer != null &&
                                  event.bringer!.isNotEmpty)
                                _Badge(
                                  label: '${event.bringer!} bringt',
                                  color: const Color(0xFF4A90E2),
                                  icon: Icons.directions_car_rounded,
                                ),
                              if (event.abholer != null &&
                                  event.abholer!.isNotEmpty)
                                _Badge(
                                  label: '${event.abholer!} holt',
                                  color: const Color(0xFF7B68EE),
                                  icon: Icons.home_rounded,
                                ),
                            ],
                          ),
                        ],
                        // Feature 2: Pack-Reminder Badge
                        if (event.packReminder != null &&
                            event.packReminder!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.backpack_outlined,
                                  size: 14, color: Color(0xFF9F7AEA)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '\u{1F392} ${event.packReminder!}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9F7AEA),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Bearbeiten'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Löschen',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String person;
  final String? location;
  final bool allDay;
  final String recurrence;
  final int reminderMinutes;
  final String recurrenceEndMode;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final String? packReminder; // Feature 2: Vorbereitungsnotiz
  final String? bringer; // Feature 3: Wer bringt
  final String? abholer; // Feature 3: Wer holt

  _CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.person,
    this.location,
    this.allDay = false,
    this.recurrence = 'Einmalig',
    this.reminderMinutes = 0,
    this.recurrenceEndMode = 'Kein Ende',
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.packReminder,
    this.bringer,
    this.abholer,
  });

  _CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    String? person,
    String? location,
    bool? allDay,
    String? recurrence,
    int? reminderMinutes,
    String? recurrenceEndMode,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    String? packReminder,
    String? bringer,
    String? abholer,
  }) {
    return _CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      person: person ?? this.person,
      location: location ?? this.location,
      allDay: allDay ?? this.allDay,
      recurrence: recurrence ?? this.recurrence,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      recurrenceEndMode: recurrenceEndMode ?? this.recurrenceEndMode,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      packReminder: packReminder ?? this.packReminder,
      bringer: bringer ?? this.bringer,
      abholer: abholer ?? this.abholer,
    );
  }

  factory _CalendarEvent.fromJson(Map<String, dynamic> json) {
    final start =
        DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now();
    final person = json['person']?.toString() ?? 'Eltern';
    final title = json['title']?.toString() ?? '';
    final fallbackId =
        'legacy_${start.millisecondsSinceEpoch}_${title.hashCode}_${person.hashCode}';

    return _CalendarEvent(
      id: json['id']?.toString() ?? fallbackId,
      title: title,
      start: start,
      end: DateTime.tryParse(json['end']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
      person: person,
      location: json['location']?.toString(),
      allDay: json['allDay'] == true,
      recurrence: json['recurrence']?.toString() ?? 'Einmalig',
      reminderMinutes: (json['reminderMinutes'] as num?)?.toInt() ??
          _CalendarScreenState._smartReminderValue,
      recurrenceEndMode: json['recurrenceEndMode']?.toString() ?? 'Kein Ende',
      recurrenceEndDate: json['recurrenceEndDate'] != null
          ? DateTime.tryParse(json['recurrenceEndDate'].toString())
          : null,
      recurrenceCount: (json['recurrenceCount'] as num?)?.toInt(),
      packReminder: json['packReminder']?.toString(),
      bringer: json['bringer']?.toString(),
      abholer: json['abholer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'person': person,
      'location': location,
      'allDay': allDay,
      'recurrence': recurrence,
      'reminderMinutes': reminderMinutes,
      'recurrenceEndMode': recurrenceEndMode,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'recurrenceCount': recurrenceCount,
      'packReminder': packReminder,
      'bringer': bringer,
      'abholer': abholer,
    };
  }
}

extension on _CalendarScreenState {
  Future<void> _scheduleRemindersFor(List<_CalendarEvent> events) async {
    for (final event in events) {
      final body =
          '${event.person}: ${DateFormat.Hm('de').format(event.start)}';

      if (event.reminderMinutes == _CalendarScreenState._smartReminderValue) {
        await NotificationService.instance.scheduleStandardCalendarReminders(
          eventId: event.id,
          eventStart: event.start,
          title: event.title,
          body: body,
        );
        continue;
      }

      if (event.reminderMinutes > 0) {
        final when =
            event.start.subtract(Duration(minutes: event.reminderMinutes));
        await NotificationService.instance.scheduleEventReminder(
          eventId: event.id,
          when: when,
          title: event.title,
          body: body,
          reminderKey: 'custom_${event.reminderMinutes}',
        );
      }
      // Feature 2: Pack-Reminder Abend vorher um 20:00 Uhr
      if (event.packReminder != null && event.packReminder!.isNotEmpty) {
        final evening = DateTime(
          event.start.year,
          event.start.month,
          event.start.day - 1,
          20,
          0,
        );
        if (evening.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleEventReminder(
            eventId: '${event.id}_pack',
            when: evening,
            title: 'Morgen: ${event.title}',
            body: 'Nicht vergessen: ${event.packReminder}',
            reminderKey: 'pack_reminder',
          );
        }
      }
    }
  }
}

class _TimeButton extends StatefulWidget {
  const _TimeButton(
      {required this.label, required this.initial, required this.onPicked});

  final String label;
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  State<_TimeButton> createState() => _TimeButtonState();
}

class _TimeButtonState extends State<_TimeButton> {
  late TimeOfDay _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  Future<void> _pick() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _value,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24))),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _value = picked);
      widget.onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _pick,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.label,
            style: const TextStyle(color: Color(0xFF4A5568)),
          ),
          Text(
            _value.format(context),
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 1: Wochenstreifen — 7-Tage Quick-Selector
// ═══════════════════════════════════════════════════════════════════════════
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDay,
    required this.onSelectDay,
    required this.eventCounter,
  });

  final DateTime selectedDay;
  final void Function(DateTime) onSelectDay;
  final int Function(DateTime) eventCounter;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final days = List.generate(7, (i) => today.add(Duration(days: i)));

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == selectedDay.year &&
              day.month == selectedDay.month &&
              day.day == selectedDay.day;
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final eventCount = eventCounter(day);
          final wd = weekdays[day.weekday - 1];

          return GestureDetector(
            onTap: () => onSelectDay(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4CAF50)
                    : isToday
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4CAF50)
                      : isToday
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[200]!,
                  width: isSelected || isToday ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    wd,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : const Color(0xFF2D3748),
                    ),
                  ),
                  if (eventCount > 0) ...[
                    const SizedBox(height: 3),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Colors.white : const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE 5: Diese Woche Vorschau — horizontal scrollbare Event-Cards
// ═══════════════════════════════════════════════════════════════════════════
class _WeekPreview extends StatelessWidget {
  const _WeekPreview({
    required this.events,
    required this.personColors,
    required this.onDayTap,
    this.onDeleteEvent,
  });

  final List<_CalendarEvent> events;
  final Map<String, Color> personColors;
  final void Function(DateTime) onDayTap;
  final void Function(_CalendarEvent)? onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in6days = today.add(const Duration(days: 6));

    final upcoming = events
        .where((e) => !e.start.isBefore(today) && e.start.isBefore(in6days))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Diese Woche',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: upcoming.length,
            itemBuilder: (context, i) {
              final e = upcoming[i];
              final color = personColors[e.person] ?? const Color(0xFF4CAF50);
              final isToday = e.start.year == today.year &&
                  e.start.month == today.month &&
                  e.start.day == today.day;
              final dayLabel =
                  isToday ? 'Heute' : DateFormat.E('de').format(e.start);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onDayTap(e.start),
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Text(e.title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          ListTile(
                            leading: const Icon(Icons.open_in_new_rounded),
                            title: const Text('Zum Tag springen'),
                            onTap: () {
                              Navigator.pop(ctx);
                              onDayTap(e.start);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete_rounded,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('Löschen',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () {
                              Navigator.pop(ctx);
                              onDeleteEvent?.call(e);
                            },
                          ),
                        ]),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$dayLabel ${DateFormat.Hm('de').format(e.start)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (ctx) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 8),
                                            child: Text(e.title,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.open_in_new_rounded),
                                            title:
                                                const Text('Zum Tag springen'),
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              onDayTap(e.start);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.delete_rounded,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error),
                                            title: Text('Löschen',
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error)),
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              onDeleteEvent?.call(e);
                                            },
                                          ),
                                        ]),
                                  ),
                                ),
                              );
                            },
                            child: const Icon(Icons.more_vert_rounded,
                                size: 14, color: Color(0xFF718096)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3748),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Quick-Add Result Model
// ═══════════════════════════════════════════════════════════════════════════
class _QuickAddResult {
  final String title;
  final DateTime dateTime;
  final String? person;
  final bool isBirthday;

  const _QuickAddResult({
    required this.title,
    required this.dateTime,
    this.person,
    this.isBirthday = false,
  });
}
