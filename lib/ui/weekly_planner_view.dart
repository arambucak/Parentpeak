import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/logic/weekly_planner_controller.dart';
import 'package:parentpeak/models/day_plan.dart';
import 'package:parentpeak/models/recipe.dart';

enum PlannerTone { warm, clear, premium }

String _toneCopy(
  PlannerTone tone,
  String warm,
  String clear, {
  String? premium,
}) {
  switch (tone) {
    case PlannerTone.warm:
      return warm;
    case PlannerTone.clear:
      return clear;
    case PlannerTone.premium:
      return premium ?? clear;
  }
}

class WeeklyPlannerView extends StatelessWidget {
  const WeeklyPlannerView({
    super.key,
    required this.controller,
    this.tone = PlannerTone.warm,
    this.onImportKitaPlan,
    this.onEditPantry,
    this.onSaveFamilyMoment,
    this.pantryMissingIngredientsBuilder,
  });

  final WeeklyPlannerController controller;
  final PlannerTone tone;
  final VoidCallback? onImportKitaPlan;
  final VoidCallback? onEditPantry;
  final Future<void> Function(DateTime date, String? recipeId)? onSaveFamilyMoment;
  final List<String> Function(Recipe recipe)? pantryMissingIngredientsBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final plans = controller.weekPlans;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _PlannerHero(controller: controller, tone: tone),
            const SizedBox(height: 10),
            _SmartActions(
              controller: controller,
              tone: tone,
              onImportKitaPlan: onImportKitaPlan,
              onEditPantry: onEditPantry,
            ),
            const SizedBox(height: 12),
            for (final plan in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayPlanCard(
                  plan: plan,
                  controller: controller,
                  tone: tone,
                  onSaveFamilyMoment: onSaveFamilyMoment,
                  pantryMissingIngredientsBuilder: pantryMissingIngredientsBuilder,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlannerHero extends StatelessWidget {
  const _PlannerHero({required this.controller, required this.tone});

  final WeeklyPlannerController controller;
  final PlannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = controller.weekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('dd.MM').format(weekStart)} - ${DateFormat('dd.MM').format(weekEnd)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _toneCopy(
                        tone,
                        'Was kochen wir heute? Geklaert.',
                        'Wochenplanung mit klarem Fokus',
                        premium: 'Essensplanung, ruhig organisiert.',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _toneCopy(
                        tone,
                        'Planen, tauschen, entspannt durch die Woche.',
                        'Schnell entscheiden, weniger Mental Load.',
                        premium: 'Strukturiert planen. Flexibel reagieren.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => controller
                    .moveToWeek(controller.weekStart.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left_rounded),
                color: Colors.white,
              ),
              Text(
                weekLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () =>
                    controller.moveToWeek(controller.weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right_rounded),
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStatChip(
                icon: Icons.restaurant_rounded,
                label: _toneCopy(
                  tone,
                  '${controller.plannedDinnerCount} Abende geplant',
                  '${controller.plannedDinnerCount} Dinner fixiert',
                  premium: '${controller.plannedDinnerCount} Menues gesetzt',
                ),
              ),
              _HeroStatChip(
                icon: Icons.flash_on_rounded,
                label: _toneCopy(
                  tone,
                  '${controller.chaosDayCount} Stress-Swap',
                  '${controller.chaosDayCount} Notfallwechsel',
                  premium: '${controller.chaosDayCount} flexible Anpassung',
                ),
              ),
              _HeroStatChip(
                icon: Icons.warning_amber_rounded,
                label: _toneCopy(
                  tone,
                  '${controller.weekConflictCount()} Doppel-Check',
                  '${controller.weekConflictCount()} Konflikte',
                  premium: '${controller.weekConflictCount()} Abgleichhinweise',
                ),
              ),
              _HeroStatChip(
                icon: Icons.ac_unit_rounded,
                label: _toneCopy(
                  tone,
                  '${controller.freezerItemsCount} Reste gerettet',
                  '${controller.freezerItemsCount} Gefrier-Posten',
                  premium: '${controller.freezerItemsCount} Vorratserinnerungen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ChildStage>(
            style: SegmentedButton.styleFrom(
              foregroundColor: Colors.white,
              selectedForegroundColor: theme.colorScheme.primary,
              selectedBackgroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
            ),
            segments: const [
              ButtonSegment(value: ChildStage.baby, label: Text('Baby')),
              ButtonSegment(value: ChildStage.toddler, label: Text('Kleinkind')),
              ButtonSegment(value: ChildStage.school, label: Text('Schulkind')),
            ],
            selected: {controller.childStage},
            onSelectionChanged: (value) => controller.setChildStage(value.first),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SmartActions extends StatelessWidget {
  const _SmartActions({
    required this.controller,
    required this.tone,
    this.onImportKitaPlan,
    this.onEditPantry,
  });

  final WeeklyPlannerController controller;
  final PlannerTone tone;
  final VoidCallback? onImportKitaPlan;
  final VoidCallback? onEditPantry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _toneCopy(tone, 'Heute schnell entlasten', 'Schnellaktionen', premium: 'Priorisierte Aktionen'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 18),
                  label: Text(_toneCopy(tone, 'Notfalltausch', 'Express-Tausch', premium: 'Adaptiver Tausch')),
                  onPressed: () {
                    final monday = controller.weekStart;
                    final ok = controller.activateChaosAndSwap(monday);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? _toneCopy(tone, 'Fertig. Ein Express-Gericht ist jetzt eingeplant.', 'Express-Gericht übernommen.', premium: 'Alternative wurde übernommen.')
                              : 'Kein Express-Gericht verfügbar.',
                        ),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: Text(_toneCopy(tone, 'Kita-Plan importieren', 'Lunch-Import', premium: 'Kita-Abgleich')),
                  onPressed: onImportKitaPlan,
                ),
                ActionChip(
                  avatar: const Icon(Icons.kitchen_rounded, size: 18),
                  label: Text(_toneCopy(tone, 'Vorrat pflegen', 'Pantry-Editor', premium: 'Vorrat abstimmen')),
                  onPressed: onEditPantry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPlanCard extends StatelessWidget {
  const _DayPlanCard({
    required this.plan,
    required this.controller,
    required this.tone,
    this.onSaveFamilyMoment,
    this.pantryMissingIngredientsBuilder,
  });

  final DayPlan plan;
  final WeeklyPlannerController controller;
  final PlannerTone tone;
  final Future<void> Function(DateTime date, String? recipeId)? onSaveFamilyMoment;
  final List<String> Function(Recipe recipe)? pantryMissingIngredientsBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = controller.findRecipeById(plan.dinnerRecipeId);
    final hasConflict = controller.hasKitaDinnerConflict(plan.date);
    final chaosSuggestion = controller.suggestChaosRecipe(plan.date);
    final freezerHint = controller.freezerSuggestionText(plan.date);
    final blwTips = recipe == null ? const <String>[] : controller.babyLedWeaningTips(recipe);
    final missingIngredients = recipe == null || pantryMissingIngredientsBuilder == null
        ? const <String>[]
        : pantryMissingIngredientsBuilder!(recipe);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_capitalize(DateFormat('EEEE', 'de_DE').format(plan.date))} · ${DateFormat('dd.MM.').format(plan.date)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _RecipeRow(recipe: recipe, controller: controller, tone: tone, date: plan.date),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: plan.kitaLunch,
              decoration: InputDecoration(
                labelText: 'Kita-/Schul-Mittagessen',
                hintText: _toneCopy(tone, 'z. B. Milchreis mit Apfelmus', 'z. B. Nudeln, Suppe, Milchreis', premium: 'z. B. Wochenspeise hier eintragen'),
                prefixIcon: const Icon(Icons.school_rounded),
              ),
              onFieldSubmitted: (value) => controller.setKitaLunch(plan.date, value),
            ),
            if (hasConflict)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _toneCopy(
                    tone,
                    'Mittag und Abend sind sehr ähnlich. Vorschlag: heute etwas Leichtes am Abend.',
                    'Mittag und Abend sind sehr ähnlich. Empfehlung: leichtes Dinner.',
                    premium: 'Hinweis: Mittags- und Abendgericht überschneiden sich deutlich.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (chaosSuggestion != null && !plan.isChaosDay)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_toneCopy(tone, 'Plan B steht bereit', 'Alternative verfügbar', premium: 'Alternative bereit')}: ${chaosSuggestion.title} (${chaosSuggestion.durationMinutes} Min)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (missingIngredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: missingIngredients.take(5).map((item) => Chip(label: Text(item))).toList(),
                ),
              ),
            if (blwTips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _toneCopy(tone, 'Baby-Modus Tipp: ${blwTips.first}', 'BLW-Hinweis: ${blwTips.first}', premium: 'Baby-Notiz: ${blwTips.first}'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSaveFamilyMoment == null ? null : () => onSaveFamilyMoment!(plan.date, recipe?.id),
                  icon: const Icon(Icons.favorite_rounded),
                  label: Text(_toneCopy(tone, 'Familienmoment speichern', 'Moment erfassen', premium: 'Moment dokumentieren')),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final code = controller.freezeLeftover(plan.date);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_toneCopy(tone, 'Code erstellt', 'Gefriercode', premium: 'Code')}: $code')),
                    );
                  },
                  icon: const Icon(Icons.ac_unit_rounded),
                  label: const Text('Reste einfrieren'),
                ),
                if ((plan.leftoverCode ?? '').isNotEmpty)
                  Chip(label: Text('Code: ${plan.leftoverCode}'), onDeleted: () => controller.clearLeftover(plan.date)),
              ],
            ),
            if (freezerHint != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(freezerHint, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    required this.recipe,
    required this.controller,
    required this.tone,
    required this.date,
  });

  final Recipe? recipe;
  final WeeklyPlannerController controller;
  final PlannerTone tone;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_toneCopy(tone, 'Heute Abend', 'Dinner-Slot', premium: 'Abendmenue'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                recipe?.title ?? _toneCopy(tone, 'Noch offen - bitte ein Gericht auswählen', 'Noch kein Dinner gesetzt', premium: 'Menue noch offen'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (recipe != null)
                Text('${recipe!.durationMinutes} Min · ${recipe!.isOnePot ? 'One-Pot' : 'Standard'}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.swap_horiz_rounded),
          tooltip: _toneCopy(tone, 'Gericht wechseln', 'Dinner ersetzen', premium: 'Menue wechseln'),
          onSelected: (recipeId) => controller.setDinnerRecipe(date, recipeId),
          itemBuilder: (context) => controller.recipes
              .map((item) => PopupMenuItem<String>(value: item.id, child: Text(item.title)))
              .toList(),
        ),
      ],
    );
  }
}
