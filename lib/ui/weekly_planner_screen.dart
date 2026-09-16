import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/weekly_planner_controller.dart';
import 'package:parentpeak/logic/weekly_planner_storage_service.dart';
import 'package:parentpeak/models/meal_memory.dart';
import 'package:parentpeak/models/recipe.dart';
import 'package:parentpeak/ui/weekly_planner_view.dart';

String _t(String key) =>
  AppStringsManager.phase1String(languageService.currentLanguage, key);


class WeeklyPlannerScreen extends StatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  late final WeeklyPlannerController _controller;
  late final WeeklyPlannerStorageService _storage;

  bool _loading = true;
  bool _hydrating = false;
  bool _persisting = false;
  bool _pendingPersist = false;
  String? _syncInfo;
  PlannerTone _tone = PlannerTone.warm;

  Set<String> _pantryItems = {
    'reis',
    'pasta',
    'nudeln',
    'tomatensosse',
    'frischkaese',
    'kokosmilch',
  };
  List<MealMemory> _yearMemories = [];

  @override
  void initState() {
    super.initState();
    _storage = BackendServiceFactory.createWeeklyPlannerStorageService();
    _controller = WeeklyPlannerController(
      initialRecipes: kDebugMode ? _demoRecipes : const <Recipe>[],
      weekStart: _startOfWeek(DateTime.now()),
    );

    // Setze eine sinnvolle Starter-Woche, damit die Kern-Features direkt testbar sind.
    final monday = _controller.weekStart;
    _controller.setDinnerRecipe(monday, 'r-1');
    _controller.setDinnerRecipe(monday.add(const Duration(days: 1)), 'r-3');
    _controller.setDinnerRecipe(monday.add(const Duration(days: 2)), 'r-5');
    _controller.setKitaLunch(
      monday.add(const Duration(days: 2)), _t('planner_demo_kita_lunch'));

    _controller.addListener(_onPlannerChanged);
    _loadInitialWeek();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlannerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitialWeek() async {
    setState(() => _loading = true);
    _hydrating = true;

    final plans = await _storage.loadWeek(_controller.weekStart);
    if (plans.isNotEmpty) {
      _controller.replaceWeekPlans(plans, notify: false);
    }

    final pantry = await _storage.loadPantryItems();
    if (pantry.isNotEmpty) {
      _pantryItems = pantry;
    }
    _yearMemories = await _storage.loadMealMemoriesForYear(DateTime.now().year);

    _hydrating = false;
    if (!mounted) return;

    setState(() {
      _syncInfo = _storage.lastSyncError;
      _loading = false;
    });
  }

  void _onPlannerChanged() {
    if (_hydrating) return;
    _persistWeek();
  }

  Future<void> _persistWeek() async {
    if (_persisting) {
      _pendingPersist = true;
      return;
    }

    _persisting = true;
    do {
      _pendingPersist = false;
      await _storage.saveWeek(_controller.weekStart, _controller.weekPlans);

      if (mounted) {
        setState(() {
          _syncInfo = _storage.lastSyncError;
        });
      }
    } while (_pendingPersist);

    _persisting = false;
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = viewportWidth >= 1280
        ? 1040.0
        : viewportWidth >= 980
            ? 920.0
            : double.infinity;
    final horizontalPadding = viewportWidth >= 980 ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('planner_title')),
        actions: [
          PopupMenuButton<PlannerTone>(
            tooltip: context.tr('tooltip_tone'),
            initialValue: _tone,
            onSelected: (value) {
              setState(() {
                _tone = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: PlannerTone.warm,
                child: Text(_t('planner_tone_warm')),
              ),
              PopupMenuItem(
                value: PlannerTone.clear,
                child: Text(_t('planner_tone_clear')),
              ),
              PopupMenuItem(
                value: PlannerTone.premium,
                child: Text(_t('planner_tone_premium')),
              ),
            ],
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  children: [
                    if (_syncInfo != null && _syncInfo!.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          10,
                          horizontalPadding,
                          0,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_syncInfo!),
                      ),
                    if (_yearMemories.isNotEmpty)
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: _YearRecapCard(
                          memories: _yearMemories,
                          recipes: _demoRecipes,
                        ),
                      ),
                    Expanded(
                      child: WeeklyPlannerView(
                        controller: _controller,
                        tone: _tone,
                        onImportKitaPlan: _openKitaImport,
                        onEditPantry: _openPantryEditor,
                        pantryMissingIngredientsBuilder:
                            _pantryMissingIngredients,
                        onSaveFamilyMoment: _saveFamilyMoment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<String> _pantryMissingIngredients(Recipe recipe) {
    final missing = <String>[];
    for (final ingredient in recipe.ingredients) {
      final token = ingredient.name.trim().toLowerCase();
      if (token.isEmpty) continue;

      final exists = _pantryItems
          .any((item) => token.contains(item) || item.contains(token));

      if (!exists) {
        missing.add(ingredient.name);
      }
    }
    return missing;
  }

  Future<void> _openPantryEditor() async {
    final temp = TextEditingController(
      text: (_pantryItems.toList()..sort()).join(', '),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_t('planner_update_pantry')),
          content: TextField(
            controller: temp,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _t('planner_pantry_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('finance_save')),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;

    final items = temp.text
        .split(RegExp(r'[,\n]'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();

    setState(() {
      _pantryItems = items;
    });

    await _storage.savePantryItems(items);
  }

  Future<void> _openKitaImport() async {
    final textController = TextEditingController();
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('planner_import_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_t('planner_import_body')),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                minLines: 5,
                maxLines: 8,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: _t('planner_import_hint'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(_t('cancel')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(_t('planner_import')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (apply != true || !mounted) return;

    final extracted = _extractKitaLunchByWeekday(textController.text);
    if (extracted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('planner_import_invalid'))),
      );
      return;
    }

    _hydrating = true;
    for (final entry in extracted.entries) {
      final date = _controller.weekStart.add(Duration(days: entry.key));
      _controller.setKitaLunch(date, entry.value);
    }
    _hydrating = false;
    await _persistWeek();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('weekly_kita_imported')
            .replaceAll('{count}', '${extracted.length}'))),
    );
  }

  Map<int, String> _extractKitaLunchByWeekday(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final days = <String, int>{
      'montag': 0,
      'dienstag': 1,
      'mittwoch': 2,
      'donnerstag': 3,
      'freitag': 4,
      'samstag': 5,
      'sonntag': 6,
    };

    final result = <int, String>{};
    for (final line in lines) {
      final normalized = line.toLowerCase();
      for (final entry in days.entries) {
        if (!normalized.startsWith(entry.key)) continue;

        final value = line
            .substring(entry.key.length)
            .replaceFirst(':', '')
            .replaceFirst('-', '')
            .trim();
        if (value.isNotEmpty) {
          result[entry.value] = value;
        }
      }
    }
    return result;
  }

  Future<void> _saveFamilyMoment(DateTime date, String? recipeId) async {
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_t('planner_capture_moment')),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _t('planner_moment_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('finance_save')),
            ),
          ],
        );
      },
    );

    if (saved != true) return;
    final note = noteController.text.trim();
    if (note.isEmpty) return;

    final memory = MealMemory(
      id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      recipeId: recipeId,
      note: note,
      photoPath: null,
    );
    await _storage.saveMealMemory(memory);
    final memories =
        await _storage.loadMealMemoriesForYear(DateTime.now().year);

    if (!mounted) return;
    setState(() {
      _yearMemories = memories;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('planner_moment_saved'))),
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final daysFromMonday = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: daysFromMonday));
  }
}

class _YearRecapCard extends StatelessWidget {
  const _YearRecapCard({
    required this.memories,
    required this.recipes,
  });

  final List<MealMemory> memories;
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipeById = {
      for (final recipe in recipes) recipe.id: recipe.title,
    };

    final counts = <String, int>{};
    for (final memory in memories) {
      final id = memory.recipeId;
      if (id == null || id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('planner_year_recap').replaceAll('{year}', '${DateTime.now().year}'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (top.isEmpty)
            Text(_t('planner_no_moments'))
          else
            for (final entry in top.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                    _t('planner_recap_item')
                      .replaceAll('{recipe}', recipeById[entry.key] ?? _t('planner_unknown_recipe'))
                      .replaceAll('{count}', '${entry.value}'),
                ),
              ),
          if (memories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
                _t('planner_latest_moment')
                  .replaceAll('{date}', DateFormat('dd.MM.yyyy').format(memories.first.date))
                  .replaceAll('{note}', memories.first.note),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

List<Recipe> get _demoRecipes => [
  Recipe(
    id: 'r-1',
    title: _t('planner_recipe_1_title'),
    durationMinutes: 14,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: true,
    ingredients: [
        RecipeIngredient(
          name: _t('planner_demo_ingredient_pasta'), amount: _t('planner_demo_amount_300_g'), babyOption: _t('planner_demo_baby_soft_cook')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_broccoli'),
          amount: _t('planner_demo_amount_200_g'),
          babyOption: _t('planner_demo_baby_small_florets')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_cream_cheese'),
          amount: _t('planner_demo_amount_150_g'),
          babyOption: _t('planner_demo_baby_no_salt')),
    ],
  ),
  Recipe(
    id: 'r-2',
    title: _t('planner_recipe_2_title'),
    durationMinutes: 12,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(
          name: _t('planner_demo_ingredient_precooked_rice'),
          amount: _t('planner_demo_amount_400_g'),
          babyOption: _t('planner_demo_baby_mix_puree')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_peas'), amount: _t('planner_demo_amount_120_g'), babyOption: _t('planner_demo_baby_mash_well')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_egg'), amount: _t('planner_demo_amount_2_pieces'), babyOption: _t('planner_demo_baby_cook_thoroughly')),
    ],
  ),
  Recipe(
    id: 'r-3',
    title: _t('planner_recipe_3_title'),
    durationMinutes: 45,
    isPickEaterFriendly: false,
    isOnePot: false,
    hideVegetables: true,
    ingredients: [
      RecipeIngredient(
          name: _t('planner_demo_ingredient_lasagne_sheets'),
          amount: _t('planner_demo_amount_12_pieces'),
          babyOption: _t('planner_demo_baby_bake_soft')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_minced_or_lentils'),
          amount: '400 g',
          babyOption: _t('planner_demo_baby_chop_finely')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_tomato_sauce'),
          amount: _t('planner_demo_amount_500_ml'),
          babyOption: _t('planner_demo_baby_remove_before_salt')),
    ],
  ),
  Recipe(
    id: 'r-4',
    title: _t('planner_recipe_4_title'),
    durationMinutes: 13,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(
          name: _t('planner_demo_ingredient_potatoes'), amount: _t('planner_demo_amount_600_g'), babyOption: _t('planner_demo_baby_mash_finely')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_carrots'), amount: _t('planner_demo_amount_2_pieces'), babyOption: _t('planner_demo_baby_soft_cook')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_vegetable_stock'),
          amount: _t('planner_demo_amount_750_ml'),
          babyOption: _t('planner_demo_baby_water_only')),
    ],
  ),
  Recipe(
    id: 'r-5',
    title: _t('planner_recipe_5_title'),
    durationMinutes: 25,
    isPickEaterFriendly: true,
    isOnePot: false,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(
          name: _t('planner_demo_ingredient_rice'), amount: _t('planner_demo_amount_300_g'), babyOption: _t('planner_demo_baby_cook_longer')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_pepper'),
          amount: _t('planner_demo_amount_2_pieces'),
          babyOption: _t('planner_demo_baby_peeled_diced')),
      RecipeIngredient(
          name: _t('planner_demo_ingredient_zucchini'), amount: _t('planner_demo_amount_1_piece'), babyOption: _t('planner_demo_baby_steam_soft')),
    ],
  ),
];
