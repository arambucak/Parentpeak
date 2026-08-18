import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/models/cooking_hub.dart';
import 'package:parentpeak/models/guerilla_recipe.dart';
import 'package:parentpeak/models/kitchen_sos.dart';
import 'package:parentpeak/models/local_help_profile.dart';
import 'package:parentpeak/models/recipe.dart';

class HubPlanningResult {
  const HubPlanningResult({
    required this.currentWeekPlanner,
    required this.weeklyHistoryByWeekStart,
    required this.fairnessCookCountByUserId,
  });

  final Map<String, String> currentWeekPlanner;
  final Map<String, Map<String, String>> weeklyHistoryByWeekStart;
  final Map<String, int> fairnessCookCountByUserId;
}

class KettenbrecherService {
  const KettenbrecherService();

  GuerillaRecipe generateGuerillaRecipe({
    required Recipe baseRecipe,
    required List<String> dislikedHealthyIngredients,
  }) {
    final mapping = <String, AiTarnStep>{};

    for (final ingredient in dislikedHealthyIngredients) {
      final key = ingredient.trim().toLowerCase();
      if (key.isEmpty) continue;
      mapping[key] = _templateForIngredient(key);
    }

    return GuerillaRecipe(
      id: '${baseRecipe.id}-guerilla',
      title: baseRecipe.title,
      ingredients: baseRecipe.ingredients,
      durationMinutes: baseRecipe.durationMinutes,
      isPickEaterFriendly: true,
      isOnePot: baseRecipe.isOnePot,
      hideVegetables: true,
      aiTarnMapping: mapping,
    );
  }

  GuerillaRecipe generateGuerillaRecipeFromPrompt({
    required Recipe baseRecipe,
    required String parentPrompt,
    required List<String> candidateHealthyIngredients,
  }) {
    final prompt = parentPrompt.toLowerCase();
    final inferred = _inferIngredientsFromPrompt(
      prompt: prompt,
      candidates: candidateHealthyIngredients,
      baseRecipe: baseRecipe,
    );

    final prefersCreamy =
        prompt.contains('cremig') || prompt.contains('smooth');
    final avoidsPieces = prompt.contains('keine stuecke') ||
        prompt.contains('ohne stuecke') ||
        prompt.contains('nicht sichtbar') ||
        prompt.contains('unsichtbar');
    final tomatoPreferred = prompt.contains('tomate') || prompt.contains('rot');

    final mapping = <String, AiTarnStep>{};
    for (final ingredient in inferred) {
      mapping[ingredient] = _promptAwareStep(
        ingredient: ingredient,
        prefersCreamy: prefersCreamy,
        avoidsPieces: avoidsPieces,
        tomatoPreferred: tomatoPreferred,
      );
    }

    return GuerillaRecipe(
      id: '${baseRecipe.id}-guerilla-ai',
      title: '${baseRecipe.title} (KI-Guerilla)',
      ingredients: baseRecipe.ingredients,
      durationMinutes: baseRecipe.durationMinutes,
      isPickEaterFriendly: true,
      isOnePot: baseRecipe.isOnePot,
      hideVegetables: true,
      aiTarnMapping: mapping,
    );
  }

  GuerillaRecipe? generateGuerillaRecipeFromGeminiJson({
    required Recipe baseRecipe,
    required String jsonText,
  }) {
    final extracted = _extractJsonBlock(jsonText);
    if (extracted == null || extracted.isEmpty) return null;

    try {
      final decoded = jsonDecode(extracted);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      final rawSteps = map['aiTarnMapping'];
      if (rawSteps is! List) return null;

      final mapping = <String, AiTarnStep>{};
      for (final item in rawSteps) {
        if (item is! Map) continue;
        final step = Map<String, dynamic>.from(item);
        final key = (step['ingredientKey'] ?? step['hiddenIngredient'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (key.isEmpty) continue;

        mapping[key] = AiTarnStep(
          hiddenIngredient:
              step['hiddenIngredient']?.toString() ?? _capitalize(key),
          camouflageMethod:
              step['camouflageMethod']?.toString() ?? 'fein einarbeiten',
          textureHint: step['textureHint']?.toString() ?? 'glatt einruehren',
          colorHint: step['colorHint']?.toString() ?? 'farblich angleichen',
        );
      }

      if (mapping.isEmpty) return null;

      return GuerillaRecipe(
        id: '${baseRecipe.id}-guerilla-gemini',
        title: '${baseRecipe.title} (KI-JSON)',
        ingredients: baseRecipe.ingredients,
        durationMinutes: baseRecipe.durationMinutes,
        isPickEaterFriendly: true,
        isOnePot: baseRecipe.isOnePot,
        hideVegetables: true,
        aiTarnMapping: mapping,
      );
    } catch (e) {
      debugPrint('KettenbrecherService._parseGeminiRecipeJson(): failed: $e');
      return null;
    }
  }

  List<AiTarnStep> visibleTarnSteps(
      GuerillaRecipe recipe, double levelPercent) {
    final all = recipe.aiTarnMapping.values.toList();
    if (all.isEmpty || levelPercent <= 0) return const [];

    final ratio = (levelPercent / 100).clamp(0.0, 1.0);
    final count = math.max(1, (all.length * ratio).round());
    return all.take(count).toList();
  }

  CookingHub generateFairWeeklyRotation({
    required String id,
    required String hubName,
    required List<String> memberUserIds,
    required DateTime weekStart,
    required Map<String, List<String>> childAllergiesByUserId,
    required Map<String, List<String>> childPreferencesByUserId,
  }) {
    final result = generateMultiWeekRotationPlan(
      memberUserIds: memberUserIds,
      weekStart: weekStart,
      weeksAhead: 4,
      childAllergiesByUserId: childAllergiesByUserId,
      childPreferencesByUserId: childPreferencesByUserId,
    );

    return CookingHub(
      id: id,
      hubName: hubName,
      memberUserIds: memberUserIds,
      weeklyRotationalPlanner: result.currentWeekPlanner,
      weeklyRotationHistoryByWeekStart: result.weeklyHistoryByWeekStart,
      fairnessCookCountByUserId: result.fairnessCookCountByUserId,
      childAllergiesByUserId: childAllergiesByUserId,
      childPreferencesByUserId: childPreferencesByUserId,
    );
  }

  HubPlanningResult generateMultiWeekRotationPlan({
    required List<String> memberUserIds,
    required DateTime weekStart,
    required int weeksAhead,
    required Map<String, List<String>> childAllergiesByUserId,
    required Map<String, List<String>> childPreferencesByUserId,
  }) {
    final normalizedStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final fairnessBias = <String, int>{
      for (final member in memberUserIds)
        member: _restrictionScore(
          childAllergiesByUserId[member] ?? const [],
          childPreferencesByUserId[member] ?? const [],
        ),
    };

    final cookCount = <String, int>{
      for (final member in memberUserIds) member: 0
    };
    final history = <String, Map<String, String>>{};

    for (var weekIndex = 0; weekIndex < weeksAhead; weekIndex++) {
      final weekDate = normalizedStart.add(Duration(days: weekIndex * 7));
      final weekPlanner = <String, String>{};

      for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
        final day = weekDate.add(Duration(days: dayIndex));
        final rankedMembers = memberUserIds.toList()
          ..sort((a, b) {
            final aScore = (cookCount[a] ?? 0) - (fairnessBias[a] ?? 0);
            final bScore = (cookCount[b] ?? 0) - (fairnessBias[b] ?? 0);
            final byNeed = aScore.compareTo(bScore);
            if (byNeed != 0) return byNeed;
            return a.compareTo(b);
          });

        final assigned = rankedMembers.first;
        cookCount[assigned] = (cookCount[assigned] ?? 0) + 1;
        weekPlanner[DateFormat('yyyy-MM-dd').format(day)] = assigned;
      }

      history[DateFormat('yyyy-MM-dd').format(weekDate)] = weekPlanner;
    }

    final currentWeekKey = DateFormat('yyyy-MM-dd').format(normalizedStart);
    final currentWeekPlanner =
        history[currentWeekKey] ?? const <String, String>{};

    return HubPlanningResult(
      currentWeekPlanner: currentWeekPlanner,
      weeklyHistoryByWeekStart: history,
      fairnessCookCountByUserId: cookCount,
    );
  }

  List<String> findNearbyResponders({
    required GeoCoordinates senderLocation,
    required Map<String, GeoCoordinates> allParents,
    required double radiusMeters,
  }) {
    final responders = <String>[];

    allParents.forEach((userId, location) {
      final distance = distanceMeters(senderLocation, location);
      if (distance <= radiusMeters) {
        responders.add(userId);
      }
    });

    return responders;
  }

  List<String> findTrustedNearbyResponders({
    required String requesterUserId,
    required GeoCoordinates senderLocation,
    required Map<String, GeoCoordinates> allParents,
    required List<LocalHelpProfile> helpProfiles,
    required double radiusMeters,
  }) {
    final profileById = {
      for (final profile in helpProfiles) profile.userId: profile,
    };

    final responders = <String>[];
    allParents.forEach((userId, location) {
      final profile = profileById[userId];
      if (profile == null) return;
      if (!profile.optedInForKitchenSos) return;
      if (!profile.isTrustedBy(requesterUserId)) return;

      final distance = distanceMeters(senderLocation, location);
      final effectiveRadius =
          math.min(radiusMeters, profile.maxSupportRadiusMeters);
      if (distance <= effectiveRadius) {
        responders.add(userId);
      }
    });

    return responders;
  }

  Map<String, dynamic> prepareSosPushPayload({
    required KitchenSos sos,
    required List<String> recipientUserIds,
    required double radiusMeters,
  }) {
    return {
      'type': 'kitchen_sos',
      'priority': 'high',
      'senderId': sos.senderId,
      'sosId': sos.id,
      'radiusMeters': radiusMeters,
      'createdAt': sos.createdAt.toIso8601String(),
      'recipientUserIds': recipientUserIds,
      'message':
          'SOS in der Nachbarschaft: Eine Familie braucht jetzt Unterstützung',
    };
  }

  double distanceMeters(GeoCoordinates a, GeoCoordinates b) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);

    final haversine = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 *
        math.atan2(
            math.sqrt(haversine as num), math.sqrt(1 - (haversine as num)));
    return earthRadius * c;
  }

  AiTarnStep _templateForIngredient(String key) {
    if (key.contains('zucchini')) {
      return const AiTarnStep(
        hiddenIngredient: 'Zucchini',
        camouflageMethod: 'fein raspeln und in der Sosse verkochen',
        textureHint: 'zum Schluss samtig puerieren',
        colorHint: 'mit Tomatenmark und Gewuerzen angleichen',
      );
    }

    if (key.contains('lins')) {
      return const AiTarnStep(
        hiddenIngredient: 'Rote Linsen',
        camouflageMethod: 'als Bindung in Tomaten- oder Kaesesosse kochen',
        textureHint: 'mit Nudelwasser glattziehen',
        colorHint: 'in rote oder braune Sosse einbauen',
      );
    }

    if (key.contains('spinat')) {
      return const AiTarnStep(
        hiddenIngredient: 'Babyspinat',
        camouflageMethod: 'kurz blanchieren und mit Frischkaese mixen',
        textureHint: 'als cremige Zwischenlage unterheben',
        colorHint: 'mit Kaese oder Sosse optisch neutralisieren',
      );
    }

    return AiTarnStep(
      hiddenIngredient: _capitalize(key),
      camouflageMethod: 'sehr fein schneiden und spaet einruehren',
      textureHint: 'mit Sosse oder Puerree binden',
      colorHint: 'in gleichfarbige Komponenten mischen',
    );
  }

  AiTarnStep _promptAwareStep({
    required String ingredient,
    required bool prefersCreamy,
    required bool avoidsPieces,
    required bool tomatoPreferred,
  }) {
    final base = _templateForIngredient(ingredient);

    final method = avoidsPieces
        ? '${base.camouflageMethod}; danach komplett puerieren'
        : base.camouflageMethod;

    final texture = prefersCreamy
        ? '${base.textureHint}; mit Frischkaese oder Joghurt abrunden'
        : base.textureHint;

    final color = tomatoPreferred
        ? 'in tomatiger Basis tarnen; ${base.colorHint}'
        : base.colorHint;

    return AiTarnStep(
      hiddenIngredient: base.hiddenIngredient,
      camouflageMethod: method,
      textureHint: texture,
      colorHint: color,
    );
  }

  List<String> _inferIngredientsFromPrompt({
    required String prompt,
    required List<String> candidates,
    required Recipe baseRecipe,
  }) {
    final normalizedCandidates = candidates
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList();

    final inferred = <String>[];

    for (final candidate in normalizedCandidates) {
      if (prompt.contains(candidate)) {
        inferred.add(candidate);
      }
    }

    if (inferred.isEmpty) {
      for (final ingredient in baseRecipe.ingredients) {
        final name = ingredient.name.toLowerCase();
        if (name.contains('zucchini')) inferred.add('zucchini');
        if (name.contains('linse')) inferred.add('linsen');
        if (name.contains('spinat')) inferred.add('spinat');
        if (name.contains('karotte')) inferred.add('karotte');
      }
    }

    if (inferred.isEmpty) {
      inferred.addAll(normalizedCandidates.take(3));
    }

    return inferred.toSet().toList();
  }

  String? _extractJsonBlock(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final fenced =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
            .firstMatch(input);
    if (fenced != null) {
      return fenced.group(1)?.trim();
    }

    final start = input.indexOf('{');
    final end = input.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return input.substring(start, end + 1).trim();
    }

    return null;
  }

  int _restrictionScore(List<String> allergies, List<String> preferences) {
    return allergies.length * 2 + preferences.length;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}
