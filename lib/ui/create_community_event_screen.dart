import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/models/community_event.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

/// Event erstellen — moderner 3-Schritt Wizard.
///
/// Schritt 1: Wer bist du? (Veranstalter-Typ + Name)
/// Schritt 2: Dein Event (Titel, Kategorie, Datum, Ort, Alter, Preis)
/// Schritt 3: Details (Indoor/Outdoor, Barrierefreiheit, Sprache, Kontakt)
class CreateCommunityEventScreen extends StatefulWidget {
  const CreateCommunityEventScreen({super.key});

  @override
  State<CreateCommunityEventScreen> createState() =>
      _CreateCommunityEventScreenState();
}

class _CreateCommunityEventScreenState
    extends State<CreateCommunityEventScreen> {
  final _pageCtrl = PageController();

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  int _step = 0;
  bool _saving = false;
  bool _scanning = false;

  // Schritt 1
  CreatorType _creatorType = CreatorType.eltern;
  final _organizerCtrl = TextEditingController();

  // Schritt 2
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  EventCategory _category = EventCategory.sonstiges;
  final Set<EventAgeGroup> _ageGroups = {EventAgeGroup.alle};
  final _locationCtrl = TextEditingController();
  String _city = '';
  double? _lat;
  double? _lon;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _eventTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isFree = true;
  final _priceCtrl = TextEditingController();
  bool _isRecurring = false;
  final _recurringCtrl = TextEditingController();
  bool _isPrivateAddress = false;

  // Schritt 3
  EventVenue _venue = EventVenue.beides;
  final Set<AccessibilityTag> _accessibility = {};
  String _eventLanguage = 'de';
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _rainPlanCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _organizerCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _recurringCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _rainPlanCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step--);
    }
  }

  // ─── Flyer-Scan (Kamera → KI → Auto-Fill) ──────────────────────────────────

  Future<void> _scanFlyer() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(_t('community_event_scan_flyer'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_t('community_event_ai_recognizes'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 16),
          ListTile(
            leading:
                const Icon(Icons.camera_alt_rounded, color: Color(0xFF8B5CF6)),
            title: Text(_t('community_event_take_photo')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: Color(0xFF8B5CF6)),
            title: Text(_t('community_event_from_gallery')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _scanning = true);

    try {
      final bytes = await picked.readAsBytes();
      final text = await GeminiAIService().generateText(
        'Analysiere diesen Flyer/Poster für ein Familien-Event. '
        'Extrahiere folgende Informationen als JSON:\n'
        '{"title":"...","description":"kurze Beschreibung in 1-2 Sätzen",'
        '"date":"YYYY-MM-DD oder null","time":"HH:MM oder null",'
        '"location":"Adresse/Ort oder null","price":"kostenlos oder Betrag oder null",'
        '"organizer":"Veranstalter oder null"}\n'
        'Antworte NUR mit dem JSON, kein Markdown.',
        imageBytes: bytes,
      ).timeout(const Duration(seconds: 20));
      final jsonStr = text.replaceAll(RegExp(r'^```json\s*|\s*```$'), '');

      if (jsonStr.startsWith('{')) {
        final data = _parseFlyer(jsonStr);

        if (mounted) {
          setState(() {
            if (data['title'] != null) _titleCtrl.text = data['title'];
            if (data['description'] != null)
              _descCtrl.text = data['description'];
            if (data['location'] != null) _locationCtrl.text = data['location'];
            if (data['price'] != null && data['price'] != 'kostenlos') {
              _isFree = false;
              _priceCtrl.text = data['price'];
            }
            if (data['organizer'] != null)
              _organizerCtrl.text = data['organizer'];
            if (data['date'] != null) {
              final parsed = DateTime.tryParse(data['date']);
              if (parsed != null) _eventDate = parsed;
            }
            if (data['time'] != null) {
              final parts = data['time'].toString().split(':');
              if (parts.length == 2) {
                _eventTime = TimeOfDay(
                  hour: int.tryParse(parts[0]) ?? 10,
                  minute: int.tryParse(parts[1]) ?? 0,
                );
              }
            }
            _scanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('community_flyer_detected')),
            backgroundColor: Color(0xFF16A34A),
          ));
        }
      } else {
        throw Exception('KI konnte den Flyer nicht lesen');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Flyer konnte nicht erkannt werden: $e'),
        ));
      }
    }
  }

  Map<String, dynamic> _parseFlyer(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end == -1) return {};
      final chunk = raw.substring(start, end + 1);
      final decoded = jsonDecode(chunk);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  // ─── Duplikat-Erkennung ────────────────────────────────────────────────────

  Future<CommunityEvent?> _checkDuplicate() async {
    final title = _titleCtrl.text.trim().toLowerCase();
    if (title.isEmpty) return null;

    try {
      final existing = await CommunityEventService.instance.loadEvents(
        city: _city.isNotEmpty ? _city : _locationCtrl.text.trim(),
      );

      for (final event in existing) {
        final existingTitle = event.title.toLowerCase();
        // Einfacher Ähnlichkeitscheck: Titel enthält den anderen oder umgekehrt
        final similar = existingTitle.contains(title) ||
            title.contains(existingTitle) ||
            _levenshteinSimilarity(title, existingTitle) > 0.7;

        // Gleiches Datum (±1 Tag)
        final samePeriod =
            (event.eventDate.difference(_eventDate).inDays).abs() <= 1;

        if (similar && samePeriod) return event;
      }
    } catch (_) {}
    return null;
  }

  double _levenshteinSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final maxLen = a.length > b.length ? a.length : b.length;
    final dist = _levenshteinDistance(a, b);
    return 1.0 - (dist / maxLen);
  }

  int _levenshteinDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) d[i][0] = i;
    for (var j = 0; j <= n; j++) d[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
    }
    return d[m][n];
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Bitte gib einen Titel ein (Schritt 2)');
      return;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      _showError('Bitte gib einen Ort ein (Schritt 2)');
      return;
    }

    // Duplikat-Erkennung
    final duplicate = await _checkDuplicate();
    if (duplicate != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Text('⚠️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(_t('community_event_similar_found')),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '"${duplicate.title}" wurde bereits am '
              '${duplicate.createdAt.day}.${duplicate.createdAt.month}.${duplicate.createdAt.year} '
              'von ${duplicate.organizer} geteilt.',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Möchtest du dein Event trotzdem hinzufügen?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('community_event_create_anyway')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _saving = true);

    final uid = AuthService.instance.currentUser?.uid ?? 'guest';
    final eventDateTime = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _eventTime.hour,
      _eventTime.minute,
    );

    final event = CommunityEvent(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      ageGroups: _ageGroups.toList(),
      venue: _venue,
      location: _locationCtrl.text.trim(),
      city: _city.isNotEmpty ? _city : _locationCtrl.text.trim(),
      lat: _lat,
      lon: _lon,
      isPrivateAddress: _isPrivateAddress,
      eventDate: eventDateTime,
      isRecurring: _isRecurring,
      recurringNote: _isRecurring ? _recurringCtrl.text.trim() : null,
      rainPlan:
          _rainPlanCtrl.text.trim().isEmpty ? null : _rainPlanCtrl.text.trim(),
      price: _isFree ? 'kostenlos' : _priceCtrl.text.trim(),
      isFree: _isFree,
      url: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      organizer: _organizerCtrl.text.trim().isEmpty
          ? 'Eltern-Tipp'
          : _organizerCtrl.text.trim(),
      creatorType: _creatorType,
      contactName: _contactNameCtrl.text.trim().isEmpty
          ? null
          : _contactNameCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim().isEmpty
          ? null
          : _contactPhoneCtrl.text.trim(),
      accessibility: _accessibility.toList(),
      eventLanguage: _eventLanguage,
      source: EventSource.community,
      creatorId: uid,
      createdAt: DateTime.now(),
    );

    final success = await CommunityEventService.instance.createEvent(event);

    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('community_event_published')),
        ));
        Navigator.pop(context, true);
      } else {
        _showError(CommunityEventService.instance.error ??
            'Event konnte nicht erstellt werden.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = CommunityEventService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'create_event_title')),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text('${service.remainingToday}/3 heute',
                  style: const TextStyle(fontSize: 11)),
              avatar: const Icon(Icons.event_available_rounded, size: 16),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Progress
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = i == _step;
              final done = i < _step;
              return Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF16A34A)
                        : active
                            ? const Color(0xFF8B5CF6)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : Text('${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : theme.colorScheme.outline,
                            )),
                  ),
                ),
                if (i < 2)
                  Container(
                    width: 40,
                    height: 2,
                    color: i < _step
                        ? const Color(0xFF16A34A)
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                  ),
              ]);
            }),
          ),
        ),
        Text(
          ['Wer bist du?', 'Dein Event', 'Details & Kontakt'][_step],
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [_step1(theme), _step2(theme), _step3(theme)],
          ),
        ),
        // Navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            if (_step > 0)
              TextButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(_t('network_back')),
              )
            else
              const Spacer(),
            const Spacer(),
            if (_step < 2)
              FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'next_btn_wizard')),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.publish_rounded, size: 18),
                label: Text(_saving ? 'Wird gesendet...' : 'Veröffentlichen'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ─── SCHRITT 1: Wer bist du? ──────────────────────────────────────────────
  Widget _step1(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            const Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
              'Events eintragen ist kostenlos. Hilf anderen Eltern tolle Aktivitaeten zu finden!',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF6B21A8), height: 1.3),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'i_am'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...CreatorType.values.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<CreatorType>(
                value: t,
                groupValue: _creatorType,
                onChanged: (v) => setState(() => _creatorType = v!),
                title: Text(_creatorTypeLabel(t),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(_creatorTypeHint(t),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                tileColor: _creatorType == t
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.06)
                    : null,
                activeColor: const Color(0xFF8B5CF6),
                dense: true,
              ),
            )),
        const SizedBox(height: 16),
        TextField(
          controller: _organizerCtrl,
          decoration: InputDecoration(
            labelText: 'Name / Organisation',
            hintText: _creatorType == CreatorType.eltern
                ? 'z.B. Sarah M.'
                : 'z.B. Kita Sonnenschein',
            prefixIcon: const Icon(Icons.person_rounded, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    );
  }

  String _creatorTypeLabel(CreatorType t) {
    switch (t) {
      case CreatorType.eltern:
        return '\u{1F46A} Eltern / Privatperson';
      case CreatorType.verein:
        return '\u{1F91D} Verein / Initiative';
      case CreatorType.institution:
        return '\u{1F3EB} Kita / Familienzentrum / Schule';
      case CreatorType.unternehmen:
        return '\u{1F3E2} Unternehmen / Anbieter';
    }
  }

  String _creatorTypeHint(CreatorType t) {
    switch (t) {
      case CreatorType.eltern:
        return 'Spielplatz-Tipp, Eltern-Treff, Geheimtipp';
      case CreatorType.verein:
        return 'Vereins-Events, Elterngruppen, Sport';
      case CreatorType.institution:
        return 'Offizielle Angebote, Kurse, Feste';
      case CreatorType.unternehmen:
        return 'Workshops, Kurse, Veranstaltungen';
    }
  }

  // ─── SCHRITT 2: Dein Event ────────────────────────────────────────────────
  Widget _step2(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        // Flyer-Scan Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _scanning ? null : _scanFlyer,
            icon: _scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.document_scanner_rounded, size: 18),
            label: Text(
                _scanning ? 'KI liest Flyer...' : '📷 Flyer/Poster scannen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(_t('community_event_photo_hint'),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: 'Titel *',
            hintText: 'z.B. Familien-Picknick im Park',
            prefixIcon: const Icon(Icons.title_rounded, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: 'Beschreibung',
            hintText: 'Was erwartet die Familien?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'category_required'),
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: EventCategory.values
                .map((c) => ChoiceChip(
                      label:
                          Text(c.label, style: const TextStyle(fontSize: 11)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        const SizedBox(height: 16),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'age_group_required'),
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: EventAgeGroup.values
                .map((a) => FilterChip(
                      label:
                          Text(a.label, style: const TextStyle(fontSize: 11)),
                      selected: _ageGroups.contains(a),
                      onSelected: (s) => setState(
                          () => s ? _ageGroups.add(a) : _ageGroups.remove(a)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        const SizedBox(height: 16),
        // Datum + Uhrzeit
        Row(children: [
          Expanded(
              child: GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _eventDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _eventDate = d);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Datum *',
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                  '${_eventDate.day}.${_eventDate.month}.${_eventDate.year}',
                  style: theme.textTheme.bodyMedium),
            ),
          )),
          const SizedBox(width: 10),
          SizedBox(
              width: 120,
              child: GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                      context: context, initialTime: _eventTime);
                  if (t != null) setState(() => _eventTime = t);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Uhrzeit',
                    prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                      '${_eventTime.hour.toString().padLeft(2, '0')}:${_eventTime.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyMedium),
                ),
              )),
        ]),
        const SizedBox(height: 12),
        // Wiederkehrend
        SwitchListTile(
          value: _isRecurring,
          onChanged: (v) => setState(() => _isRecurring = v),
          title: Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'recurring_event'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (_isRecurring)
          TextField(
            controller: _recurringCtrl,
            decoration: InputDecoration(
              hintText: 'z.B. Jeden Samstag 10-12 Uhr',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
          ),
        const SizedBox(height: 12),
        // Ort
        LocationPickerWidget(
          hint: 'Ort / Adresse wählen *',
          onLocationPicked: (loc) {
            _locationCtrl.text = loc.displayName;
            _city = loc.city;
            _lat = loc.lat;
            _lon = loc.lon;
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _isPrivateAddress,
          onChanged: (v) => setState(() => _isPrivateAddress = v),
          title: Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'private_address'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        // Preis
        SwitchListTile(
          value: _isFree,
          onChanged: (v) => setState(() => _isFree = v),
          title: Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'free_event'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          secondary: const Text('\u{1F389}', style: TextStyle(fontSize: 20)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (!_isFree)
          TextField(
            controller: _priceCtrl,
            decoration: InputDecoration(
              hintText: 'z.B. 5 EUR pro Kind',
              prefixIcon: const Icon(Icons.euro_rounded, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
          ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ─── SCHRITT 3: Details & Kontakt ─────────────────────────────────────────
  Widget _step3(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'indoor_outdoor'),
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EventVenue.values
                .map((v) => ChoiceChip(
                      label:
                          Text(v.label, style: const TextStyle(fontSize: 12)),
                      selected: _venue == v,
                      onSelected: (_) => setState(() => _venue = v),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        if (_venue == EventVenue.outdoor || _venue == EventVenue.beides) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _rainPlanCtrl,
            decoration: InputDecoration(
              labelText: 'Bei Regen? (optional)',
              hintText: 'z.B. Faellt aus / Alternative Indoor',
              prefixIcon: const Icon(Icons.umbrella_rounded, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'accessibility_label'),
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AccessibilityTag.values
                .map((a) => FilterChip(
                      label:
                          Text(a.label, style: const TextStyle(fontSize: 11)),
                      selected: _accessibility.contains(a),
                      onSelected: (s) => setState(() =>
                          s ? _accessibility.add(a) : _accessibility.remove(a)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        const SizedBox(height: 20),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'event_language'),
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: {
              'de': '\u{1F1E9}\u{1F1EA} Deutsch',
              'en': '\u{1F1EC}\u{1F1E7} English',
              'tr': '\u{1F1F9}\u{1F1F7} Tuerkce',
              'ar': '\u{1F1F8}\u{1F1E6} Arabisch',
              'ku': 'Kurdi',
              'ru': '\u{1F1F7}\u{1F1FA} Russisch',
            }
                .entries
                .map((e) => ChoiceChip(
                      label:
                          Text(e.value, style: const TextStyle(fontSize: 11)),
                      selected: _eventLanguage == e.key,
                      onSelected: (_) => setState(() => _eventLanguage = e.key),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        const SizedBox(height: 20),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'contact_optional'),
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'contact_hint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 10),
        TextField(
          controller: _contactNameCtrl,
          decoration: InputDecoration(
            labelText: 'Ansprechpartner',
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _contactPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Telefon',
            prefixIcon: const Icon(Icons.phone_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'Website / Link (optional)',
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
