import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/models/recipe.dart';

/// SimpleMealPlanner: Clean, focused meal planning for real parents.
/// 
/// Features:
/// - Weekly meal plan (Mon-Sun)
/// - Simple recipe selection
/// - Auto-generated shopping list
/// - Baby portion options
/// - Zero gimmicks
class SimpleMealPlanner extends StatefulWidget {
  const SimpleMealPlanner({super.key});

  @override
  State<SimpleMealPlanner> createState() => _SimpleMealPlannerState();
}

class _SimpleMealPlannerState extends State<SimpleMealPlanner> {
  late DateTime _weekStart;
  final Map<String, String> _weekPlan = {}; // date -> recipeId
  final Set<String> _hideBabyOptions = {};
  bool _showShoppingList = false;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _initializeWeekPlan();
  }

  void _initializeWeekPlan() {
    // Pre-fill with some default recipes for demo
    for (int i = 0; i < 7; i++) {
      final date = _weekStart.add(Duration(days: i));
      final key = _formatDate(date);
      _weekPlan[key] = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFD),
        elevation: 0,
        foregroundColor: const Color(0xFF1A2A3A),
        title: const Text(
          'Essensplaner',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => setState(() => _showShoppingList = !_showShoppingList),
            tooltip: context.tr('tooltip_shopping_list'),
          ),
        ],
      ),
      body: _showShoppingList
          ? _buildShoppingList()
          : _buildWeeklyPlan(),
    );
  }

  Widget _buildWeeklyPlan() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Woche vom ${DateFormat('dd.MM').format(_weekStart)} '
              'bis ${DateFormat('dd.MM').format(_weekStart.add(const Duration(days: 6)))}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF516072),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = _weekStart.add(Duration(days: index));
              final dateKey = _formatDate(date);
              final recipeId = _weekPlan[dateKey] ?? '';
              final recipe = recipeId.isEmpty
                  ? null
                  : _allRecipes.firstWhere((r) => r.id == recipeId,
                      orElse: () => _allRecipes.first);

              return _DayPlanCard(
                date: date,
                recipe: recipe,
                onRecipeSelected: (selectedRecipe) {
                  setState(() {
                    _weekPlan[dateKey] = selectedRecipe.id;
                  });
                },
                onToggleBabyMode: (hide) {
                  setState(() {
                    if (hide) {
                      _hideBabyOptions.add(dateKey);
                    } else {
                      _hideBabyOptions.remove(dateKey);
                    }
                  });
                },
                hideBabyOptions: _hideBabyOptions.contains(dateKey),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingList() {
    final ingredients = <String, String>{}; // ingredient -> amount

    // Collect all ingredients from selected recipes
    for (final recipeId in _weekPlan.values) {
      if (recipeId.isEmpty) continue;

      final recipe = _allRecipes.firstWhere((r) => r.id == recipeId,
          orElse: () => _allRecipes.first);

      for (final ing in recipe.ingredients) {
        if (ingredients.containsKey(ing.name)) {
          // Simple concatenation for now
          ingredients[ing.name] = '${ingredients[ing.name]}, ${ing.amount}';
        } else {
          ingredients[ing.name] = ing.amount;
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Einkaufsliste für diese Woche',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ingredients.length} Artikel',
                  style: const TextStyle(
                    color: Color(0xFF516072),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E3E8)),
                ),
                child: const Text(
                  'Keine Rezepte ausgewählt. Wähle Rezepte im Wochenplan, um die Einkaufsliste zu generieren.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF516072)),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ingredients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entries = ingredients.entries.toList();
                    final item = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Checkbox(value: false, onChanged: (_) {}),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.value,
                                  style: const TextStyle(
                                    color: Color(0xFF516072),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  DateTime _startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }
}

class _DayPlanCard extends StatelessWidget {
  final DateTime date;
  final Recipe? recipe;
  final Function(Recipe) onRecipeSelected;
  final Function(bool) onToggleBabyMode;
  final bool hideBabyOptions;

  const _DayPlanCard({
    required this.date,
    required this.recipe,
    required this.onRecipeSelected,
    required this.onToggleBabyMode,
    required this.hideBabyOptions,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE', 'de_DE').format(date);
    final dayLabel = DateFormat('dd.MM').format(date);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF516072),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Color(0xFFE07B39),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recipe == null)
            GestureDetector(
              onTap: () => _showRecipeSelector(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE0E3E8),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+ Rezept auswählen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF516072),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showRecipeSelector(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE0E3E8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: const Color(0xFF516072).withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe!.durationMinutes} Min',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF516072),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (recipe!.ingredients.any((i) => i.babyOption != null))
                  Row(
                    children: [
                      Checkbox(
                        value: hideBabyOptions,
                        onChanged: (val) =>
                            onToggleBabyMode(val ?? false),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Baby-Portion verstecken',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF516072),
                        ),
                      ),
                    ],
                  ),
                if (!hideBabyOptions &&
                    recipe!.ingredients.any((i) => i.babyOption != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFFE4D0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '👶 Baby-Optionen:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...recipe!.ingredients
                              .where((i) => i.babyOption != null)
                              .map((ing) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    child: Text(
                                      '• ${ing.name}: ${ing.babyOption}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF516072),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showRecipeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rezept auswählen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _allRecipes.length,
                itemBuilder: (context, index) {
                  final r = _allRecipes[index];
                  return ListTile(
                    title: Text(r.title),
                    subtitle: Text(
                      '${r.durationMinutes} min${r.isPickEaterFriendly ? ' • kinderfreundlich' : ''}',
                    ),
                    onTap: () {
                      onRecipeSelected(r);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RECIPE DATABASE (moved here for simplicity)
// ============================================================================

const List<Recipe> _allRecipes = [
  Recipe(
    id: 'r-1',
    title: 'One-Pot Pasta mit Brokkoli',
    durationMinutes: 14,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: true,
    ingredients: [
      RecipeIngredient(name: 'Pasta', amount: '300 g', babyOption: 'Sehr weich kochen'),
      RecipeIngredient(name: 'Brokkoli', amount: '200 g', babyOption: 'In kleine Röschen dämpfen'),
      RecipeIngredient(name: 'Frischkäse', amount: '150 g', babyOption: 'Ohne Salz für Baby-Portion'),
    ],
  ),
  Recipe(
    id: 'r-2',
    title: 'Express Reispfanne Vorrat',
    durationMinutes: 12,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(name: 'Reis (vorgekocht)', amount: '400 g', babyOption: 'Mit Gemüsebrei mischen'),
      RecipeIngredient(name: 'Erbsen', amount: '120 g', babyOption: 'Gut zerdrücken'),
      RecipeIngredient(name: 'Ei', amount: '2 Stk', babyOption: 'Komplett durchgaren'),
    ],
  ),
  Recipe(
    id: 'r-3',
    title: 'Ofen-Lasagne Familie',
    durationMinutes: 45,
    isPickEaterFriendly: false,
    isOnePot: false,
    hideVegetables: true,
    ingredients: [
      RecipeIngredient(name: 'Lasagneplatten', amount: '12 Stk', babyOption: 'Sehr weich backen'),
      RecipeIngredient(name: 'Hack oder Linsen', amount: '400 g', babyOption: 'Sehr fein zerkleinern'),
      RecipeIngredient(name: 'Tomatensosse', amount: '500 ml', babyOption: 'Ohne Salz entnehmen'),
    ],
  ),
  Recipe(
    id: 'r-4',
    title: 'Kartoffel-Suppe schnell',
    durationMinutes: 13,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(name: 'Kartoffeln', amount: '600 g', babyOption: 'Fein stampfen'),
      RecipeIngredient(name: 'Karotten', amount: '2 Stk', babyOption: 'Sehr weich kochen'),
      RecipeIngredient(name: 'Gemüsebrühe', amount: '750 ml', babyOption: 'Für Baby nur Wasser verwenden'),
    ],
  ),
  Recipe(
    id: 'r-5',
    title: 'Gemüse-Reis-Pfanne',
    durationMinutes: 25,
    isPickEaterFriendly: true,
    isOnePot: false,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(name: 'Reis', amount: '300 g', babyOption: 'Etwas länger garen'),
      RecipeIngredient(name: 'Paprika', amount: '2 Stk', babyOption: 'Geschält und fein gewürfelt'),
      RecipeIngredient(name: 'Brokkoli', amount: '150 g', babyOption: 'Sehr weich garen'),
    ],
  ),
  Recipe(
    id: 'r-6',
    title: 'Quinoa Buddha Bowl',
    durationMinutes: 20,
    isPickEaterFriendly: false,
    isOnePot: false,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(name: 'Quinoa', amount: '200 g'),
      RecipeIngredient(name: 'Kichererbsen (Dose)', amount: '200 g', babyOption: 'Zerdrücken'),
      RecipeIngredient(name: 'Gemischtes Gemüse', amount: '300 g'),
    ],
  ),
];
