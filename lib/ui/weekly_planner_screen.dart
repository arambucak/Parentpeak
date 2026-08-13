import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/weekly_planner_controller.dart';
import 'package:parentpeak/logic/weekly_planner_storage_service.dart';
import 'package:parentpeak/models/meal_memory.dart';
import 'package:parentpeak/models/recipe.dart';
import 'package:parentpeak/ui/weekly_planner_view.dart';

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
    _controller.setKitaLunch(monday.add(const Duration(days: 2)), 'Gemuesesuppe');

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
        title: const Text('Essensplaner Pro'),
        actions: [
          PopupMenuButton<PlannerTone>(
            tooltip: 'Sprachstil',
            initialValue: _tone,
            onSelected: (value) {
              setState(() {
                _tone = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: PlannerTone.warm,
                child: Text('Ton: Warm'),
              ),
              PopupMenuItem(
                value: PlannerTone.clear,
                child: Text('Ton: Klar'),
              ),
              PopupMenuItem(
                value: PlannerTone.premium,
                child: Text('Ton: Premium ruhig'),
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
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                        pantryMissingIngredientsBuilder: _pantryMissingIngredients,
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

      final exists = _pantryItems.any((item) =>
          token.contains(item) || item.contains(token));

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
          title: const Text('Vorrat aktualisieren'),
          content: TextField(
            controller: temp,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'z. B. reis, pasta, kokosmilch, tomatensosse',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Speichern'),
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
              const Text(
                'Kita-/Schulplan importieren',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'OCR-ready: Erkannten Text einfuegen, wir ordnen automatisch den Wochentagen zu.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Montag: Milchreis\nDienstag: Nudeln\nMittwoch: Suppe',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Abbrechen'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Importieren'),
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
        const SnackBar(content: Text('Kein gueltiger Wochentag erkannt. Bitte Format pruefen.')),
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
      SnackBar(content: Text('${extracted.length} Kita-Eintraege uebernommen.')),
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
          title: const Text('Familienmoment festhalten'),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'z. B. Mia hat heute zum ersten Mal Brokkoli gegessen!',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Speichern'),
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
    final memories = await _storage.loadMealMemoriesForYear(DateTime.now().year);

    if (!mounted) return;
    setState(() {
      _yearMemories = memories;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Familienmoment gespeichert.')),
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
            'Jahresrueckblick ${DateTime.now().year}: Eure Top 5 Gerichte',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (top.isEmpty)
            const Text('Noch keine gespeicherten Familienmomente. Startet heute mit eurem ersten Highlight.')
          else
            for (final entry in top.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${recipeById[entry.key] ?? 'Unbekanntes Rezept'} (${entry.value}x)',
                ),
              ),
          if (memories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Neuester Moment: ${DateFormat('dd.MM.yyyy').format(memories.first.date)} - ${memories.first.note}',
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

const List<Recipe> _demoRecipes = [
  Recipe(
    id: 'r-1',
    title: 'One-Pot Pasta mit Brokkoli',
    durationMinutes: 14,
    isPickEaterFriendly: true,
    isOnePot: true,
    hideVegetables: true,
    ingredients: [
      RecipeIngredient(name: 'Pasta', amount: '300 g', babyOption: 'Sehr weich kochen'),
      RecipeIngredient(name: 'Brokkoli', amount: '200 g', babyOption: 'In kleine Roeschen dämpfen'),
      RecipeIngredient(name: 'Frischkaese', amount: '150 g', babyOption: 'Ohne Salz für Baby-Portion'),
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
      RecipeIngredient(name: 'Reis (vorgekocht)', amount: '400 g', babyOption: 'Mit Gemuesebrei mischen'),
      RecipeIngredient(name: 'Erbsen', amount: '120 g', babyOption: 'Gut zerdruecken'),
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
      RecipeIngredient(name: 'Gemuesebruehe', amount: '750 ml', babyOption: 'Fuer Baby nur Wasser verwenden'),
    ],
  ),
  Recipe(
    id: 'r-5',
    title: 'Gemuese-Reis-Pfanne',
    durationMinutes: 25,
    isPickEaterFriendly: true,
    isOnePot: false,
    hideVegetables: false,
    ingredients: [
      RecipeIngredient(name: 'Reis', amount: '300 g', babyOption: 'Etwas laenger garen'),
      RecipeIngredient(name: 'Paprika', amount: '2 Stk', babyOption: 'Geschält und fein gewuerfelt'),
      RecipeIngredient(name: 'Zucchini', amount: '1 Stk', babyOption: 'Weich dünsten'),
    ],
  ),
];