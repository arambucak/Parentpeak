import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/logic/weekly_planner_controller.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/day_plan.dart';
import 'package:parentpeak/models/recipe.dart';

enum PlannerTone { warm, clear, premium }

String _plannerCopy(
  BuildContext context,
  PlannerTone tone,
  String key, {
  Map<String, String> values = const {},
}) {
  var value = AppStringsManager.getString(
    languageService.currentLanguage,
    'package3_planner_$key',
  );
  for (final entry in values.entries) {
    value = value.replaceAll('{${entry.key}}', entry.value);
  }
  return value;
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
                      _plannerCopy(context, tone, 'hero_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _plannerCopy(context, tone, 'hero_subtitle'),
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
                label: _plannerCopy(context, tone, 'planned_dinners',
                    values: {'count': '${controller.plannedDinnerCount}'}),
              ),
              _HeroStatChip(
                icon: Icons.flash_on_rounded,
                label: _plannerCopy(context, tone, 'chaos_swaps',
                    values: {'count': '${controller.chaosDayCount}'}),
              ),
              _HeroStatChip(
                icon: Icons.warning_amber_rounded,
                label: _plannerCopy(context, tone, 'conflicts',
                    values: {'count': '${controller.weekConflictCount()}'}),
              ),
              _HeroStatChip(
                icon: Icons.ac_unit_rounded,
                label: _plannerCopy(context, tone, 'freezer_items',
                    values: {'count': '${controller.freezerItemsCount}'}),
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
            segments: [
              ButtonSegment(value: ChildStage.baby, label: Text(_plannerCopy(context, tone, 'stage_baby'))),
              ButtonSegment(value: ChildStage.toddler, label: Text(_plannerCopy(context, tone, 'stage_toddler'))),
              ButtonSegment(value: ChildStage.school, label: Text(_plannerCopy(context, tone, 'stage_school'))),
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
              _plannerCopy(context, tone, 'quick_actions'),
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
                  label: Text(_plannerCopy(context, tone, 'emergency_swap')),
                  onPressed: () {
                    final monday = controller.weekStart;
                    final ok = controller.activateChaosAndSwap(monday);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? _plannerCopy(context, tone, 'swap_success')
                              : _plannerCopy(context, tone, 'swap_unavailable'),
                        ),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: Text(_plannerCopy(context, tone, 'import_lunch_plan')),
                  onPressed: onImportKitaPlan,
                ),
                ActionChip(
                  avatar: const Icon(Icons.kitchen_rounded, size: 18),
                  label: Text(_plannerCopy(context, tone, 'edit_pantry')),
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
              '${_capitalize(DateFormat('EEEE', languageService.currentLanguage).format(plan.date))} · ${DateFormat('dd.MM.').format(plan.date)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _RecipeRow(recipe: recipe, controller: controller, tone: tone, date: plan.date),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: plan.kitaLunch,
              decoration: InputDecoration(
                labelText: _plannerCopy(context, tone, 'lunch_label'),
                hintText: _plannerCopy(context, tone, 'lunch_hint'),
                prefixIcon: const Icon(Icons.school_rounded),
              ),
              onFieldSubmitted: (value) => controller.setKitaLunch(plan.date, value),
            ),
            if (hasConflict)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _plannerCopy(context, tone, 'meal_conflict'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (chaosSuggestion != null && !plan.isChaosDay)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _plannerCopy(context, tone, 'plan_b', values: {
                    'recipe': chaosSuggestion.title,
                    'minutes': '${chaosSuggestion.durationMinutes}',
                  }),
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
                    _plannerCopy(context, tone, 'baby_tip',
                      values: {'tip': blwTips.first}),
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
                  label: Text(_plannerCopy(context, tone, 'save_family_moment')),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final code = controller.freezeLeftover(plan.date);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_plannerCopy(context, tone, 'code_created', values: {'code': code}))),
                    );
                  },
                  icon: const Icon(Icons.ac_unit_rounded),
                  label: Text(_plannerCopy(context, tone, 'freeze_leftovers')),
                ),
                if ((plan.leftoverCode ?? '').isNotEmpty)
                  Chip(label: Text(_plannerCopy(context, tone, 'leftover_code', values: {'code': '${plan.leftoverCode}'})), onDeleted: () => controller.clearLeftover(plan.date)),
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
              Text(_plannerCopy(context, tone, 'dinner_label'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                recipe?.title ?? _plannerCopy(context, tone, 'no_dinner'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (recipe != null)
                Text(_plannerCopy(context, tone, 'recipe_meta', values: {
                  'minutes': '${recipe!.durationMinutes}',
                  'type': _plannerCopy(context, tone, recipe!.isOnePot ? 'one_pot' : 'standard'),
                }), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.swap_horiz_rounded),
          tooltip: _plannerCopy(context, tone, 'change_dinner'),
          onSelected: (recipeId) => controller.setDinnerRecipe(date, recipeId),
          itemBuilder: (context) => controller.recipes
              .map((item) => PopupMenuItem<String>(value: item.id, child: Text(item.title)))
              .toList(),
        ),
      ],
    );
  }
}
