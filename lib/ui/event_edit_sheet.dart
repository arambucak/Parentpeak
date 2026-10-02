import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/models/meetup_event.dart';

class EventEditSheet extends StatefulWidget {
  const EventEditSheet({super.key, required this.event, required this.onSave});
  final MeetupEvent event;
  final Future<MeetupEvent> Function(Map<String, dynamic> fields) onSave;

  @override
  State<EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<EventEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late DateTime _date;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _description = TextEditingController(text: widget.event.description);
    _location = TextEditingController(text: widget.event.location);
    _capacity = TextEditingController(text: '${widget.event.maxParticipants}');
    _date = widget.event.eventDate.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr('event_owner_required')
      : null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year + 10, 12, 31);
    final initialDate = _date.isBefore(today)
        ? today
        : _date.isAfter(lastDate)
        ? lastDate
        : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
    );
    if (!mounted || picked == null) return;
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted || picked == null) return;
    setState(
      () => _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!_date.isAfter(DateTime.now())) {
      setState(() => _error = context.tr('event_owner_future_date'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.onSave({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'startDate': _date.toUtc().toIso8601String(),
        'maxParticipants': int.parse(_capacity.text.trim()),
      });
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.tr('event_owner_save_failed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimumCapacity = widget.event.currentParticipants < 1
        ? 1
        : widget.event.currentParticipants;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('event_owner_edit_title'),
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          tooltip: context.tr('common_cancel'),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('event-edit-title'),
                      controller: _title,
                      enabled: !_busy,
                      maxLength: 200,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.tr('event_owner_title'),
                        border: fieldBorder,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('event-edit-description'),
                      controller: _description,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        labelText: context.tr('event_detail_description'),
                        border: fieldBorder,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('event-edit-location'),
                      controller: _location,
                      enabled: !_busy,
                      maxLength: 200,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.tr('event_owner_location'),
                        border: fieldBorder,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('event-edit-date'),
                          onPressed: _busy ? null : _pickDate,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(_date),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('event-edit-time'),
                          onPressed: _busy ? null : _pickTime,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            TimeOfDay.fromDateTime(_date).format(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('event-edit-capacity'),
                      controller: _capacity,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('event_owner_capacity'),
                        border: fieldBorder,
                      ),
                      validator: (value) {
                        final capacity = int.tryParse(value?.trim() ?? '');
                        return capacity == null || capacity < minimumCapacity
                            ? context.tr(
                                'event_owner_capacity_min',
                                values: {'count': minimumCapacity},
                              )
                            : null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('event-edit-save'),
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(context.tr('event_owner_save')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
