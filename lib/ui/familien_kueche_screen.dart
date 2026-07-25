import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/shopping_item.dart';

/// Familien-Kueche — 1-Tap Rezept-Inspiration + Eltern-Tipps.
///
/// Kein Formular, kein Tippen. App oeffnen → sofort Vorschlag sehen.
class FamilienKuecheScreen extends StatefulWidget {
  const FamilienKuecheScreen({super.key});

  @override
  State<FamilienKuecheScreen> createState() => _FamilienKuecheScreenState();
}

class _FamilienKuecheScreenState extends State<FamilienKuecheScreen> {
  final _service = FamilyRecipeService.instance;
  FamilyRecipe? _currentRecipe;
  bool _loading = true;
  bool _showSteps = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
    await _generateNew();
  }

  Future<void> _generateNew() async {
    setState(() {
      _loading = true;
      _showSteps = false;
    });
    final recipe = await _service.generateRecipe();
    if (mounted)
      setState(() {
        _currentRecipe = recipe;
        _loading = false;
      });
  }

  Future<void> _saveRecipe() async {
    if (_currentRecipe == null) return;
    await _service.saveRecipe(_currentRecipe!);
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u{2764}\u{FE0F} Rezept gespeichert!')),
      );
    }
  }

  Future<void> _rateRecipe(bool liked) async {
    if (_currentRecipe == null) return;
    await _service.rateRecipe(_currentRecipe!.title, liked);
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(liked
            ? '\u{2B50} Super! Kommt auf die Kinder-Hits Liste.'
            : '\u{1F44D} Okay, merken wir uns.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familien-Kueche'),
        elevation: 0,
        actions: [
          if (_service.savedRecipes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_rounded),
              tooltip: 'Gespeicherte Rezepte',
              onPressed: () => _showSavedRecipes(theme),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Rezept-Card
          if (_loading)
            _loadingState(theme)
          else if (_currentRecipe != null)
            _recipeCard(theme, _currentRecipe!),
          const SizedBox(height: 20),
          // Tipps-Bereich
          _tippsSection(theme),
        ]),
      ),
    );
  }

  Widget _loadingState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        const Text('\u{1F373}', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 14),
        Text('Rezept wird generiert...',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        const CircularProgressIndicator(strokeWidth: 2),
      ]),
    );
  }

  Widget _recipeCard(ThemeData theme, FamilyRecipe recipe) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header mit Gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipe.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(recipe.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF9A3412), height: 1.3)),
            const SizedBox(height: 12),
            // Meta-Chips
            Wrap(spacing: 8, runSpacing: 6, children: [
              _metaChip('\u{23F1}\u{FE0F} ${recipe.timeLabel}',
                  const Color(0xFF2563EB)),
              _metaChip(
                  '\u{1F4B0} ${recipe.costLabel}', const Color(0xFF16A34A)),
              _metaChip(
                  '\u{1F476} ${recipe.ageLabel}', const Color(0xFF8B5CF6)),
              if (recipe.allergensFree.isNotEmpty)
                _metaChip('\u{1F6AB} Ohne: ${recipe.allergensFree.join(", ")}',
                    const Color(0xFFDC2626)),
            ]),
          ]),
        ),
        // Zutaten
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('\u{1F6D2} Zutaten (${recipe.portions} Portionen)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...recipe.ingredients.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i, style: theme.textTheme.bodySmall)),
                  ]),
                )),
          ]),
        ),
        // Zubereitung (ausklappbar)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: GestureDetector(
            onTap: () => setState(() => _showSteps = !_showSteps),
            child: Row(children: [
              Text('\u{1F373} Zubereitung',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(
                  _showSteps
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: theme.colorScheme.outline),
            ]),
          ),
        ),
        if (_showSteps)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...recipe.steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF97316)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFF97316)))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(e.value,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.3))),
                        ]),
                  )),
            ]),
          ),
        // Eltern-Tipp
        if (recipe.tip.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('\u{1F4A1}', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(recipe.tip,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF166534),
                            height: 1.3,
                            fontStyle: FontStyle.italic))),
              ]),
            ),
          ),
        // Action Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: _saveRecipe,
                icon: const Icon(Icons.favorite_border_rounded, size: 18),
                label: const Text('Speichern'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton.icon(
                onPressed: _generateNew,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Andere Idee'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showIngredientPicker(context),
                icon: const Icon(Icons.shopping_cart_rounded, size: 16),
                label: const Text('Zutaten auf Einkaufsliste'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: BorderSide(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Bewertung: Hat es geschmeckt?
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Text('\u{1F36D}', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Hat es geschmeckt?',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9A3412)))),
                GestureDetector(
                  onTap: () => _rateRecipe(true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('\u{1F44D} Ja!',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A))),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _rateRecipe(false),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('\u{1F44E} Nee',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626))),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _metaChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ─── Tipps-Bereich ────────────────────────────────────────────────────────

  Widget _tippsSection(ThemeData theme) {
    final tips = _getTips();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('\u{1F4AC} Familien-Essen Tipps',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      ...tips.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['emoji']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t['title']!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(t['text']!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3)),
                    ])),
              ]),
            ),
          )),
    ]);
  }

  List<Map<String, String>> _getTips() {
    final month = DateTime.now().month;
    final season = month >= 3 && month <= 5
        ? 'fruehling'
        : month >= 6 && month <= 8
            ? 'sommer'
            : month >= 9 && month <= 11
                ? 'herbst'
                : 'winter';

    final allTips = <Map<String, String>>[
      {
        'emoji': '\u{1F966}',
        'title': 'Picky Eater?',
        'text':
            'Kinder brauchen bis zu 15 Versuche bevor sie etwas Neues moegen. Nicht aufgeben — immer wieder anbieten, nie zwingen.'
      },
      {
        'emoji': '\u{1F44C}',
        'title': 'Heute Tiefkuehlpizza?',
        'text':
            'Voellig okay. Nicht jeder Tag muss Perfektion sein. Morgen wird frisch gekocht.'
      },
      {
        'emoji': '\u{1F9D1}\u{200D}\u{1F373}',
        'title': 'Gemeinsam kochen',
        'text':
            'Kinder die mithelfen essen eher was auf dem Teller liegt. Ab 2 Jahren: Ruehren, Waschen. Ab 4: Schneiden mit Kindermesser.'
      },
      if (season == 'sommer')
        {
          'emoji': '\u{1F353}',
          'title': 'Saison-Tipp',
          'text':
              'Erdbeeren, Kirschen, Tomaten — gerade frisch und guenstig. Perfekt als Snack ohne Kochen.'
        },
      if (season == 'herbst')
        {
          'emoji': '\u{1F383}',
          'title': 'Saison-Tipp',
          'text':
              'Kuerbis, Aepfel, Birnen: suess, guenstig und vielseitig. Kuerbissuppe geht in 20 Minuten.'
        },
      if (season == 'winter')
        {
          'emoji': '\u{2744}\u{FE0F}',
          'title': 'Saison-Tipp',
          'text':
              'Kohlrabi, Karotten, Kartoffeln: Eintopf waermt, ist guenstig und laesst sich gut vorkochen.'
        },
      if (season == 'fruehling')
        {
          'emoji': '\u{1F331}',
          'title': 'Saison-Tipp',
          'text':
              'Spargel, Radieschen, Spinat: frisch vom Markt. Kinder lieben Radieschen wenn sie selbst ernten duerfen.'
        },
      {
        'emoji': '\u{1F4B0}',
        'title': 'Budget-Tipp',
        'text':
            'Huelsenfruchte (Linsen, Kichererbsen) sind guenstig, gesund und machen satt. Perfekt fuer Familien.'
      },
    ];

    // 3 Tipps anzeigen (rotierend nach Tag)
    final day = DateTime.now().day;
    final start = day % allTips.length;
    final result = <Map<String, String>>[];
    for (int i = 0; i < 3 && i < allTips.length; i++) {
      result.add(allTips[(start + i) % allTips.length]);
    }
    return result;
  }

  // ─── Gespeicherte Rezepte ─────────────────────────────────────────────────

  void _showSavedRecipes(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Text(
                    '\u{2764}\u{FE0F} Gespeicherte Rezepte (${_service.savedRecipes.length})',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Expanded(
              child: _service.savedRecipes.isEmpty
                  ? Center(
                      child: Text('Noch keine gespeicherten Rezepte.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: _service.savedRecipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = _service.savedRecipes[i];
                        return ListTile(
                          title: Text(r.title,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${r.timeLabel} \u{2022} ${r.costLabel} \u{2022} ${r.ageLabel}',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            onPressed: () async {
                              await _service.removeRecipe(r.id);
                              Navigator.pop(ctx);
                              setState(() {});
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _currentRecipe = r;
                              _showSteps = false;
                            });
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          tileColor: theme.colorScheme.surfaceContainerLow,
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Zutaten-Auswahl fuer Einkaufsliste ───────────────────────────────────

  void _showIngredientPicker(BuildContext context) {
    if (_currentRecipe == null) return;
    final recipe = _currentRecipe!;
    final theme = Theme.of(context);
    final shopping = ShoppingListService.instance;

    // Fuer jedes Item: ist es ein Basis-Item? Ist es schon auf der Liste?
    final selections = recipe.ingredients.map((ing) {
      final isBasic = ShoppingListService.isBasicItem(ing);
      final parsed = ShoppingItem.fromInput(ing);
      final alreadyOnList = shopping.isAlreadyOnList(parsed.name);
      return _IngredientSelection(
        ingredient: ing,
        parsedName: parsed.name,
        isSelected: !isBasic && !alreadyOnList,
        isBasic: isBasic,
        alreadyOnList: alreadyOnList,
      );
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IngredientPickerSheet(
        selections: selections,
        theme: theme,
        onConfirm: (selected) async {
          try {
            await shopping.load();
            await shopping.addItemsFromRecipe(selected);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '\u{2705} ${selected.length} Zutaten auf die Einkaufsliste gesetzt'),
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Fehler: $e'),
              ));
            }
          }
        },
      ),
    );
  }
}

// ─── Ingredient Selection Data ───────────────────────────────────────────────

class _IngredientSelection {
  final String ingredient;
  final String parsedName;
  bool isSelected;
  final bool isBasic;
  final bool alreadyOnList;

  _IngredientSelection({
    required this.ingredient,
    required this.parsedName,
    required this.isSelected,
    required this.isBasic,
    required this.alreadyOnList,
  });
}

// ─── Ingredient Picker Bottom Sheet ──────────────────────────────────────────

class _IngredientPickerSheet extends StatefulWidget {
  final List<_IngredientSelection> selections;
  final ThemeData theme;
  final Future<void> Function(List<String>) onConfirm;

  const _IngredientPickerSheet({
    required this.selections,
    required this.theme,
    required this.onConfirm,
  });

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final selectedCount = widget.selections.where((s) => s.isSelected).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Text('\u{1F6D2} Was brauchst du noch?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Waehle nur was du wirklich kaufen musst.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 14),
        // Liste
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.selections.length,
            itemBuilder: (_, i) {
              final sel = widget.selections[i];
              return CheckboxListTile(
                value: sel.isSelected,
                onChanged: (v) => setState(() => sel.isSelected = v ?? false),
                title: Text(sel.ingredient,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: sel.alreadyOnList
                    ? Text('\u{2714} Schon auf deiner Liste',
                        style: TextStyle(
                            fontSize: 10, color: const Color(0xFF16A34A)))
                    : sel.isBasic
                        ? Text('\u{1F3E0} Hast du wahrscheinlich zuhause',
                            style: TextStyle(
                                fontSize: 10, color: theme.colorScheme.outline))
                        : null,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF16A34A),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      final selected = widget.selections
                          .where((s) => s.isSelected)
                          .map((s) => s.ingredient)
                          .toList();
                      Navigator.pop(context);
                      widget.onConfirm(selected);
                    },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text('$selectedCount Zutaten hinzufuegen'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )),
      ]),
    );
  }
}
