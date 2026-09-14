import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:flutter/services.dart';

import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/services/tischmoment_service.dart';

/// "Unser Tischmoment" — ein sanftes Abend-Ritual am Familientisch.
///
/// Eine Frage pro Tag, kindgerechte Herz-Symbole, optional pro Kind. Alle
/// Einträge bleiben AUSSCHLIESSLICH lokal auf dem Gerät (private Schatzkiste).
class TischmomentScreen extends StatefulWidget {
  const TischmomentScreen({super.key});

  @override
  State<TischmomentScreen> createState() => _TischmomentScreenState();
}

class _TischmomentScreenState extends State<TischmomentScreen> {
  static const _accent = Color(0xFF7C3AED);

  final _noteCtrl = TextEditingController();

  final String _question = Tischmoment.questionOfTheDay();
  List<String> _childNames = [];
  String? _selectedChild; // null = für die ganze Familie
  String? _selectedFeeling;
  bool _saving = false;

  List<TischmomentEntry> _entries = [];
  bool _showTreasure = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final profile = await FamilyMatchProfile.load();
      final names = (profile?.children ?? [])
          .map((c) => c.name.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      if (mounted) setState(() => _childNames = names);
    } catch (_) {}
    await _reloadEntries();
  }

  Future<void> _reloadEntries() async {
    final all = await TischmomentService.loadAll();
    if (mounted) setState(() => _entries = all);
  }

  Future<void> _save() async {
    if (_selectedFeeling == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('table_moment_select_feeling')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    final entry = TischmomentEntry(
      id: 'tm-${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      childName: _selectedChild ?? '',
      question: _question,
      feelingKey: _selectedFeeling!,
      note: _noteCtrl.text.trim(),
    );
    await TischmomentService.add(entry);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    _noteCtrl.clear();
    setState(() {
      _selectedFeeling = null;
      _selectedChild = null;
      _saving = false;
    });
    await _reloadEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.tr('table_moment_saved')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF16A34A),
    ));
  }

  Future<void> _deleteEntry(TischmomentEntry e) async {
    await TischmomentService.delete(e.id);
    await _reloadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('table_moment_title')),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showTreasure
                ? Icons.edit_note_rounded
                : Icons.auto_awesome_rounded),
            tooltip: context.tr(_showTreasure
              ? 'table_moment_new'
              : 'table_moment_treasure'),
            onPressed: () => setState(() => _showTreasure = !_showTreasure),
          ),
        ],
      ),
      body: _showTreasure ? _treasureView(theme) : _captureView(theme),
    );
  }

  // ─── Neuen Moment festhalten ────────────────────────────────────────────
  Widget _captureView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🕯️ Frage des Tages',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(_question,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Kind-Auswahl (optional)
          if (_childNames.isNotEmpty) ...[
            Text(context.tr('table_moment_for_whom'),
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _childChip(context.tr('table_moment_whole_family'), _selectedChild == null,
                    () => setState(() => _selectedChild = null)),
                ..._childNames.map((n) => _childChip(
                    n, _selectedChild == n, () => setState(() => _selectedChild = n))),
              ],
            ),
            const SizedBox(height: 24),
          ],

          Text(context.tr('table_moment_how_was_it'),
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...Tischmoment.feelings.map((f) => _feelingTile(theme, f)),
          const SizedBox(height: 20),

          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.tr('table_moment_note_label'),
              hintText: context.tr('table_moment_note_hint'),
              alignLabelWithHint: true,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.favorite_rounded),
              label: Text(context.tr('table_moment_save')),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _privacyHint(theme),
        ],
      ),
    );
  }

  Widget _childChip(String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: _accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: active ? _accent : theme.colorScheme.onSurface,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
          color: active ? _accent : theme.colorScheme.outlineVariant),
      backgroundColor: theme.colorScheme.surface,
    );
  }

  Widget _feelingTile(ThemeData theme, TischmomentFeeling f) {
    final active = _selectedFeeling == f.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active
            ? _accent.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _selectedFeeling = f.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(f.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(f.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? _accent : null)),
                ),
                if (active)
                  const Icon(Icons.check_circle_rounded, color: _accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyHint(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_rounded, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Text(context.tr('table_moment_local_only'),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  // ─── Schatzkiste ──────────────────────────────────────────────────────────
  Widget _treasureView(ThemeData theme) {
    final travel = TischmomentService.timeTravel(_entries);
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎁', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 16),
              Text(context.tr('table_moment_empty'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                context.tr('table_moment_empty_hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        if (travel.isNotEmpty) ...[
          _timeTravelSection(theme, travel),
          const SizedBox(height: 20),
        ],
        Text(context.tr('table_moment_yours'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ..._entries.map((e) => _entryCard(theme, e)),
        const SizedBox(height: 16),
        Center(child: _privacyHint(theme)),
      ],
    );
  }

  Widget _timeTravelSection(ThemeData theme, List<TischmomentEntry> travel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏳', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Kleine Zeitreise',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: _accent)),
            ],
          ),
          const SizedBox(height: 10),
          ...travel.map((e) {
            final who = e.childName.isNotEmpty ? e.childName : 'Ihr';
            final feeling = Tischmoment.feelingByKey(e.feelingKey);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_relativeAgo(e.createdAt)} hat sich $who gefreut: '
                '${feeling.emoji} ${feeling.label.toLowerCase()}'
                '${e.note.isNotEmpty ? ' – „${e.note}“' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _entryCard(ThemeData theme, TischmomentEntry e) {
    final feeling = Tischmoment.feelingByKey(e.feelingKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feeling.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.childName.isNotEmpty
                            ? e.childName
                            : 'Ganze Familie',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(_formatDate(e.createdAt),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(feeling.label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: _accent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.question,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                if (e.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('„${e.note}“',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic, height: 1.4)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: theme.colorScheme.outline),
            tooltip: context.tr('tooltip_remove'),
            onPressed: () => _confirmDelete(e),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(TischmomentEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('table_moment_delete_title')),
        content: Text(context.tr('table_moment_delete_message')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('common_cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _accent),
              child: Text(context.tr('tooltip_remove'))),
        ],
      ),
    );
    if (ok == true) await _deleteEntry(e);
  }

  // ─── Datums-Helfer ────────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Heute';
    if (diff == 1) return 'Gestern';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _relativeAgo(DateTime dt) {
    final now = DateTime.now();
    final months = (now.year - dt.year) * 12 + (now.month - dt.month);
    if (months >= 12) return 'Vor einem Jahr';
    if (months >= 1) return 'Vor einem Monat';
    return 'Vor Kurzem';
  }
}
