import 'dart:math';

import 'package:flutter/material.dart';
import 'package:parentpeak/models/day_plan.dart';
import 'package:parentpeak/models/recipe.dart';

enum ChildStage { baby, toddler, school }

class WeeklyPlannerController extends ChangeNotifier {
  WeeklyPlannerController({
    required List<Recipe> initialRecipes,
    required DateTime weekStart,
  })  : _recipes = List<Recipe>.from(initialRecipes),
        _weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day) {
    _ensureWeekPlans();
  }

  final List<Recipe> _recipes;
  final Map<String, DayPlan> _plansByDateKey = {};

  DateTime _weekStart;
  ChildStage _childStage = ChildStage.toddler;

  static const List<String> _leftoverAnimals = [
    'Pinguin',
    'Koala',
    'Tiger',
    'Otter',
    'Panda',
    'Fuchs',
  ];

  DateTime get weekStart => _weekStart;
  ChildStage get childStage => _childStage;
  List<Recipe> get recipes => List<Recipe>.unmodifiable(_recipes);

  int get plannedDinnerCount =>
      weekPlans.where((plan) => (plan.dinnerRecipeId ?? '').isNotEmpty).length;

  int get chaosDayCount => weekPlans.where((plan) => plan.isChaosDay).length;

  int get freezerItemsCount =>
      _plansByDateKey.values.where((plan) => (plan.leftoverCode ?? '').isNotEmpty).length;

  int weekConflictCount() {
    var count = 0;
    for (final plan in weekPlans) {
      if (hasKitaDinnerConflict(plan.date)) {
        count++;
      }
    }
    return count;
  }

  List<DayPlan> get weekPlans {
    final items = <DayPlan>[];
    for (var i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      items.add(_planFor(day));
    }
    return items;
  }

  Recipe? findRecipeById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final recipe in _recipes) {
      if (recipe.id == id) {
        return recipe;
      }
    }
    return null;
  }

  void setChildStage(ChildStage stage) {
    _childStage = stage;
    notifyListeners();
  }

  List<String> babyLedWeaningTips(Recipe recipe) {
    if (_childStage != ChildStage.baby) return const [];

    final tips = <String>[
      'Vor dem Salzen eine Baby-Portion entnehmen.',
      'Gemuese weich garen und in greifbare Sticks schneiden.',
    ];

    final hasBabyOptions = recipe.ingredients.any(
      (ingredient) => (ingredient.babyOption ?? '').trim().isNotEmpty,
    );

    if (hasBabyOptions) {
      tips.add('Nutze die Baby-Optionen bei den Zutaten für die Baby-Portion.');
    }

    if (recipe.hideVegetables) {
      tips.add('Fuer Babys Gemuese nicht verstecken, sondern sichtbar anbieten.');
    }

    return tips;
  }

  void setKitaLunch(DateTime date, String value) {
    final plan = _planFor(date);
    _setPlan(
      plan.copyWith(
        kitaLunch: value,
      ),
    );
  }

  void setDinnerRecipe(DateTime date, String? recipeId) {
    final plan = _planFor(date);
    _setPlan(
      plan.copyWith(
        dinnerRecipeId: recipeId,
        clearDinnerRecipeId: recipeId == null,
      ),
    );
  }

  bool hasKitaDinnerConflict(DateTime date) {
    final plan = _planFor(date);
    final dinner = findRecipeById(plan.dinnerRecipeId);
    if (dinner == null || plan.kitaLunch.trim().isEmpty) return false;

    final dinnerCategory = _categorizeText(dinner.title);
    final lunchCategory = _categorizeText(plan.kitaLunch);
    return dinnerCategory.isNotEmpty && dinnerCategory == lunchCategory;
  }

  bool activateChaosAndSwap(DateTime date) {
    final plan = _planFor(date);
    final oldRecipeId = plan.dinnerRecipeId;

    final replacement = _findChaosReplacement(excludeRecipeId: oldRecipeId);
    if (replacement == null) {
      _setPlan(plan.copyWith(isChaosDay: true));
      return false;
    }

    _setPlan(
      plan.copyWith(
        isChaosDay: true,
        dinnerRecipeId: replacement.id,
      ),
    );

    if (oldRecipeId != null && oldRecipeId.isNotEmpty) {
      final freeDay = _findNextFreeDay(excludingDate: date);
      if (freeDay != null) {
        final freePlan = _planFor(freeDay);
        _setPlan(
          freePlan.copyWith(
            dinnerRecipeId: oldRecipeId,
          ),
          notify: false,
        );
      }
    }

    notifyListeners();
    return true;
  }

  Recipe? suggestChaosRecipe(DateTime date) {
    final plan = _planFor(date);
    return _findChaosReplacement(excludeRecipeId: plan.dinnerRecipeId);
  }

  String freezeLeftover(DateTime date) {
    final code = _generateLeftoverCode();
    final plan = _planFor(date);
    _setPlan(plan.copyWith(leftoverCode: code));
    return code;
  }

  void clearLeftover(DateTime date) {
    final plan = _planFor(date);
    _setPlan(plan.copyWith(clearLeftoverCode: true));
  }

  String? freezerSuggestionText(DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    for (final entry in _plansByDateKey.values) {
      if (entry.leftoverCode == null || entry.leftoverCode!.isEmpty) continue;
      if (!entry.date.isBefore(checkDate)) continue;

      final recipe = findRecipeById(entry.dinnerRecipeId);
      final recipeTitle = recipe?.title ?? 'ein Gericht';
      return 'Im Gefrierfach wartet noch ${entry.leftoverCode} ($recipeTitle). Jetzt einplanen?';
    }
    return null;
  }

  void moveToWeek(DateTime newWeekStart) {
    _weekStart = DateTime(newWeekStart.year, newWeekStart.month, newWeekStart.day);
    _ensureWeekPlans();
    notifyListeners();
  }

  Map<String, dynamic> exportWeekMap() {
    return {
      'weekStart': _weekStart.toIso8601String(),
      'plans': weekPlans.map((plan) => plan.toMap()).toList(),
    };
  }

  void replaceWeekPlans(List<DayPlan> plans, {bool notify = true}) {
    for (final plan in plans) {
      final normalizedDate = DateTime(plan.date.year, plan.date.month, plan.date.day);
      _plansByDateKey[_dateKey(normalizedDate)] = plan.copyWith(date: normalizedDate);
    }

    _ensureWeekPlans();
    if (notify) {
      notifyListeners();
    }
  }

  void _ensureWeekPlans() {
    for (var i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      final key = _dateKey(day);
      _plansByDateKey.putIfAbsent(
        key,
        () => DayPlan(
          date: day,
          dinnerRecipeId: null,
          kitaLunch: '',
          isChaosDay: false,
          leftoverCode: null,
        ),
      );
    }
  }

  DayPlan _planFor(DateTime date) {
    final key = _dateKey(date);
    return _plansByDateKey.putIfAbsent(
      key,
      () => DayPlan(
        date: DateTime(date.year, date.month, date.day),
        dinnerRecipeId: null,
        kitaLunch: '',
        isChaosDay: false,
        leftoverCode: null,
      ),
    );
  }

  void _setPlan(DayPlan plan, {bool notify = true}) {
    _plansByDateKey[_dateKey(plan.date)] = plan;
    if (notify) {
      notifyListeners();
    }
  }

  Recipe? _findChaosReplacement({String? excludeRecipeId}) {
    final express = _recipes.where((recipe) {
      final title = recipe.title.toLowerCase();
      final fastEnough = recipe.durationMinutes > 0 && recipe.durationMinutes < 15;
      final pantryHint = title.contains('vorrat') ||
          title.contains('pasta') ||
          title.contains('nudel') ||
          title.contains('one-pot') ||
          recipe.isOnePot;
      return (fastEnough || pantryHint) && recipe.id != excludeRecipeId;
    }).toList();

    if (express.isEmpty) return null;
    express.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return express.first;
  }

  DateTime? _findNextFreeDay({required DateTime excludingDate}) {
    final normalizedExcluding = DateTime(
      excludingDate.year,
      excludingDate.month,
      excludingDate.day,
    );

    for (var i = 0; i < 14; i++) {
      final day = _weekStart.add(Duration(days: i));
      if (day == normalizedExcluding) continue;
      final plan = _planFor(day);
      if ((plan.dinnerRecipeId ?? '').isEmpty) {
        return day;
      }
    }
    return null;
  }

  String _generateLeftoverCode() {
    final random = Random();
    final animal = _leftoverAnimals[random.nextInt(_leftoverAnimals.length)];
    final number = random.nextInt(9) + 1;
    return '$animal-$number';
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _categorizeText(String value) {
    final text = value.toLowerCase();
    if (text.contains('reis') || text.contains('milchreis')) return 'reis';
    if (text.contains('pasta') || text.contains('nudel')) return 'pasta';
    if (text.contains('kartoffel')) return 'kartoffel';
    if (text.contains('suppe') || text.contains('eintopf')) return 'suppe';
    if (text.contains('pizza')) return 'pizza';
    return '';
  }
}