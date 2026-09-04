import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/logic/family_recipe_share_service.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/shared_family_recipe.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/ui/widgets/safe_image.dart';

/// Phase 3a: Familien-Rezepte teilen.
///
/// Eltern koennen eigene Rezepte teilen (Foto, Beschreibung, Zutaten) und die
/// Rezepte von verbundenen Freunden entdecken. Suche nach Gericht oder Zutat,
/// schnelle Filter und herzliche Reaktionen ("Das kochen wir nach!" /
/// "Hat geschmeckt!").
class FamilyRecipesScreen extends StatefulWidget {
  /// Optionaler vorausgefüllter Suchbegriff (z. B. vom Küchen-Hauptscreen).
  final String? initialQuery;

  const FamilyRecipesScreen({super.key, this.initialQuery});

  @override
  State<FamilyRecipesScreen> createState() => _FamilyRecipesScreenState();
}

class _FamilyRecipesScreenState extends State<FamilyRecipesScreen> {
  static const _accent = Color(0xFFE8543A);

  final _service = FamilyRecipeShareService.instance;
  final _aiService = FamilyRecipeService.instance;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<SharedFamilyRecipe> _recipes = [];
  bool _loading = true;
  String _query = '';
  String? _activeFilter; // null = alle

  // KI-Fallback (Blitz-Rezept), wenn die Community nichts hat.
  bool _generatingAi = false;
  FamilyRecipe? _aiRecipe;
  bool _aiShared = false;

  // Schnell-Filter: Label -> Suchbegriff, der an die Server-Suche geht.
  static const _filters = <String, String>{
    'Schnell (< 20 Min)': 'schnell',
    'Vegetarisch': 'vegetarisch',
    'BLW / Beikost': 'blw',
  };

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _searchCtrl.text = q;
      _query = q;
    }
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Wenn ein Filter aktiv ist, fliesst dessen Begriff mit in die Suche.
    final filterTerm =
        _activeFilter != null ? (_filters[_activeFilter] ?? '') : '';
    final effectiveQuery =
        [_query, filterTerm].where((s) => s.trim().isNotEmpty).join(' ');
    final list = await _service.loadRecipes(query: effectiveQuery);
    if (!mounted) return;
    setState(() {
      _recipes = list;
      _loading = false;
      // Bei neuer Suche das alte KI-Blitz-Rezept zurücksetzen.
      _aiRecipe = null;
      _aiShared = false;
    });
  }

  /// KI-Fallback: erzeugt auf Knopfdruck ein kinderfreundliches Blitz-Rezept
  /// zum gesuchten Gericht (kein automatischer Aufruf -> spart KI-Kosten).
  Future<void> _generateAiFallback() async {
    final dish = _query.trim();
    if (dish.isEmpty) return;
    setState(() => _generatingAi = true);
    try {
      await _aiService.initialize();
      final recipe = await _aiService.generateRecipeFor(dish);
      if (!mounted) return;
      setState(() {
        _aiRecipe = recipe;
        _generatingAi = false;
      });
      if (recipe == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Ich konnte gerade kein Rezept erstellen. Bitte versuche es '
                  'gleich noch einmal.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on AiRateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _generatingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _generatingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Ich konnte gerade kein Rezept erstellen. Bitte versuche es gleich '
            'noch einmal.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Teilt das KI-Blitz-Rezept in den Familien-Rezepten (Standard: Nur Freunde).
  Future<void> _shareAiRecipe(FamilyRecipe r) async {
    setState(() => _generatingAi = true);
    try {
      final created = await _service.createRecipe(
        title: r.title,
        description: r.description,
        ingredients: r.ingredients,
        steps: r.steps,
        prepMinutes: r.prepMinutes,
        visibility: 'friends',
      );
      if (!mounted) return;
      setState(() {
        _generatingAi = false;
        _aiShared = created != null;
      });
      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rezept mit deinen Freunden geteilt. 🍳'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF16A34A),
        ));
        _load();
      }
    } on SuspendedAccountException {
      if (mounted) {
        setState(() => _generatingAi = false);
        await showAccountSuspendedNotice(context);
      }
    } catch (_) {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _query = value.trim();
      _load();
    });
  }

  void _toggleFilter(String label) {
    setState(() => _activeFilter = _activeFilter == label ? null : label);
    _load();
  }

  Future<void> _react(SharedFamilyRecipe recipe, String type) async {
    HapticFeedback.lightImpact();
    try {
      final updated = await _service.react(recipe.id, type);
      if (updated != null && mounted) {
        setState(() {
          final i = _recipes.indexWhere((r) => r.id == recipe.id);
          if (i != -1) _recipes[i] = updated;
        });
      }
    } on SuspendedAccountException {
      if (mounted) await showAccountSuspendedNotice(context);
    }
  }

  Future<void> _deleteRecipe(SharedFamilyRecipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rezept löschen?'),
        content: Text('Möchtest du „${recipe.title}“ wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _accent),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _service.deleteRecipe(recipe.id);
    if (ok && mounted) {
      setState(() => _recipes.removeWhere((r) => r.id == recipe.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rezept gelöscht.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateRecipeSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familien-Rezepte'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Rezept teilen'),
      ),
      body: Column(
        children: [
          _searchAndFilters(theme),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipes.isEmpty
                      ? _emptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _recipes.length,
                          itemBuilder: (_, i) =>
                              _recipeCard(theme, _recipes[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Wonach ist euch heute? (z. B. Kartoffelsalat, Nudeln)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _query = '';
                        _load();
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.keys.map((label) {
                final active = _activeFilter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: active,
                    showCheckmark: false,
                    onSelected: (_) => _toggleFilter(label),
                    selectedColor: _accent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: active ? _accent : theme.colorScheme.onSurface,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color:
                          active ? _accent : theme.colorScheme.outlineVariant,
                    ),
                    backgroundColor: theme.colorScheme.surface,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    final hasQuery = _query.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.restaurant_menu_rounded,
            size: 52, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          hasQuery
              ? 'Noch kein Community-Rezept für „$_query“.'
              : (_activeFilter != null
                  ? 'Noch kein passendes Rezept gefunden.'
                  : 'Noch keine Rezepte.'),
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        // KI-Fallback: Blitz-Rezept auf Knopfdruck (nur bei aktiver Suche).
        if (hasQuery && _aiRecipe == null) _aiFallbackCard(theme),
        if (_aiRecipe != null) _aiRecipeCard(theme, _aiRecipe!),
        if (!hasQuery) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Teile dein erstes Familien-Rezept – ein Tap unten rechts genügt.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }

  /// Karte, die anbietet, per KI ein Blitz-Rezept zum Suchbegriff zu zaubern.
  Widget _aiFallbackCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text('✨🍳', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 10),
          Text(
            'Möchtest du, dass die KI dir ein kinderfreundliches '
            'Blitz-Rezept für „$_query“ zaubert?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generatingAi ? null : _generateAiFallback,
              icon: _generatingAi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_generatingAi ? 'Zaubere …' : 'Blitz-Rezept zaubern'),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zeigt das generierte KI-Blitz-Rezept inline (mit Teilen-Option).
  Widget _aiRecipeCard(ThemeData theme, FamilyRecipe r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text('KI-Blitz-Rezept',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: _accent)),
          ]),
          const SizedBox(height: 8),
          Text(r.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.description,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
          ],
          Row(children: [
            Icon(Icons.schedule_rounded,
                size: 13, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(r.timeLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(width: 12),
            Icon(Icons.child_care_rounded,
                size: 13, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(r.ageLabel,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ]),
          if (r.ingredients.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Zutaten',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...r.ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                            child: Text(ing, style: theme.textTheme.bodySmall)),
                      ]),
                )),
          ],
          if (r.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Zubereitung',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...List.generate(
                r.steps.length,
                (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}. ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _accent)),
                            Expanded(
                                child: Text(r.steps[i],
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(height: 1.4))),
                          ]),
                    )),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _generatingAi || _aiShared ? null : () => _shareAiRecipe(r),
              icon: Icon(
                  _aiShared ? Icons.check_rounded : Icons.bookmark_add_rounded),
              label: Text(_aiShared
                  ? 'In Familien-Rezepten gespeichert'
                  : 'In Familien-Rezepten teilen'),
              style: FilledButton.styleFrom(
                backgroundColor: _aiShared ? const Color(0xFF16A34A) : _accent,
                disabledBackgroundColor:
                    _aiShared ? const Color(0xFF16A34A) : null,
                disabledForegroundColor: _aiShared ? Colors.white : null,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipeCard(ThemeData theme, SharedFamilyRecipe r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.photoUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                r.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.image_not_supported_rounded,
                      color: theme.colorScheme.outline),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (r.isMine)
                      IconButton(
                        icon: Icon(Icons.more_vert_rounded,
                            color: theme.colorScheme.outline),
                        onPressed: () => _showOwnerMenu(r),
                        tooltip: 'Optionen',
                      ),
                  ],
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: _avatarColor(r.authorName),
                      child: Text(
                        r.authorName.isNotEmpty
                            ? r.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(r.isMine ? 'Von dir' : r.authorName,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    if (r.prepMinutes > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.schedule_rounded,
                          size: 13, color: theme.colorScheme.outline),
                      const SizedBox(width: 3),
                      Text('${r.prepMinutes} Min',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ],
                ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(r.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                ],
                if (r.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Zutaten',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: r.ingredients
                        .map((ing) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:
                                  Text(ing, style: theme.textTheme.labelSmall),
                            ))
                        .toList(),
                  ),
                ],
                if (r.steps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Zubereitung',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ...List.generate(r.steps.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700, color: _accent)),
                          Expanded(
                              child: Text(r.steps[i],
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.4))),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 14),
                _reactionRow(theme, r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionRow(ThemeData theme, SharedFamilyRecipe r) {
    return Row(
      children: [
        _reactionButton(
          theme,
          active: r.myCook,
          label: 'Das kochen wir nach!',
          emoji: '🍳',
          count: r.cookCount,
          onTap: () => _react(r, 'cook'),
        ),
        const SizedBox(width: 8),
        _reactionButton(
          theme,
          active: r.myTasty,
          label: 'Hat geschmeckt!',
          emoji: '😋',
          count: r.tastyCount,
          onTap: () => _react(r, 'tasty'),
        ),
      ],
    );
  }

  Widget _reactionButton(
    ThemeData theme, {
    required bool active,
    required String label,
    required String emoji,
    required int count,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: active
            ? _accent.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              children: [
                Text('$emoji ${count > 0 ? count : ''}'.trim(),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: active ? _accent : theme.colorScheme.onSurface,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOwnerMenu(SharedFamilyRecipe r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Rezept löschen'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteRecipe(r);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Color _avatarColor(String name) {
    const colors = [
      Color(0xFFE8543A),
      Color(0xFF7C3AED),
      Color(0xFF0EA5E9),
      Color(0xFF059669),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

/// Bottom-Sheet zum Erstellen eines Rezepts.
class _CreateRecipeSheet extends StatefulWidget {
  const _CreateRecipeSheet();

  @override
  State<_CreateRecipeSheet> createState() => _CreateRecipeSheetState();
}

class _CreateRecipeSheetState extends State<_CreateRecipeSheet> {
  static const _accent = Color(0xFFE8543A);

  final _service = FamilyRecipeShareService.instance;
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();

  XFile? _photo;
  String _visibility = 'friends'; // Standard: Nur meine Freunde
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _ingredientsCtrl.dispose();
    _stepsCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 80,
      );
      if (img != null && mounted) setState(() => _photo = img);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto konnte nicht ausgewählt werden.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  List<String> _splitLines(String raw) =>
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitte gib deinem Rezept einen Namen.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      String photoUrl = '';
      if (_photo != null) {
        final url = await _service.uploadPhoto(_photo!);
        if (url != null) photoUrl = url;
      }
      final recipe = await _service.createRecipe(
        title: title,
        description: _descCtrl.text.trim(),
        photoUrl: photoUrl,
        ingredients: _splitLines(_ingredientsCtrl.text),
        steps: _splitLines(_stepsCtrl.text),
        prepMinutes: int.tryParse(_minutesCtrl.text.trim()) ?? 0,
        visibility: _visibility,
      );
      if (!mounted) return;
      if (recipe != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rezept geteilt. Danke fürs Teilen! 🍳'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF16A34A),
        ));
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Konnte nicht speichern — bitte später erneut.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on SuspendedAccountException {
      if (mounted) {
        setState(() => _saving = false);
        await showAccountSuspendedNotice(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Konnte nicht speichern — bitte später erneut.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Rezept teilen',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              // Foto
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.6)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _photo != null
                      ? SafeXFileImage(
                          file: _photo!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 150,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded,
                                size: 30, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('Foto hinzufügen (optional)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              _field(_titleCtrl, 'Name des Gerichts',
                  hint: 'z. B. Omas Kartoffelsalat'),
              const SizedBox(height: 12),
              _field(_descCtrl, 'Kurze Beschreibung',
                  hint: 'Warum mögen es eure Kinder?', maxLines: 2),
              const SizedBox(height: 12),
              _field(_ingredientsCtrl, 'Zutaten (eine pro Zeile)',
                  hint: '500 g Kartoffeln\n1 Zwiebel\n…', maxLines: 4),
              const SizedBox(height: 12),
              _field(_stepsCtrl, 'Zubereitung (ein Schritt pro Zeile)',
                  hint: 'Kartoffeln kochen.\nZwiebel würfeln.\n…', maxLines: 4),
              const SizedBox(height: 12),
              _field(_minutesCtrl, 'Zubereitungszeit in Minuten',
                  hint: 'z. B. 25', keyboardType: TextInputType.number),
              const SizedBox(height: 18),

              Text('Wer darf dein Rezept sehen?',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _visibilityOption(
                  'friends',
                  'Nur meine Freunde',
                  'Empfohlen – nur verbundene Familien sehen es.',
                  Icons.group_rounded),
              _visibilityOption(
                  'public',
                  'Für alle Familien',
                  'Alle ParentPeak-Familien können es entdecken.',
                  Icons.public_rounded),
              _visibilityOption(
                  'private',
                  'Nur für mich',
                  'Bleibt privat – nur du siehst es.',
                  Icons.lock_outline_rounded),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Teilen',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    final theme = Theme.of(context);
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: maxLines > 1
          ? TextCapitalization.sentences
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _visibilityOption(
      String value, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    final active = _visibility == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active
            ? _accent.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _visibility = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: active ? _accent : theme.colorScheme.outline,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: active ? _accent : null)),
                      Text(subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
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
}
