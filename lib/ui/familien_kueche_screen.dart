import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/logic/family_recipe_service.dart';
import 'package:parentpeak/ui/family_recipes_screen.dart';
import 'package:parentpeak/ui/fridge_recipe_screen.dart';
import 'package:parentpeak/ui/tischmoment_screen.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

/// Familien-Küche — 1-Tap Rezept-Inspiration + Eltern-Tipps.
///
/// Kein Formular, kein Tippen. App oeffnen → sofort Vorschlag sehen.
class FamilienKuecheScreen extends StatefulWidget {
  const FamilienKuecheScreen({super.key});

  @override
  State<FamilienKuecheScreen> createState() => _FamilienKuecheScreenState();
}

class _FamilienKuecheScreenState extends State<FamilienKuecheScreen> {
  final _service = FamilyRecipeService.instance;
  final _searchCtrl = TextEditingController();
  FamilyRecipe? _currentRecipe;
  bool _loading = true;
  bool _dayRecipeExpanded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _service.initialize();
    await _generateNew();
  }

  /// Öffnet die Familien-Rezepte mit vorausgefülltem Suchbegriff.
  void _searchRecipes(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyRecipesScreen(initialQuery: q),
      ),
    );
  }

  Future<void> _generateNew() async {
    setState(() {
      _loading = true;
      _dayRecipeExpanded = false;
    });
    final recipe = await _service.generateRecipe(
      languageCode: languageService.currentLanguage,
    );
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
        SnackBar(
            content: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'recipe_saved'))),
      );
    }
  }

  Future<void> _rateRecipe(bool liked) async {
    if (_currentRecipe == null) return;
    await _service.rateRecipe(_currentRecipe!.title, liked);
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
            liked ? 'kitchen_rating_liked' : 'kitchen_rating_not_liked')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'familien_kueche_title')),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_rounded),
            tooltip: context.tr('kitchen_family_recipes_tooltip'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FamilyRecipesScreen()),
            ),
          ),
          if (_service.savedRecipes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_rounded),
              tooltip: context.tr('tooltip_saved_recipes'),
              onPressed: () => _showSavedRecipes(theme),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Prominente Rezept-Suche ganz oben
          _searchBar(theme),
          const SizedBox(height: 16),
          // KI-Kühlschrank-Foto: aus vorhandenen Zutaten ein Rezept
          _fridgeCard(theme),
          const SizedBox(height: 16),
          // Herzens-Feature: sanfter Abend-Impuls (abends hervorgehoben)
          _tischmomentCard(theme),
          const SizedBox(height: 16),
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

  /// Prominente Suchleiste: springt mit dem Begriff in die Familien-Rezepte.
  Widget _searchBar(ThemeData theme) {
    return TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      onSubmitted: _searchRecipes,
      decoration: InputDecoration(
        hintText: context.tr('kitchen_search_hint'),
        hintStyle: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B5CF6)),
        suffixIcon: IconButton(
          icon:
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF8B5CF6)),
          tooltip: context.tr('tooltip_search'),
          onPressed: () => _searchRecipes(_searchCtrl.text),
        ),
        filled: true,
        fillColor: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
    );
  }

  /// Einstieg in das KI-Kühlschrank-Foto (Phase 3b).
  Widget _fridgeCard(ThemeData theme) {
    return Material(
      color: const Color(0xFFE8543A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FridgeRecipeScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('📸🥕', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('kitchen_fridge_title'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('kitchen_fridge_subtitle'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Sanfter Abend-Impuls für das Tischmoment-Ritual. Ab 17 Uhr wird die Karte
  /// warm hervorgehoben; tagsüber bleibt sie dezent.
  Widget _tischmomentCard(ThemeData theme) {
    final isEvening = DateTime.now().hour >= 17;
    final title = context.tr(isEvening
      ? 'kitchen_table_moment_evening_title'
      : 'kitchen_table_moment_title');
    final subtitle = isEvening
      ? context.tr('kitchen_table_moment_evening_subtitle')
      : context.tr('kitchen_table_moment_subtitle');

    final borderRadius = BorderRadius.circular(18);
    return Material(
      color: isEvening ? null : theme.colorScheme.surface,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TischmomentScreen()),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: isEvening
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                  )
                : null,
            border: isEvening
                ? null
                : Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('🕯️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: isEvening
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: isEvening
                                  ? Colors.white70
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: isEvening ? Colors.white : theme.colorScheme.outline,
                    size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        const Text('\u{1F373}', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 14),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'generating_recipe'),
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
        borderRadius: BorderRadius.circular(18),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipe.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(recipe.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF9A3412), height: 1.3)),
            const SizedBox(height: 12),
            // Meta-Chips
            Wrap(spacing: 8, runSpacing: 6, children: [
              _metaChip('\u{23F1}\u{FE0F} ${context.tr('kitchen_minutes', values: {'minutes': recipe.prepMinutes})}',
                  const Color(0xFF2563EB)),
              _metaChip(
                  '\u{1F4B0} ${context.tr('kitchen_cost_per_portion', values: {'cost': recipe.costPerPortion.toStringAsFixed(2)})}', const Color(0xFF16A34A)),
              _metaChip(
                  '\u{1F476} ${context.tr(recipe.minChildAge == 0 ? 'kitchen_age_months' : 'kitchen_age_years', values: {'age': recipe.minChildAge})}', const Color(0xFF8B5CF6)),
              if (recipe.allergensFree.isNotEmpty)
                _metaChip('${context.tr('kitchen_without')} ${recipe.allergensFree.join(", ")}',
                    const Color(0xFFDC2626)),
            ]),
          ]),
        ),
        // Zutaten & Zubereitung (kompakt: einklappbar unter einem Tipp)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => _dayRecipeExpanded = !_dayRecipeExpanded),
            child: Row(children: [
              Text(
                  _dayRecipeExpanded
                      ? context.tr('kitchen_ingredients_preparation')
                      : context.tr('kitchen_view_ingredients_preparation'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(
                  _dayRecipeExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: theme.colorScheme.outline),
            ]),
          ),
        ),
        // Zutaten (nur wenn ausgeklappt)
        if (_dayRecipeExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${AppStringsManager.getString(languageService.currentLanguage, "ingredients_portions")} (${recipe.portions} ${AppStringsManager.getString(languageService.currentLanguage, "portions_label")})',
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
                      Expanded(
                          child: Text(i, style: theme.textTheme.bodySmall)),
                    ]),
                  )),
            ]),
          ),
        // Zubereitung (nur wenn ausgeklappt)
        if (_dayRecipeExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'save_recipe')),
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
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'other_idea')),
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
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'ingredients_to_list')),
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
                    child: Text(
                        AppStringsManager.getString(
                            languageService.currentLanguage, 'did_it_taste'),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9A3412)))),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _rateRecipe(true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        AppStringsManager.getString(
                            languageService.currentLanguage, 'yes_tasty'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A))),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _rateRecipe(false),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        AppStringsManager.getString(
                            languageService.currentLanguage, 'no_tasty'),
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
      Text(
          AppStringsManager.getString(
              languageService.currentLanguage, 'family_food_tips'),
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
        ? 'frühling'
        : month >= 6 && month <= 8
            ? 'sommer'
            : month >= 9 && month <= 11
                ? 'herbst'
                : 'winter';

    final allTips = <Map<String, String>>[
      {
        'emoji': '\u{1F966}',
        'id': 'picky_eater',
      },
      {
        'emoji': '\u{1F44C}',
        'id': 'frozen_pizza',
      },
      {
        'emoji': '\u{1F9D1}\u{200D}\u{1F373}',
        'id': 'cook_together',
      },
      if (season == 'sommer')
        {
          'emoji': '\u{1F353}',
            'id': 'season_summer',
        },
      if (season == 'herbst')
        {
          'emoji': '\u{1F383}',
            'id': 'season_autumn',
        },
      if (season == 'winter')
        {
          'emoji': '\u{2744}\u{FE0F}',
            'id': 'season_winter',
        },
      if (season == 'frühling')
        {
          'emoji': '\u{1F331}',
            'id': 'season_spring',
        },
      {
        'emoji': '\u{1F4B0}',
        'id': 'budget',
      },
      {
        'emoji': '\u{1F9CA}',
        'id': 'meal_prep',
      },
      {
        'emoji': '\u{1F34E}',
        'id': 'snack',
      },
      {
        'emoji': '\u{1F4A7}',
        'id': 'drinking',
      },
      {
        'emoji': '\u{1F955}',
        'id': 'hidden_vegetables',
      },
      {
        'emoji': '\u{1F91D}',
        'id': 'family_ritual',
      },
      {
        'emoji': '\u{23F0}',
        'id': 'morning',
      },
      {
        'emoji': '\u{1F9D1}\u{200D}\u{1F33E}',
        'id': 'nature',
      },
      {
        'emoji': '\u{1F36A}',
        'id': 'healthy_sweets',
      },
      {
        'emoji': '\u{1F37D}\u{FE0F}',
        'id': 'no_food_battle',
      },
      {
        'emoji': '\u{1F9C0}',
        'id': 'leftovers',
      },
      {
        'emoji': '\u{2744}\u{FE0F}',
        'id': 'frozen_vegetables',
      },
    ];

    // 3 Tipps anzeigen (rotierend nach Tag)
    final day = DateTime.now().day;
    final start = day % allTips.length;
    final result = <Map<String, String>>[];
    for (int i = 0; i < 3 && i < allTips.length; i++) {
      final tip = allTips[(start + i) % allTips.length];
      final id = tip['id']!;
      final localized = context.tr('kitchen_tip_$id').split('|');
      result.add({
        'emoji': tip['emoji']!,
        'title': localized.first,
        'text': localized.length > 1 ? localized[1] : '',
      });
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
                    context.tr('kitchen_saved_recipes_count', values: {
                      'count': _service.savedRecipes.length,
                    }),
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
                      child: Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage,
                              'no_saved_recipes'),
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
                              '${context.tr('kitchen_minutes', values: {'minutes': r.prepMinutes})} \u{2022} '
                              '${context.tr('kitchen_cost_per_portion', values: {'cost': r.costPerPortion.toStringAsFixed(2)})} \u{2022} '
                              '${context.tr(r.minChildAge == 0 ? 'kitchen_age_months' : 'kitchen_age_years', values: {'age': r.minChildAge})}',
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
                              _dayRecipeExpanded = false;
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

  // ─── Zutaten-Auswahl für Einkaufsliste ───────────────────────────────────

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
                    context.tr('kitchen_ingredients_added', values: {
                      'count': selected.length,
                    })),
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(context.tr('kitchen_error', values: {'error': e})),
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
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'what_do_you_need'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(AppStringsManager.getString(
          languageService.currentLanguage, 'kitchen_buy_only_needed'),
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
                    ? Text(context.tr('already_on_list'),
                        style: TextStyle(
                            fontSize: 10, color: const Color(0xFF16A34A)))
                    : sel.isBasic
                        ? Text(context.tr('probably_at_home'),
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
                label: Text(context.tr('kitchen_add_ingredients_count',
                  values: {'count': selectedCount})),
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
