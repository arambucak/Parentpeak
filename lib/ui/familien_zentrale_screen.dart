import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// Familien-Zentrale — Einkauf + To-do + Kind-Dossier.
/// Besser als FamilyWall: Mengenangabe, Erledigt-Bereich, Kind-Infos.
class FamilienZentraleScreen extends StatefulWidget {
  const FamilienZentraleScreen({super.key});

  @override
  State<FamilienZentraleScreen> createState() => _FamilienZentraleScreenState();
}

class _FamilienZentraleScreenState extends State<FamilienZentraleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _shopping = ShoppingListService.instance;
  final _dossierService = KindDossierService.instance;
  final _inputCtrl = TextEditingController();
  final _todoCtrl = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _inputCtrl.dispose();
    _todoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _shopping.load();
      await _dossierService.load();
      if (_dossierService.dossiers.isEmpty) await _initDossiersFromProfile();
      await _loadTodos();
    } catch (e) {
      debugPrint('FamilienZentrale._load() Fehler: $e');
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _initDossiersFromProfile() async {
    try {
      final profile = await FamilyMatchProfile.load();
      if (profile != null && profile.children.isNotEmpty) {
        for (final child in profile.children) {
          final exams = UExaminationData.generateForChild(child.ageMonths);
          await _dossierService.addOrUpdate(KindDossier(
            childName: child.name.isNotEmpty ? child.name : 'Kind',
            ageMonths: child.ageMonths,
            uExams: exams,
          ));
        }
      }
    } catch (e) {
      debugPrint('FamilienZentrale._initDossiersFromProfile() Fehler: $e');
    }
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('zentrale.todos');
    if (raw != null && raw.isNotEmpty) {
      try {
        _todos = List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zentrale.todos', jsonEncode(_todos));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Familien-Zentrale')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familien-Zentrale'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.shopping_cart_rounded, size: 20),
                text: 'Einkauf'),
            Tab(icon: Icon(Icons.task_alt_rounded, size: 20), text: 'To-do'),
            Tab(icon: Icon(Icons.child_care_rounded, size: 20), text: 'Kinder'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _einkaufTab(theme),
          _todoTab(theme),
          _kinderTab(theme),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: EINKAUF
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _einkaufTab(ThemeData theme) {
    final active = _shopping.activeItems;
    final done = _shopping.doneItems;
    final frequent = _shopping.frequentItems;

    return Column(children: [
      // Eingabe
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: _inputCtrl,
            decoration: InputDecoration(
              hintText: 'z.B. "3x Milch" oder "Nudeln 500g"',
              hintStyle:
                  TextStyle(fontSize: 13, color: theme.colorScheme.outline),
              prefixIcon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
              isDense: true,
            ),
            onSubmitted: (_) => _addShoppingItem(),
          )),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _addShoppingItem,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Icon(Icons.add_rounded),
          ),
        ]),
      ),
      // Haeufig gekauft
      if (frequent.isNotEmpty && active.length < 3)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: frequent.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final name = frequent[i];
                  return ActionChip(
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    onPressed: () async {
                      await _shopping.addItem(ShoppingItem.fromInput(name));
                      setState(() {});
                    },
                    avatar: const Icon(Icons.add_rounded, size: 14),
                    visualDensity: VisualDensity.compact,
                  );
                },
              )),
        ),
      // Aktive Items
      Expanded(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          ...active.map((item) => _shoppingItemTile(theme, item, false)),
          if (done.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text('Erledigt (${done.length})',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            ...done.map((item) => _shoppingItemTile(theme, item, true)),
          ],
        ],
      )),
    ]);
  }

  Widget _shoppingItemTile(ThemeData theme, ShoppingItem item, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: () async {
          await _shopping.toggleDone(item.id);
          setState(() {});
        },
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
                color: isDone
                    ? const Color(0xFF16A34A)
                    : theme.colorScheme.outline,
                width: 1.5),
          ),
          child: isDone
              ? const Icon(Icons.check_rounded,
                  size: 16, color: Color(0xFF16A34A))
              : null,
        ),
        title: Text(
          '${item.emoji} ${item.name}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? theme.colorScheme.outline : null,
          ),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (item.quantity != null)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(item.quantity!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6)))),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              await _shopping.removeItem(item.id);
              setState(() {});
            },
            child: Icon(Icons.close_rounded,
                size: 16, color: theme.colorScheme.outline),
          ),
        ]),
      ),
    );
  }

  void _addShoppingItem() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final item = ShoppingItem.fromInput(text);
    await _shopping.addItem(item);
    _inputCtrl.clear();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: TO-DO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _todoTab(ThemeData theme) {
    final pending = _todos.where((t) => t['done'] != true).toList();
    final done = _todos.where((t) => t['done'] == true).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: _todoCtrl,
            decoration: InputDecoration(
              hintText: 'Neue Aufgabe...',
              prefixIcon: const Icon(Icons.add_task_rounded, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              isDense: true,
            ),
            onSubmitted: (_) => _addTodo(),
          )),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _addTodo,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Icon(Icons.add_rounded),
          ),
        ]),
      ),
      Expanded(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          ...pending.map((t) => _todoTile(theme, t, false)),
          if (done.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text('Erledigt (${done.length})',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            ...done.map((t) => _todoTile(theme, t, true)),
          ],
        ],
      )),
    ]);
  }

  Widget _todoTile(ThemeData theme, Map<String, dynamic> todo, bool isDone) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: GestureDetector(
        onTap: () {
          todo['done'] = !(todo['done'] ?? false);
          _saveTodos();
          setState(() {});
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
                color: isDone
                    ? const Color(0xFF2563EB)
                    : theme.colorScheme.outline,
                width: 1.5),
          ),
          child: isDone
              ? const Icon(Icons.check_rounded,
                  size: 16, color: Color(0xFF2563EB))
              : null,
        ),
      ),
      title: Text(
        todo['text'] ?? '',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          decoration: isDone ? TextDecoration.lineThrough : null,
          color: isDone ? theme.colorScheme.outline : null,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.close_rounded,
            size: 16, color: theme.colorScheme.outline),
        onPressed: () {
          _todos.remove(todo);
          _saveTodos();
          setState(() {});
        },
      ),
    );
  }

  void _addTodo() {
    final text = _todoCtrl.text.trim();
    if (text.isEmpty) return;
    _todos.insert(0, {
      'text': text,
      'done': false,
      'id': DateTime.now().millisecondsSinceEpoch
    });
    _todoCtrl.clear();
    _saveTodos();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: KINDER (Dossier)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _kinderTab(ThemeData theme) {
    final dossiers = _dossierService.dossiers;

    if (dossiers.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('\u{1F476}', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text('Noch keine Kinder-Daten',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'Erstelle ein Profil im Eltern-Netzwerk um das Kind-Dossier zu nutzen.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center),
        ]),
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: dossiers.length,
      itemBuilder: (_, i) => _dossierCard(theme, dossiers[i]),
    );
  }

  Widget _dossierCard(ThemeData theme, KindDossier dossier) {
    final ageYears = (dossier.ageMonths / 12).round();
    final nextExam = dossier.uExams
        .where((u) => !u.isDone && u.dueAtMonths <= dossier.ageMonths + 6)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: Text(
                    ageYears < 2
                        ? '\u{1F476}'
                        : ageYears < 6
                            ? '\u{1F9D2}'
                            : '\u{1F466}',
                    style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(dossier.childName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('$ageYears Jahre',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ])),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: () => _editDossier(dossier),
          ),
        ]),
        const SizedBox(height: 14),
        // Quick-Infos
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (dossier.clothingSize != null)
            _infoChip('\u{1F455} Gr. ${dossier.clothingSize}',
                const Color(0xFF2563EB)),
          if (dossier.shoeSize != null)
            _infoChip(
                '\u{1F45F} Schuh ${dossier.shoeSize}', const Color(0xFF8B5CF6)),
          if (dossier.allergies.isNotEmpty)
            _infoChip('\u{26A0}\u{FE0F} ${dossier.allergies.join(", ")}',
                const Color(0xFFDC2626)),
          if (dossier.kitaSchool != null)
            _infoChip(
                '\u{1F3EB} ${dossier.kitaSchool}', const Color(0xFF0EA5A4)),
        ]),
        // U-Untersuchung Hinweis
        if (nextExam.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Text('\u{1F3E5}', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Faellig: ${nextExam.first.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E)),
              )),
            ]),
          ),
        ],
        // Notfall-Button
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showNotfallInfo(theme, dossier),
              icon: const Icon(Icons.local_hospital_rounded, size: 16),
              label: const Text('Notfall-Info anzeigen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: BorderSide(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
      ]),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ─── Notfall-Info ─────────────────────────────────────────────────────────

  void _showNotfallInfo(ThemeData theme, KindDossier d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('\u{1F6A8}', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text('Notfall-Info: ${d.childName}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _notfallRow(
              '\u{1F9EC} Blutgruppe', d.bloodType ?? 'Nicht eingetragen'),
          _notfallRow(
              '\u{26A0}\u{FE0F} Allergien',
              d.allergies.isNotEmpty
                  ? d.allergies.join(', ')
                  : 'Keine bekannt'),
          _notfallRow(
              '\u{1F3E5} Kinderarzt', d.doctorName ?? 'Nicht eingetragen'),
          _notfallRow('\u{1F4DE} Arzt-Tel.', d.doctorPhone ?? '—'),
          _notfallRow('\u{1F4F1} Notfall-Kontakt', d.emergencyContact ?? '—'),
          _notfallRow('\u{1F4DE} Notfall-Tel.', d.emergencyPhone ?? '—'),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Schliessen'),
              )),
        ]),
      ),
    );
  }

  Widget _notfallRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  // ─── Dossier bearbeiten ───────────────────────────────────────────────────

  void _editDossier(KindDossier dossier) {
    final clothingCtrl =
        TextEditingController(text: dossier.clothingSize ?? '');
    final shoeCtrl = TextEditingController(text: dossier.shoeSize ?? '');
    final allergiesCtrl =
        TextEditingController(text: dossier.allergies.join(', '));
    final doctorCtrl = TextEditingController(text: dossier.doctorName ?? '');
    final doctorPhoneCtrl =
        TextEditingController(text: dossier.doctorPhone ?? '');
    final bloodCtrl = TextEditingController(text: dossier.bloodType ?? '');
    final emergCtrl =
        TextEditingController(text: dossier.emergencyContact ?? '');
    final emergPhoneCtrl =
        TextEditingController(text: dossier.emergencyPhone ?? '');
    final kitaCtrl = TextEditingController(text: dossier.kitaSchool ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('${dossier.childName} bearbeiten',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _editField(clothingCtrl, 'Kleidergroesse', 'z.B. 110'),
              _editField(shoeCtrl, 'Schuhgroesse', 'z.B. 28'),
              _editField(allergiesCtrl, 'Allergien (kommagetrennt)',
                  'z.B. Nuesse, Laktose'),
              _editField(doctorCtrl, 'Kinderarzt Name', 'z.B. Dr. Mueller'),
              _editField(doctorPhoneCtrl, 'Kinderarzt Telefon', '030 123456'),
              _editField(bloodCtrl, 'Blutgruppe', 'z.B. A+'),
              _editField(emergCtrl, 'Notfall-Kontakt (Name)', 'z.B. Oma Helga'),
              _editField(emergPhoneCtrl, 'Notfall-Telefon', '0170 ...'),
              _editField(kitaCtrl, 'Kita / Schule', 'z.B. Kita Sonnenschein'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final updated = KindDossier(
                    childName: dossier.childName,
                    ageMonths: dossier.ageMonths,
                    clothingSize: clothingCtrl.text.trim().isEmpty
                        ? null
                        : clothingCtrl.text.trim(),
                    shoeSize: shoeCtrl.text.trim().isEmpty
                        ? null
                        : shoeCtrl.text.trim(),
                    allergies: allergiesCtrl.text.trim().isEmpty
                        ? []
                        : allergiesCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                    doctorName: doctorCtrl.text.trim().isEmpty
                        ? null
                        : doctorCtrl.text.trim(),
                    doctorPhone: doctorPhoneCtrl.text.trim().isEmpty
                        ? null
                        : doctorPhoneCtrl.text.trim(),
                    bloodType: bloodCtrl.text.trim().isEmpty
                        ? null
                        : bloodCtrl.text.trim(),
                    emergencyContact: emergCtrl.text.trim().isEmpty
                        ? null
                        : emergCtrl.text.trim(),
                    emergencyPhone: emergPhoneCtrl.text.trim().isEmpty
                        ? null
                        : emergPhoneCtrl.text.trim(),
                    kitaSchool: kitaCtrl.text.trim().isEmpty
                        ? null
                        : kitaCtrl.text.trim(),
                    uExams: dossier.uExams,
                  );
                  await _dossierService.addOrUpdate(updated);
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
    );
  }
}
