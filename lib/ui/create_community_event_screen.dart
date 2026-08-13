import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/community_event_service.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/models/community_event.dart';

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
  int _step = 0;
  bool _saving = false;

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

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Bitte gib einen Titel ein (Schritt 2)');
      return;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      _showError('Bitte gib einen Ort ein (Schritt 2)');
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('\u{2705} Event veröffentlicht!'),
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
        title: const Text('Event eintragen'),
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
                label: const Text('Zurück'),
              )
            else
              const Spacer(),
            const Spacer(),
            if (_step < 2)
              FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Weiter'),
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
        Text('Ich bin...',
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
        Text('Kategorie *',
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
        Text('Altersgruppe *',
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
          title: Text('Wiederkehrendes Event',
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
          title: Text('Private Adresse (nur Stadtteil zeigen)',
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
          title: Text('Kostenlos',
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
        Text('Indoor / Outdoor',
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
        Text('Barrierefreiheit (optional)',
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
        Text('Event-Sprache',
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
        Text('Kontakt (optional)',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Wird nur Interessierten angezeigt.',
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
