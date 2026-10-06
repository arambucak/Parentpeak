import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/family_hub_migration.dart';
import 'package:parentpeak/ui/widgets/family_hub_account_boundary.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

/// Familien-Zentrale — Einkauf + To-do + Kind-Dossier.
/// Besser als FamilyWall: Mengenangabe, Erledigt-Bereich, Kind-Infos.
class FamilienZentraleScreen extends StatelessWidget {
  const FamilienZentraleScreen({super.key});

  @override
  Widget build(BuildContext context) => FamilyHubAccountBoundary(
        builder: (_) => const _ScopedFamilienZentraleScreen(),
      );
}

class _ScopedFamilienZentraleScreen extends StatefulWidget {
  const _ScopedFamilienZentraleScreen();

  @override
  State<_ScopedFamilienZentraleScreen> createState() => _FamilienZentraleScreenState();
}

class _FamilienZentraleScreenState extends State<_ScopedFamilienZentraleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _shopping = ShoppingListService.instance;
  final _dossierService = KindDossierService.instance;
  final _inputCtrl = TextEditingController();
  final _todoCtrl = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  bool _loaded = false;
  bool _loadError = false;
  int _activeTabIndex = 0;
  final _store = FamilyHubStore.instance;
  late final String _scope = _store.scope;
  bool _hasLegacy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() => _activeTabIndex = _tabs.index);
    });
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
      _store.requireScope(_scope);
      await _dossierService.load();
      _store.requireScope(_scope);
      // Kinder aus dem Eltern-Netzwerk-Profil nachziehen (auch wenn schon
      // Dossiers existieren) — so landen neu angelegte Kinder zuverlässig hier.
      await _syncDossiersFromProfile();
      await _loadTodos();
      _hasLegacy = await _store.hasUnassignedLegacy();
      _store.requireScope(_scope);
      _loadError = false;
    } catch (e) {
      debugPrint('FamilienZentrale._load() Fehler: $e');
      _loadError = true;
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// Legt für jedes Kind aus dem Profil ein Dossier an, das noch keines hat
  /// (per Name abgeglichen). Bestehende Dossiers bleiben unangetastet — es wird
  /// also nichts überschrieben, nur Fehlendes ergänzt.
  Future<void> _syncDossiersFromProfile() async {
    try {
      final profile = await FamilyMatchProfile.load();
      _store.requireScope(_scope);
      if (profile == null || profile.children.isEmpty) return;
      for (final child in profile.children) {
        final name = child.name.isNotEmpty ? child.name : 'Kind';
        if (_dossierService.findByName(name) != null) continue;
        await _dossierService.addOrUpdate(KindDossier(
          childName: name,
          ageMonths: child.ageMonths,
          uExams: UExaminationData.generateForChild(child.ageMonths),
        ), expectedScope: _scope);
      }
    } catch (e) {
      debugPrint('FamilienZentrale._syncDossiersFromProfile() Fehler: $e');
    }
  }

  Future<void> _loadTodos() async {
    _todos = [];
    final data = await _store.read(expectedScope: _scope);
    _todos = (data[FamilyHubStore.todoKey] as List? ?? [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<void> _saveTodos() async {
    try {
      await _store.write({FamilyHubStore.todoKey: _todos}, expectedScope: _scope);
    } catch (e) {
      debugPrint('FamilienZentrale._saveTodos() Fehler: $e');
    }
  }

    Future<void> _claimLegacy() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => FamilyHubAccountModal(
          expectedScope: _scope,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('family_hub_legacy_title')),
            content: Text(context.tr('family_hub_legacy_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('family_hub_legacy_claim')),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        await claimFamilyHubLegacy(expectedScope: _scope);
        if (!mounted) return;
        setState(() => _loaded = false);
        await _load();
      } catch (error) {
        debugPrint('FamilienZentrale legacy claim: $error');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('family_hub_legacy_failed'))),
        );
      }
    }

  /// Anzahl fälliger oder überfälliger U-Untersuchungen über alle Kinder.
  int get _urgentExamCount {
    if (!_loaded) return 0;
    return _dossierService.dossiers.fold(0, (count, d) {
      return count +
          d.uExams
              .where((u) => !u.isDone && u.dueAtMonths <= d.ageMonths + 3)
              .length;
    });
  }

  void _shareShoppingList() {
    final items = _shopping.activeItems;
    if (items.isEmpty) return;
    final lines = items
        .map((i) => '• ${i.emoji} ${i.name}'
            '${i.quantity != null ? ' (${i.quantity})' : ''}')
        .join('\n');
    final title = context.tr('family_hub_shopping_list');
    Share.share('🛒 $title\n\n$lines', subject: title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(
            title: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'familien_zentrale_title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError) {
      return Scaffold(
        appBar: AppBar(
            title: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'familien_zentrale_title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 40, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 14),
              Text(
                context.tr('family_hub_load_error'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _loaded = false);
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.tr('family_hub_retry')),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'familien_zentrale_title')),
        elevation: 0,
        actions: [
          if (_hasLegacy && _store.userId != null)
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: context.tr('family_hub_legacy_title'),
              onPressed: _claimLegacy,
            ),
          if (_activeTabIndex == 0 && _shopping.activeItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: context.tr('tooltip_share_list'),
              onPressed: _shareShoppingList,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
                icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                text: context.tr('family_hub_tab_shopping')),
            Tab(
                icon: const Icon(Icons.task_alt_rounded, size: 20),
                text: context.tr('family_hub_tab_todo')),
            Tab(
              child: SizedBox(
                height: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.child_care_rounded, size: 20),
                        if (_urgentExamCount > 0)
                          Positioned(
                            right: -5,
                            top: -3,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(context.tr('family_hub_tab_children'),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_hasLegacy)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(children: [
                Text(context.tr('family_hub_legacy_notice')),
                if (_store.userId != null)
                  TextButton(
                    onPressed: _claimLegacy,
                    child: Text(context.tr('family_hub_legacy_title')),
                  ),
              ]),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_einkaufTab(theme), _todoTab(theme), _kinderTab(theme)],
            ),
          ),
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
              hintText: context.tr('family_hub_shopping_hint'),
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
      // Häufig gekauft
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
                      _store.requireScope(_scope);
                      await _shopping.addItem(ShoppingItem.fromInput(name));
                      setState(() {});
                    },
                    avatar: const Icon(Icons.add_rounded, size: 14),
                    visualDensity: VisualDensity.compact,
                  );
                },
              )),
        ),
      // Liste
      Expanded(
          child: active.isEmpty && done.isEmpty
              ? _buildEmptyShoppingState(theme)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (active.isEmpty && done.isNotEmpty)
                      _buildAllDoneCelebration(theme),
                    ...active
                        .map((item) => _shoppingItemTile(theme, item, false)),
                    if (done.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 6),
                        child: Text(
                            '${AppStringsManager.getString(languageService.currentLanguage, "done_count")} (${done.length})',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ),
                      ...done
                          .map((item) => _shoppingItemTile(theme, item, true)),
                    ],
                  ],
                )),
    ]);
  }

  Widget _buildEmptyShoppingState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'list_empty'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'type_hint_shopping'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildAllDoneCelebration(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Text('🎉', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'all_shopping_done'),
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF166534))),
            Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'list_complete'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF166534))),
          ]),
        ),
      ]),
    );
  }

  Widget _shoppingItemTile(ThemeData theme, ShoppingItem item, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            onTap: () async {
              _store.requireScope(_scope);
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  _store.requireScope(_scope);
                  await _shopping.removeItem(item.id);
                  setState(() {});
                },
                child: Icon(Icons.close_rounded,
                    size: 16, color: theme.colorScheme.outline),
              ),
            ]),
          )),
    );
  }

  void _addShoppingItem() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final item = ShoppingItem.fromInput(text);
    _store.requireScope(_scope);
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
              hintText: context.tr('family_hub_todo_hint'),
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
              child: Text(
                  '${AppStringsManager.getString(languageService.currentLanguage, "completed")} (${done.length})',
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
        behavior: HitTestBehavior.opaque,
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
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'no_children_data'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(context.tr('family_hub_children_empty_hint'),
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
                Text(
                    context.tr('family_hub_age_years',
                        values: {'count': '$ageYears'}),
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
            _infoChip(
                '${context.tr('family_hub_clothing_size_short')} ${dossier.clothingSize}',
                const Color(0xFF2563EB)),
          if (dossier.shoeSize != null)
            _infoChip(
                '${context.tr('family_hub_shoe_size_short')} ${dossier.shoeSize}',
                const Color(0xFF8B5CF6)),
          if (dossier.allergies.isNotEmpty)
            _infoChip('\u{26A0}\u{FE0F} ${dossier.allergies.join(", ")}',
                const Color(0xFFDC2626)),
          if (dossier.kitaSchool != null)
            _infoChip(
                '\u{1F3EB} ${dossier.kitaSchool}', const Color(0xFF0EA5A4)),
          if (dossier.kitaGroup != null)
            _infoChip(
                '\u{1F46B} ${dossier.kitaGroup}', const Color(0xFF0EA5A4)),
          if (dossier.kitaTeacher != null)
            _infoChip('\u{1F9D1}\u{200D}\u{1F3EB} ${dossier.kitaTeacher}',
                const Color(0xFF0EA5A4)),
        ]),
        // Notizen (frei)
        if (dossier.notes != null && dossier.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('\u{1F4DD} ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(dossier.notes!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ]),
          ),
        ],
        // U-Untersuchungen: aufklappbar + abhakbar
        if (dossier.uExams.isNotEmpty) ...[
          const SizedBox(height: 12),
          _uExamsSection(theme, dossier, nextExam),
        ],
        // Notfall-Button
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showNotfallInfo(theme, dossier),
              icon: const Icon(Icons.local_hospital_rounded, size: 16),
              label: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'show_emergency_info')),
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

  /// Aufklappbare U-Untersuchungs-Liste eines Kindes. Jede Untersuchung ist
  /// abhakbar; fällige (noch offene) Untersuchungen sind farblich markiert.
  Widget _uExamsSection(
      ThemeData theme, KindDossier dossier, List<UExamination> dueExams) {
    final lang = languageService.currentLanguage;
    final openCount = dossier.uExams.where((u) => !u.isDone).length;
    final hasDue = dueExams.isNotEmpty;
    // Titel: nächste fällige Untersuchung hervorheben, sonst neutralen Stand.
    final subtitle = hasDue
        ? context.tr('family_hub_exam_due', values: {
            'exam': UExaminationData.localizedLabel(dueExams.first, lang)
          })
        : context.tr('family_hub_uexams_open', values: {'count': '$openCount'});

    return Theme(
      // ExpansionTile-Divider ausblenden, damit es sich in die Card einfügt.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: hasDue
              ? const Color(0xFFFEF3C7)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          leading: const Text('\u{1F3E5}', style: TextStyle(fontSize: 16)),
          title: Text(
            context.tr('family_hub_uexams_title'),
            style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: hasDue ? const Color(0xFF92400E) : null),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
                color: hasDue
                    ? const Color(0xFF92400E)
                    : theme.colorScheme.outline),
          ),
          children: dossier.uExams
              .map((exam) => _uExamTile(theme, dossier, exam, lang))
              .toList(),
        ),
      ),
    );
  }

  Widget _uExamTile(
      ThemeData theme, KindDossier dossier, UExamination exam, String lang) {
    final isDue = !exam.isDone && exam.dueAtMonths <= dossier.ageMonths + 6;
    String? doneLabel;
    if (exam.isDone && exam.doneDate != null) {
      final parsed = DateTime.tryParse(exam.doneDate!);
      if (parsed != null) {
        final d = parsed.toLocal();
        final dateStr =
            '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
        doneLabel =
            context.tr('family_hub_uexam_done_on', values: {'date': dateStr});
      }
    }
    return InkWell(
      onTap: () => _toggleUExam(dossier, exam),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(children: [
          Icon(
            exam.isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: exam.isDone
                ? const Color(0xFF16A34A)
                : (isDue ? const Color(0xFFD97706) : theme.colorScheme.outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                UExaminationData.localizedLabel(exam, lang),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: exam.isDone ? TextDecoration.lineThrough : null,
                  color: exam.isDone ? theme.colorScheme.outline : null,
                ),
              ),
              if (doneLabel != null)
                Text(doneLabel,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: const Color(0xFF16A34A))),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _toggleUExam(KindDossier dossier, UExamination exam) async {
    _store.requireScope(_scope);
    await _dossierService.setUExamDone(dossier.id, exam.id, !exam.isDone);
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
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
      builder: (ctx) => FamilyHubAccountModal(
        expectedScope: _scope,
        builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('\u{1F6A8}', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
              '${AppStringsManager.getString(languageService.currentLanguage, "emergency_info")}: ${d.childName}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _notfallRow(context.tr('family_hub_blood_type'),
              d.bloodType ?? context.tr('family_hub_not_entered')),
          _notfallRow(
              context.tr('family_hub_allergies'),
              d.allergies.isNotEmpty
                  ? d.allergies.join(', ')
                  : context.tr('family_hub_none_known')),
          _notfallRow(context.tr('family_hub_pediatrician'),
              d.doctorName ?? context.tr('family_hub_not_entered')),
          _notfallRow(
              context.tr('family_hub_doctor_phone'), d.doctorPhone ?? '—'),
          _notfallRow(context.tr('family_hub_emergency_contact'),
              d.emergencyContact ?? '—'),
          _notfallRow(context.tr('family_hub_emergency_phone'),
              d.emergencyPhone ?? '—'),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'close_btn')),
              )),
        ]),
        ),
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
    final nameCtrl = TextEditingController(text: dossier.childName);
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
    final kitaGroupCtrl = TextEditingController(text: dossier.kitaGroup ?? '');
    final kitaTeacherCtrl =
        TextEditingController(text: dossier.kitaTeacher ?? '');
    final notesCtrl = TextEditingController(text: dossier.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FamilyHubAccountModal(
        expectedScope: _scope,
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
              Text(
                  context.tr('family_hub_edit_child',
                      values: {'name': dossier.childName}),
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _editField(nameCtrl, context.tr('family_hub_child_name'),
                  context.tr('family_hub_child_name_hint')),
              _editField(clothingCtrl, context.tr('family_hub_clothing_size'),
                  context.tr('family_hub_clothing_hint')),
              _editField(shoeCtrl, context.tr('family_hub_shoe_size'),
                  context.tr('family_hub_shoe_hint')),
              _editField(allergiesCtrl, context.tr('family_hub_allergies_csv'),
                  context.tr('family_hub_allergies_hint')),
              _editField(doctorCtrl, context.tr('family_hub_pediatrician_name'),
                  context.tr('family_hub_pediatrician_hint')),
              _editField(
                  doctorPhoneCtrl,
                  context.tr('family_hub_pediatrician_phone'),
                  context.tr('family_hub_phone_hint')),
              _editField(bloodCtrl, context.tr('family_hub_blood_type_plain'),
                  context.tr('family_hub_blood_type_hint')),
              _editField(
                  emergCtrl,
                  context.tr('family_hub_emergency_contact_name'),
                  context.tr('family_hub_emergency_contact_hint')),
              _editField(
                  emergPhoneCtrl,
                  context.tr('family_hub_emergency_phone_plain'),
                  context.tr('family_hub_emergency_phone_hint')),
              _editField(kitaCtrl, context.tr('family_hub_daycare_school'),
                  context.tr('family_hub_daycare_hint')),
              _editField(kitaGroupCtrl, context.tr('family_hub_daycare_group'),
                  context.tr('family_hub_daycare_group_hint')),
              _editField(
                  kitaTeacherCtrl,
                  context.tr('family_hub_daycare_teacher'),
                  context.tr('family_hub_daycare_teacher_hint')),
              _editField(notesCtrl, context.tr('family_hub_notes'),
                  context.tr('family_hub_notes_hint'),
                  maxLines: 3),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  String? trimOrNull(String s) =>
                      s.trim().isEmpty ? null : s.trim();
                  // Namensfeld darf nicht leer gespeichert werden —
                  // sonst würde das Kind aus der Liste "verschwinden".
                  final newName = nameCtrl.text.trim().isEmpty
                      ? dossier.childName
                      : nameCtrl.text.trim();
                  // Direkter Konstruktor mit explizit übergebener id (statt
                  // copyWith): Das Formular setzt bewusst ALLE Felder, auch
                  // geleerte sollen auf null gehen. Die stabile Dossier-id wird
                  // weitergereicht, damit Umbenennen dasselbe Dossier
                  // aktualisiert statt ein zweites anzulegen. birthDate und
                  // uExams bleiben erhalten.
                  final updated = KindDossier(
                    id: dossier.id,
                    childName: newName,
                    birthDate: dossier.birthDate,
                    clothingSize: trimOrNull(clothingCtrl.text),
                    shoeSize: trimOrNull(shoeCtrl.text),
                    allergies: allergiesCtrl.text.trim().isEmpty
                        ? <String>[]
                        : allergiesCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                    doctorName: trimOrNull(doctorCtrl.text),
                    doctorPhone: trimOrNull(doctorPhoneCtrl.text),
                    bloodType: trimOrNull(bloodCtrl.text),
                    emergencyContact: trimOrNull(emergCtrl.text),
                    emergencyPhone: trimOrNull(emergPhoneCtrl.text),
                    kitaSchool: trimOrNull(kitaCtrl.text),
                    kitaGroup: trimOrNull(kitaGroupCtrl.text),
                    kitaTeacher: trimOrNull(kitaTeacherCtrl.text),
                    notes: trimOrNull(notesCtrl.text),
                    uExams: dossier.uExams,
                  );
                  await _dossierService.addOrUpdate(updated, expectedScope: _scope);
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
                child: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'save_btn')),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, String hint,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
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
