import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/logic/event_backend_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/models/family_contact.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/logic/auth_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventService = EventService();

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  final _familyCircleService = FamilyCircleService.instance;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _maxParticipantsController;

  EventCategory _selectedCategory = EventCategory.socialGathering;
  final List<AgeGroup> _selectedAgeGroups = [];
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  final double _latitude = 52.5200;
  final double _longitude = 13.4050;
  EventVisibility _visibility = EventVisibility.publicNearby;
  double _shareRadiusKm = 25;
  int _inviteCodeExpiryDays = 14;
  List<FamilyContact> _familyContacts = [];
  final Set<String> _selectedInvitees = {};

  bool _isSubmitting = false;
  File? _selectedPhotoFile;
  String? _uploadedPhotoUrl;
  final _imagePicker = ImagePicker();
  final _eventBackendService = EventBackendService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController(text: 'Berlin, Deutschland');
    _maxParticipantsController = TextEditingController(text: '10');
    _loadFamilyContacts();
    if (!FeatureFlags.enableFamilyCircle &&
        _visibility == EventVisibility.familyCircle) {
      _visibility = EventVisibility.publicNearby;
    }
  }

  Future<void> _loadFamilyContacts() async {
    final userId = AuthService.instance.currentUser?.uid;
    if (userId == null || userId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _familyContacts = [];
      });
      return;
    }
    final contacts =
        await _familyCircleService.getConnectedContacts(userId: userId);
    if (!mounted) return;
    setState(() {
      _familyContacts = contacts;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _toggleAgeGroup(AgeGroup ageGroup) {
    setState(() {
      if (_selectedAgeGroups.contains(ageGroup)) {
        _selectedAgeGroups.remove(ageGroup);
      } else {
        _selectedAgeGroups.add(ageGroup);
      }
    });
  }

  void _toggleInvitee(String userId) {
    setState(() {
      if (_selectedInvitees.contains(userId)) {
        _selectedInvitees.remove(userId);
      } else {
        _selectedInvitees.add(userId);
      }
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _selectedPhotoFile = File(picked.path);
      _uploadedPhotoUrl = null;
    });
  }

  Future<String> _ensurePhotoUploaded() async {
    if (_selectedPhotoFile == null) return '';
    if (_uploadedPhotoUrl != null) return _uploadedPhotoUrl!;
    final url = await _eventBackendService.uploadImage(_selectedPhotoFile!);
    _uploadedPhotoUrl = url ?? '';
    return _uploadedPhotoUrl!;
  }

  Future<void> _submitForm() async {
    final currentUserId = AuthService.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('event_login_required'))),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedAgeGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('event_select_age_group'))),
      );
      return;
    }

    if (_visibility == EventVisibility.inviteOnly &&
        _selectedInvitees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('event_invite_contact')),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Erstelle Event-Objekt
      final eventDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final photoUrl = await _ensurePhotoUploaded();

      final event = MeetupEvent(
        id: 'event_${DateTime.now().millisecondsSinceEpoch}',
        hosterId: currentUserId,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        ageGroups: _selectedAgeGroups,
        location: _locationController.text,
        latitude: _latitude,
        longitude: _longitude,
        eventDate: eventDateTime,
        createdAt: DateTime.now(),
        maxParticipants: int.parse(_maxParticipantsController.text),
        photoUrl: photoUrl,
        status: EventStatus.active,
        price: null,
        visibility: _visibility,
        shareRadiusKm:
            _visibility == EventVisibility.publicNearby ? _shareRadiusKm : null,
        invitedUserIds: _visibility == EventVisibility.inviteOnly
            ? _selectedInvitees.toList()
            : const [],
        inviteCodeExpiresAt: _visibility == EventVisibility.inviteOnly
            ? DateTime.now().add(Duration(days: _inviteCodeExpiryDays))
            : null,
      );

      await _eventService.createEvent(event);

      if (mounted) {
        if (_visibility == EventVisibility.inviteOnly) {
          final code = _eventService.getInviteCodeForEvent(event.id);
          final link = _eventService.getInviteLinkForEvent(event.id);
          final expiresAt = _eventService.getInviteExpiryForEvent(event.id);
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'event_ready')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('event_created_success')),
                  const SizedBox(height: 10),
                  if (code != null) ...[
                    Text(_t('your_code')),
                    const SizedBox(height: 4),
                    SelectableText(
                      code,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (link != null) ...[
                    Text(_t('your_link')),
                    const SizedBox(height: 4),
                    SelectableText(link),
                    const SizedBox(height: 10),
                  ],
                  if (expiresAt != null)
                    Text(
                      'Gültig bis: ${expiresAt.day.toString().padLeft(2, '0')}.${expiresAt.month.toString().padLeft(2, '0')}.${expiresAt.year}',
                    ),
                  if (expiresAt != null) const SizedBox(height: 8),
                  if (expiresAt != null)
                    const Text(
                      'Bereits akzeptierte Einladungen bleiben aktiv.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                ],
              ),
              actions: [
                if (code != null)
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.of(context).pop();
                    },
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'copy_code_close')),
                  ),
                if (link != null)
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      Navigator.of(context).pop();
                    },
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'copy_link_close')),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t('event_next')),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('event_is_live'))),
          );
        }

        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konnte nicht speichern: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'create_event')),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5FBFA), Color(0xFFF9FAFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Erstelle ein Event in wenigen Schritten und entscheide, ob es privat oder öffentlich geteilt wird.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Titel
                Text(
                  'Grundinformationen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event-Titel',
                    hintText: 'z. B. Spielplatz-Treffen',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Bitte einen Titel eingeben';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    hintText: 'Was macht euer Event besonders?',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Bitte eine Beschreibung eingeben';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Sichtbarkeit & Standortverteilung
                Text(
                  'Sichtbarkeit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                _VisibilityOptionTile(
                  title: 'Öffentlich (in deiner Nähe sichtbar)',
                  subtitle:
                      'Andere Eltern sehen dein Event im Standort-Radius.',
                  selected: _visibility == EventVisibility.publicNearby,
                  onTap: () => setState(
                    () => _visibility = EventVisibility.publicNearby,
                  ),
                ),
                if (FeatureFlags.enableFamilyCircle)
                  _VisibilityOptionTile(
                    title: 'Familienkreis (für deine Kontakte sichtbar)',
                    subtitle:
                        'Nur verbundene Eltern aus deinem Familienkreis sehen das Event.',
                    selected: _visibility == EventVisibility.familyCircle,
                    onTap: () => setState(
                      () => _visibility = EventVisibility.familyCircle,
                    ),
                  ),
                _VisibilityOptionTile(
                  title: 'Nur eingeladen (individuelle Einladungen)',
                  subtitle:
                      'Nur ausgewählte Kontakte sehen und erhalten die Einladung.',
                  selected: _visibility == EventVisibility.inviteOnly,
                  onTap: () => setState(
                    () => _visibility = EventVisibility.inviteOnly,
                  ),
                ),
                _VisibilityOptionTile(
                  title: 'Nur ich (nicht geteilt)',
                  subtitle: 'Das Event bleibt nur in deinem Bereich sichtbar.',
                  selected: _visibility == EventVisibility.privateOnly,
                  onTap: () => setState(
                    () => _visibility = EventVisibility.privateOnly,
                  ),
                ),

                if (_visibility == EventVisibility.publicNearby) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Öffentlich teilen im Umkreis',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${_shareRadiusKm.toStringAsFixed(0)} km',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    value: _shareRadiusKm,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${_shareRadiusKm.toStringAsFixed(0)} km',
                    onChanged: (v) => setState(() => _shareRadiusKm = v),
                  ),
                ],

                if (_visibility == EventVisibility.inviteOnly) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Kontakte auswählen',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_familyContacts.isEmpty)
                    const Text(
                      'Noch keine Kontakte verfügbar. Diese Funktion wird bald wieder freigeschaltet.',
                    )
                  else
                    ..._familyContacts.map(
                      (contact) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _selectedInvitees.contains(contact.userId),
                        title: Text(contact.displayName),
                        subtitle: Text(
                            '${contact.city} · ${contact.childrenSummary}'),
                        onChanged: (_) => _toggleInvitee(contact.userId),
                      ),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _inviteCodeExpiryDays,
                    decoration: const InputDecoration(
                      labelText: 'Einladungscode gültig für',
                      prefixIcon: Icon(Icons.timelapse_rounded),
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 Tage')),
                      DropdownMenuItem(value: 7, child: Text('7 Tage')),
                      DropdownMenuItem(value: 14, child: Text('14 Tage')),
                      DropdownMenuItem(value: 30, child: Text('30 Tage')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _inviteCodeExpiryDays = value);
                    },
                  ),
                ],

                const SizedBox(height: 16),

                // Kategorie
                DropdownButtonFormField<EventCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    prefixIcon: Icon(Icons.category),
                  ),
                  isExpanded: true,
                  items: EventCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(_getCategoryLabel(category)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Altersgruppen
                Text(
                  'Zielgruppe (Altersgruppen)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AgeGroup.values
                      .map(
                        (ageGroup) => FilterChip(
                          label: Text(_getAgeGroupLabel(ageGroup)),
                          selected: _selectedAgeGroups.contains(ageGroup),
                          onSelected: (_) => _toggleAgeGroup(ageGroup),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),

                // Datum & Zeit
                Text(
                  'Termin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                        ),
                        onTap: _selectDate,
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        ),
                        onTap: _selectTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ort
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Treffpunkt',
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'z.B. Zentralpark, Berlin',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Bitte einen Ort eingeben';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Max Teilnehmer
                TextFormField(
                  controller: _maxParticipantsController,
                  decoration: const InputDecoration(
                    labelText: 'Maximale Teilnehmerzahl',
                    prefixIcon: Icon(Icons.people),
                    hintText: '10',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Bitte eine Zahl eingeben';
                    }
                    if (int.tryParse(value!) == null) {
                      return 'Bitte nur Zahlen eingeben';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Text(
                  'Event-Foto (optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _selectedPhotoFile == null
                        ? 'Foto auswählen'
                        : 'Foto ändern',
                  ),
                ),
                if (_selectedPhotoFile != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedPhotoFile!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _uploadedPhotoUrl == null
                              ? 'Das Foto wird beim Veröffentlichen hochgeladen.'
                              : 'Foto bereits hochgeladen.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _selectedPhotoFile = null;
                                  _uploadedPhotoUrl = null;
                                });
                              },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(_t('circle_remove')),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // Kostenhinweis
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF047857)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Event-Veröffentlichung ist in deinem App-Abo enthalten.',
                          style: TextStyle(color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitForm,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'publish_event')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(EventCategory category) {
    const labels = {
      EventCategory.sports: 'Sport',
      EventCategory.outdoor: 'Outdoor',
      EventCategory.education: 'Bildung',
      EventCategory.arts: 'Kunst',
      EventCategory.socialGathering: 'Treffen',
      EventCategory.other: 'Sonstiges',
    };
    return labels[category] ?? 'Sonstiges';
  }

  String _getAgeGroupLabel(AgeGroup ageGroup) {
    const labels = {
      AgeGroup.infant: 'Baby (0-1)',
      AgeGroup.toddler: 'Kleinkind (1-3)',
      AgeGroup.preschool: 'Vorschule (3-5)',
      AgeGroup.elementary: 'Grundschule (6-12)',
      AgeGroup.teenager: 'Teenager (13+)',
      AgeGroup.mixed: 'Altersgemischt',
    };
    return labels[ageGroup] ?? '';
  }
}

class _VisibilityOptionTile extends StatelessWidget {
  const _VisibilityOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
