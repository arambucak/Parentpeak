import 'dart:convert';

import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_backend_scope.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/models/meal_plan.dart';

/// Backend-Client für Essenspläne.
///
/// Sicherheitsgrenze (PR B2): Alle Aufrufe laufen über den verifizierten
/// Firebase-Client. Der Familienkontext wird NICHT mehr aus der globalen
/// Konfiguration (`demo-family-001`) abgeleitet, sondern serverseitig aus der
/// Token-UID über den reservierten Selector `own`. Eine fremde Familien-ID kann
/// nicht gesendet werden; der Server lehnt sie mit 403 ab.
///
/// Hinweis: Die Schreibmethoden (`saveMealPlan`, `addMeal`, `updateMeal`,
/// `deleteMeal`) werden aktuell von keiner UI aufgerufen — die lokale
/// Meal-Bearbeitung bleibt lokal. Sie sind trotzdem korrekt authentifiziert und
/// getestet, damit eine spätere Verdrahtung sicher ist.
class MealPlannerService {
  MealPlannerService(
      {BackendApiClient? apiClient, ProfileAccountStore? accountStore})
      : _apiClient = apiClient,
        _scope = FamilyBackendScope(accountStore: accountStore);

  final BackendApiClient? _apiClient;
  final FamilyBackendScope _scope;

  /// Reservierter Selector: "Familie der Token-UID", serverseitig aufgelöst.
  static const String _ownFamilySelector = 'own';

  static String _mealPlansBasePath() => APIConfig.getBackendMealPlansPath();

  BackendApiClient _client(ProfileAccountTicket? ticket) =>
      _scope.requireClient(_apiClient, ticket);

  /// Hole Essensplan für einen bestimmten Tag.
  Future<DayPlan?> getMealPlan(DateTime date,
      {ProfileAccountTicket? ticket}) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final path = '${_mealPlansBasePath()}/$_ownFamilySelector?date=$dateStr';
    final data = await _client(ticket).getJson(path);
    if (data is Map<String, dynamic>) return _parseDayPlan(data);
    return null;
  }

  /// Hole Wochenplan (7 Tage ab [startDate]).
  Future<WeekPlan?> getWeekMealPlan(DateTime startDate,
      {ProfileAccountTicket? ticket}) async {
    final dateStr = startDate.toIso8601String().split('T')[0];
    final path =
        '${_mealPlansBasePath()}/$_ownFamilySelector/week?startDate=$dateStr';
    final data = await _client(ticket).getJson(path);
    if (data is! List) return null;
    final days = data
        .whereType<Map<String, dynamic>>()
        .map<DayPlan>(_parseDayPlan)
        .toList();
    return WeekPlan(weekStart: startDate, days: days);
  }

  /// Erstelle oder aktualisiere den Essensplan eines Tages.
  Future<DayPlan?> saveMealPlan(
    DateTime date,
    List<Meal> meals, {
    ProfileAccountTicket? ticket,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final payload = {
      'date': dateStr,
      'meals': meals
          .map((meal) => {
                'title': meal.title,
                'type': meal.type.name,
                'description': meal.description,
                'ingredients': meal.ingredients,
              })
          .toList(),
    };
    final data = await _client(ticket)
        .postJsonAny('${_mealPlansBasePath()}/$_ownFamilySelector', payload);
    if (data is Map<String, dynamic>) return _parseDayPlan(data);
    return null;
  }

  /// Füge eine einzelne Mahlzeit zu einem Essensplan hinzu.
  Future<Meal?> addMeal(
    String mealPlanId,
    Meal meal, {
    ProfileAccountTicket? ticket,
  }) async {
    final payload = {
      'title': meal.title,
      'type': meal.type.name,
      'description': meal.description,
      'ingredients': meal.ingredients,
    };
    // Korrigierter Pfad: Backend mountet /api/meals/, nicht /meals/.
    final data =
        await _client(ticket).postJsonAny('/api/meals/$mealPlanId', payload);
    if (data is Map<String, dynamic>) return _parseMeal(data);
    return null;
  }

  /// Aktualisiere eine Mahlzeit.
  Future<Meal?> updateMeal(
    String mealId,
    Meal meal, {
    ProfileAccountTicket? ticket,
  }) async {
    final payload = {
      'title': meal.title,
      'type': meal.type.name,
      'description': meal.description,
      'ingredients': meal.ingredients,
    };
    final data = await _client(ticket).putJson('/api/meals/$mealId', payload);
    if (data is Map<String, dynamic>) return _parseMeal(data);
    return null;
  }

  /// Lösche eine Mahlzeit.
  Future<void> deleteMeal(String mealId, {ProfileAccountTicket? ticket}) async {
    await _client(ticket).delete('/api/meals/$mealId');
  }

  // ============================================================
  // Helper methods
  // ============================================================

  static DayPlan _parseDayPlan(Map<String, dynamic> data) {
    final meals = <Meal>[];
    if (data['meals'] != null) {
      for (var mealData in data['meals']) {
        if (mealData is Map<String, dynamic>) {
          meals.add(_parseMeal(mealData));
        }
      }
    }

    return DayPlan(
      date: DateTime.parse(data['date'] as String),
      meals: meals,
    );
  }

  static Meal _parseMeal(Map<String, dynamic> data) {
    final rawIngredients = data['ingredients'];
    final ingredients = rawIngredients is String
        ? List<String>.from(json.decode(rawIngredients))
        : rawIngredients is List
            ? List<String>.from(rawIngredients)
            : <String>[];

    final typeString = data['type'] as String;
    final mealType = MealType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => MealType.breakfast,
    );

    return Meal(
      id: data['id'] as String,
      title: data['title'] as String,
      type: mealType,
      description: data['description'] as String?,
      ingredients: ingredients,
    );
  }
}
