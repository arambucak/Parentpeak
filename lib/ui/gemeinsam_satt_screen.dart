import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/models/food_share_post.dart';
import 'package:parentpeak/models/shared_recipe.dart';
import 'package:parentpeak/models/meal_plan.dart';
import 'package:parentpeak/models_and_widgets/animation_helpers.dart';
import 'package:parentpeak/services/meal_planner_service.dart';
import 'package:parentpeak/logic/gemeinsam_satt_backend_service.dart'
    as backend_service;

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);

// ============================================================
// GEMEINSAM SATT — Eltern-Essenssolidarität
// ============================================================

const Color _brand = Color(0xFFE8543A);
const Color _brandLight = Color(0xFFFFF1EE);
const Color _surface = Color(0xFFF8FAFD);
const Color _cardBg = Colors.white;

class _FoodInfoMeta {
  final String label;
  final Color tint;

  const _FoodInfoMeta(this.label, this.tint);
}

class _NearbyFilterPreset {
  final String id;
  final String label;
  final List<String> tags;

  const _NearbyFilterPreset({
    required this.id,
    required this.label,
    required this.tags,
  });
}

const Map<String, _FoodInfoMeta> _foodInfoMetaByTag = {
  'vegetarisch': _FoodInfoMeta('Vegetarisch', Color(0xFFDCFCE7)),
  'vegan': _FoodInfoMeta('Vegan', Color(0xFFD1FAE5)),
  'glutenfrei': _FoodInfoMeta('Glutenfrei', Color(0xFFDBEAFE)),
  'nussfrei': _FoodInfoMeta('Nussfrei', Color(0xFFE0E7FF)),
  'enthaelt_nuesse': _FoodInfoMeta('Enthält Nüsse', Color(0xFFFEE2E2)),
  'laktosefrei': _FoodInfoMeta('Laktosefrei', Color(0xFFE0F2FE)),
  'enthaelt_milch': _FoodInfoMeta('Enthält Milch', Color(0xFFFFEDD5)),
  'enthaelt_ei': _FoodInfoMeta('Enthält Ei', Color(0xFFFEF3C7)),
  'babyfreundlich': _FoodInfoMeta('Babyfreundlich', Color(0xFFFCE7F3)),
  'kinderfreundlich': _FoodInfoMeta('Kinderfreundlich', Color(0xFFEDE9FE)),
  'nicht_scharf': _FoodInfoMeta('Nicht scharf', Color(0xFFF3F4F6)),
  'scharf': _FoodInfoMeta('Scharf', Color(0xFFFECACA)),
};

const List<_NearbyFilterPreset> _nearbyFilterPresets = [
  _NearbyFilterPreset(
    id: 'baby_mild',
    label: 'Baby + mild',
    tags: ['babyfreundlich', 'nicht_scharf'],
  ),
  _NearbyFilterPreset(
    id: 'glutenfrei_mild',
    label: 'Glutenfrei + mild',
    tags: ['glutenfrei', 'nicht_scharf'],
  ),
  _NearbyFilterPreset(
    id: 'veggie_kids',
    label: 'Veggie für Kinder',
    tags: ['vegetarisch', 'kinderfreundlich'],
  ),
  _NearbyFilterPreset(
    id: 'nussfrei',
    label: 'Nussfrei',
    tags: ['nussfrei'],
  ),
];

Color _trustColorForLevel(String level) {
  switch (level) {
    case 'trusted':
      return const Color(0xFF0F766E);
    case 'active':
      return const Color(0xFF1D4ED8);
    default:
      return const Color(0xFF6B7280);
  }
}

List<String> _visibleFoodInfoTags(List<String> tags) {
  return tags.where(_foodInfoMetaByTag.containsKey).toList();
}

String? _familyFitSummaryForTags(List<String> tags) {
  final tagSet = tags.toSet();
  final parts = <String>[];

  if (tagSet.contains('babyfreundlich')) {
    parts.add('Gut für Babys');
  } else if (tagSet.contains('kinderfreundlich')) {
    parts.add('Gut für Kinder');
  }

  if (tagSet.contains('glutenfrei')) {
    parts.add('glutenfrei');
  } else if (tagSet.contains('nussfrei')) {
    parts.add('nussfrei');
  }

  if (tagSet.contains('nicht_scharf')) {
    parts.add('mild');
  } else if (tagSet.contains('scharf')) {
    parts.add('eher scharf');
  }

  if (tagSet.contains('vegan')) {
    parts.add('vegan');
  } else if (tagSet.contains('vegetarisch')) {
    parts.add('vegetarisch');
  }

  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

Widget _buildFoodInfoChip(String tag) {
  final meta = _foodInfoMetaByTag[tag];
  if (meta == null) {
    return const SizedBox.shrink();
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: meta.tint,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      meta.label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF334155),
      ),
    ),
  );
}

String _lastSharedLabelFor(DateTime? value) {
  if (value == null) return 'Noch keine geteilte Historie';
  final diff = DateTime.now().difference(value);
  if (diff.inHours < 24) {
    return 'Zuletzt geteilt: heute';
  }
  if (diff.inDays == 1) {
    return 'Zuletzt geteilt: gestern';
  }
  return 'Zuletzt geteilt: vor ${diff.inDays} Tagen';
}

class GemeinsamSattScreen extends StatefulWidget {
  const GemeinsamSattScreen({super.key});

  @override
  State<GemeinsamSattScreen> createState() => _GemeinsamSattScreenState();
}

enum _RecipeFeedMode { forYou, newest, bestRated, quickMeals }

class _GemeinsamSattScreenState extends State<GemeinsamSattScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _commentController = TextEditingController();
  final backend_service.GemeinsamSattBackendService _service =
      backend_service.GemeinsamSattBackendService();

  late List<FoodSharePost> _posts;
  late List<SharedRecipe> _recipes;
  late WeekPlan _weekPlan;
  bool _isLoadingNearby = false;
  bool _isLoadingRecipes = false;
  String? _nearbyLoadError;
  String _nearbyDiscoveryScope = '10km';
  bool _nearbyGlobalDigitalMode = false;
  bool _showNearbyInviteBanner = false;
  String? _recipeLoadError;
  String? _mealPlanLoadError;
  _RecipeFeedMode _recipeFeedMode = _RecipeFeedMode.forYou;
  Set<String> _savedRecipeIds = <String>{};
  Set<String> _hiddenOfferIds = <String>{};
  Set<String> _reportedOfferIds = <String>{};
  final Set<String> _activeNearbyFilters = {'kinderfreundlich', 'nicht_scharf'};
  String? _selectedNearbyPresetId;

  static const String _savedRecipeStoragePrefix =
      'gemeinsam_satt.saved_recipes.v1';
  static const String _hiddenOfferStoragePrefix =
      'gemeinsam_satt.hidden_offers.v1';
  static const String _reportedOfferStoragePrefix =
      'gemeinsam_satt.reported_offers.v1';

  String get _myUserId =>
      AuthService.instance.currentUser?.uid.trim().isNotEmpty == true
          ? AuthService.instance.currentUser!.uid.trim()
          : 'guest_parent';

  String get _myDisplayName {
    final raw = AuthService.instance.currentUser?.displayName.trim();
    if (raw == null || raw.isEmpty) {
      return 'Ein Elternteil';
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _posts = [];
    _recipes = [];
    _weekPlan = _buildEmptyWeekPlan();
    _loadSavedRecipes();
    _loadOfferSafetyState();

    _loadNearbyFeed();
    // Load recipes from backend
    _loadRecipes();
    // Load meal plan from API
    _loadWeekMealPlan();
  }

  Future<void> _loadNearbyFeed() async {
    setState(() => _isLoadingNearby = true);
    try {
      final result = await _service.fetchRecipes(
        skip: 0,
        take: 40,
        sortBy: 'createdAt',
      );

      final backendRecipes = (result['recipes'] as List?)
              ?.whereType<backend_service.SharedRecipe>()
              .toList() ??
          const <backend_service.SharedRecipe>[];

      final mappedOffers = backendRecipes
          .where((item) {
            final lowerTags = item.tags.map((e) => e.toLowerCase()).toList();
            return item.category.toLowerCase() == 'snack' ||
                lowerTags.contains('angebot') ||
                lowerTags.contains('teilen');
          })
          .map(_mapBackendRecipeToOfferPost)
          .where((post) => post.title.trim().isNotEmpty)
          .toList();

      for (final post in mappedOffers) {
        final summary = await _service.fetchOfferReservationSummary(
          recipeId: post.id,
          userId: _myUserId,
        );

        if (summary == null) continue;
        final reservedPortions =
            (summary['reservedPortions'] as num?)?.toInt() ?? 0;
        final myPortions =
            ((summary['myReservation'] as Map?)?['portions'] as num?)
                    ?.toInt() ??
                0;

        final idx = mappedOffers.indexWhere((item) => item.id == post.id);
        if (idx == -1) continue;

        final remaining = (mappedOffers[idx].totalPortions - reservedPortions)
            .clamp(0, mappedOffers[idx].totalPortions);
        mappedOffers[idx] = mappedOffers[idx].copyWith(
          remainingPortions: remaining,
          isReservedByMe: myPortions > 0,
        );
      }

      if (!mounted) return;
      final syncError = _service.lastSyncError;
      final scoped = _resolveNearbyScope(
        mappedOffers
            .where((post) => !_hiddenOfferIds.contains(post.id))
            .toList(),
      );
      setState(() {
        _nearbyLoadError = syncError;
        _posts = scoped.posts;
        _nearbyDiscoveryScope = scoped.scope;
        _nearbyGlobalDigitalMode = scoped.globalDigitalMode;
        _showNearbyInviteBanner = scoped.showInviteBanner;
        _isLoadingNearby = false;
      });
    } catch (e) {
      debugPrint('GemeinsamSattScreen._loadNearbyFeed(): failed: $e');
      if (!mounted) return;
      setState(() {
        _nearbyLoadError =
            _service.lastSyncError ?? 'Angebote konnten nicht geladen werden.';
        _posts = [];
        _nearbyDiscoveryScope = 'global';
        _nearbyGlobalDigitalMode = true;
        _showNearbyInviteBanner = true;
        _isLoadingNearby = false;
      });
    }
  }

  ({
    List<FoodSharePost> posts,
    String scope,
    bool globalDigitalMode,
    bool showInviteBanner
  }) _resolveNearbyScope(List<FoodSharePost> source) {
    final within10 = source.where((p) => p.distanceKm <= 10).toList();
    if (within10.isNotEmpty) {
      return (
        posts: within10,
        scope: '10km',
        globalDigitalMode: false,
        showInviteBanner: false,
      );
    }

    final within50 = source.where((p) => p.distanceKm <= 50).toList();
    if (within50.isNotEmpty) {
      return (
        posts: within50,
        scope: '50km',
        globalDigitalMode: false,
        showInviteBanner: true,
      );
    }

    final within100 = source.where((p) => p.distanceKm <= 100).toList();
    if (within100.isNotEmpty) {
      return (
        posts: within100,
        scope: '100km',
        globalDigitalMode: false,
        showInviteBanner: true,
      );
    }

    if (source.isNotEmpty) {
      return (
        posts: source,
        scope: 'country',
        globalDigitalMode: false,
        showInviteBanner: true,
      );
    }

    return (
      posts: _buildGlobalDigitalNearbyFallback(),
      scope: 'global',
      globalDigitalMode: true,
      showInviteBanner: true,
    );
  }

  List<FoodSharePost> _buildGlobalDigitalNearbyFallback() {
    final now = DateTime.now();
    return [
      FoodSharePost(
        id: 'global-food-room-family-snacks',
        authorId: 'global-community',
        authorName: 'Global Community',
        authorInitials: 'GC',
        authorColor: const Color(0xFF1E5CD7),
        title: 'Globaler Food-Raum: Familienfreundliche Snacks',
        description:
            'Digitale Vorschlaege und Austausch für schnelle kindgerechte Snacks.',
        totalPortions: 1,
        remainingPortions: 1,
        pickupWindow: 'Online jetzt',
        distanceKm: 0,
        createdAt: now,
        likedByUserIds: const [],
        tags: const ['global', 'digital', 'snack'],
        comments: const [],
        imageEmoji: '🌍',
      ),
      FoodSharePost(
        id: 'global-food-room-meal-prep',
        authorId: 'global-community',
        authorName: 'Global Community',
        authorInitials: 'GC',
        authorColor: const Color(0xFF1E5CD7),
        title: 'Globaler Food-Raum: Meal Prep für Familien',
        description:
            'Rezepte, Portionsideen und Austausch für stressfreie Wochenplanung.',
        totalPortions: 1,
        remainingPortions: 1,
        pickupWindow: 'Online jetzt',
        distanceKm: 0,
        createdAt: now,
        likedByUserIds: const [],
        tags: const ['global', 'digital', 'mealprep'],
        comments: const [],
        imageEmoji: '🥗',
      ),
    ];
  }

  FoodSharePost _mapBackendRecipeToOfferPost(
      backend_service.SharedRecipe item) {
    final authorId = (item.creatorUserId ?? '').trim();
    final createdAt = item.createdAt;
    final portions = item.servings <= 0 ? 1 : item.servings;
    final minutesAgo = DateTime.now().difference(createdAt).inMinutes;
    final pickupLabel = minutesAgo <= 120
        ? 'Abholung heute möglich'
        : 'Abholung nach Absprache';

    return FoodSharePost(
      id: item.id,
      authorId: authorId.isEmpty ? 'community_parent' : authorId,
      authorName: _getUserDisplayName(authorId),
      authorInitials:
          _getInitials(authorId.isEmpty ? 'community_parent' : authorId),
      authorColor: _getColorForAuthor(authorId.isEmpty ? item.id : authorId),
      title: item.title,
      description: (item.description ?? '').trim().isEmpty
          ? 'Frisch gekocht und zum Teilen bereit.'
          : (item.description ?? '').trim(),
      totalPortions: portions,
      remainingPortions: portions,
      pickupWindow: pickupLabel,
      distanceKm: ((item.id.hashCode.abs() % 25) + 1) / 10,
      createdAt: createdAt,
      likedByUserIds: const [],
      tags: item.tags,
      comments: const [],
      imageEmoji: _getEmojiForCategory(item.category),
      authorTrustLabel: item.authorTrust?.label ?? 'Neu im Teilen',
      authorTrustLevel: item.authorTrust?.level ?? 'new',
      authorCompletedShares: item.authorTrust?.completedShares ?? 0,
      authorCompletionRate: item.authorTrust?.completionRate ?? 0,
      authorReliabilityLevel: item.authorTrust?.reliabilityLevel ?? 'new',
      authorReliabilityLabel:
          item.authorTrust?.reliabilityLabel ?? 'Noch wenig Nachweise',
      authorLastSharedAt: item.authorTrust?.lastSharedAt,
    );
  }

  Future<void> _loadWeekMealPlan() async {
    try {
      final familyId = APIConfig.getBackendFamilyId();
      final weekPlan = await MealPlannerService.getWeekMealPlan(
        familyId,
        DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        if (weekPlan != null && weekPlan.days.isNotEmpty) {
          _weekPlan = weekPlan;
          _mealPlanLoadError = null;
        } else {
          _weekPlan = _buildEmptyWeekPlan();
          _mealPlanLoadError =
              'Wochenplan konnte nicht vom Backend geladen werden.';
        }
      });
    } catch (e) {
      debugPrint('GemeinsamSattScreen._loadWeekMealPlan(): failed: $e');
      if (!mounted) return;
      setState(() {
        _weekPlan = _buildEmptyWeekPlan();
        _mealPlanLoadError = 'Wochenplan konnte nicht geladen werden.';
      });
    }
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoadingRecipes = true);
    try {
      final result = await _service.fetchRecipes(
        skip: 0,
        take: 40,
        sortBy: _recipeFeedMode == _RecipeFeedMode.bestRated
            ? 'rating'
            : 'createdAt',
      );

      final backendRecipes = (result['recipes'] as List?)
              ?.whereType<backend_service.SharedRecipe>()
              .toList() ??
          const <backend_service.SharedRecipe>[];

      final recipes = backendRecipes
          .map(_convertBackendRecipeToUI)
          .map((recipe) =>
              recipe.copyWith(isSavedByMe: _savedRecipeIds.contains(recipe.id)))
          .map((recipe) =>
              recipe.copyWith(relevanceScore: _scoreForCurrentParent(recipe)))
          .toList();

      if (!mounted) return;
      final syncError = _service.lastSyncError;
      setState(() {
        _recipeLoadError = syncError;
        _recipes = recipes;
        _isLoadingRecipes = false;
      });
    } catch (e) {
      debugPrint('GemeinsamSattScreen._loadRecipes(): failed: $e');
      if (!mounted) return;
      setState(() {
        _recipeLoadError =
            _service.lastSyncError ?? 'Rezepte konnten nicht geladen werden.';
        _recipes = [];
        _isLoadingRecipes = false;
      });
    }
  }

  // Convert backend recipe format to UI model
  SharedRecipe _convertBackendRecipeToUI(backend_service.SharedRecipe data) {
    final title = data.title;
    final category = data.category;
    final ingredients = data.ingredients
        .map((e) =>
            '${e['quantity'] ?? ''} ${e['unit'] ?? ''} ${e['name'] ?? ''}'
                .trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return SharedRecipe(
      id: data.id,
      authorId: (data.creatorUserId ?? '').toString(),
      authorName: _getUserDisplayName(data.creatorUserId),
      authorInitials: _getInitials((data.creatorUserId ?? '').toString()),
      authorColor: _getColorForAuthor((data.creatorUserId ?? '').toString()),
      title: title,
      description: (data.description ?? '').toString(),
      imageEmoji: _getEmojiForCategory(category),
      durationMinutes: data.prepTimeMinutes ?? 30,
      difficulty: _parseDifficulty(data.difficulty),
      tags: data.tags,
      likedByUserIds: data.rating > 0 ? ['seed_like'] : const [],
      ingredients: ingredients,
      steps: data.instructions,
      authorTrustLabel: data.authorTrust?.label ?? 'Neu im Teilen',
      authorTrustLevel: data.authorTrust?.level ?? 'new',
      authorPublishedRecipesCount: data.authorTrust?.publishedRecipesCount ?? 0,
      authorActiveOffersCount: data.authorTrust?.activeOffersCount ?? 0,
      authorCompletedShares: data.authorTrust?.completedShares ?? 0,
      authorCompletionRate: data.authorTrust?.completionRate ?? 0,
      authorReliabilityLevel: data.authorTrust?.reliabilityLevel ?? 'new',
      authorReliabilityLabel:
          data.authorTrust?.reliabilityLabel ?? 'Noch wenig Nachweise',
      authorLastSharedAt: data.authorTrust?.lastSharedAt,
      averageRating: data.rating,
      ratingCount: data.ratingCount,
      viewCount: data.viewCount,
      createdAt: data.createdAt,
    );
  }

  List<SharedRecipe> get _sortedRecipes {
    final list = List<SharedRecipe>.from(_recipes);
    switch (_recipeFeedMode) {
      case _RecipeFeedMode.forYou:
        list.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
        break;
      case _RecipeFeedMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _RecipeFeedMode.bestRated:
        list.sort((a, b) {
          final ratingComp = b.averageRating.compareTo(a.averageRating);
          if (ratingComp != 0) return ratingComp;
          return b.ratingCount.compareTo(a.ratingCount);
        });
        break;
      case _RecipeFeedMode.quickMeals:
        list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
        break;
    }
    return list;
  }

  double _scoreForCurrentParent(SharedRecipe recipe) {
    final lowerTags = recipe.tags.map((e) => e.toLowerCase()).toList();
    final timeFit = recipe.durationMinutes <= 25
        ? 1.0
        : recipe.durationMinutes <= 40
            ? 0.7
            : 0.4;
    final childFit = lowerTags.any((tag) =>
            tag.contains('kinder') ||
            tag.contains('baby') ||
            tag.contains('familie'))
        ? 1.0
        : 0.55;
    final trust = recipe.ratingCount > 0
        ? (recipe.averageRating / 5).clamp(0.0, 1.0)
        : 0.45;
    final freshnessDays = DateTime.now().difference(recipe.createdAt).inDays;
    final freshness = freshnessDays <= 2
        ? 1.0
        : freshnessDays <= 7
            ? 0.75
            : 0.45;
    final interest =
        recipe.viewCount > 0 ? (recipe.viewCount / 100).clamp(0.0, 1.0) : 0.35;

    return (0.30 * timeFit) +
        (0.25 * childFit) +
        (0.20 * trust) +
        (0.15 * freshness) +
        (0.10 * interest);
  }

  Future<void> _loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getStringList(_savedRecipeStorageKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _savedRecipeIds = saved.toSet();
      _recipes = _recipes
          .map((recipe) =>
              recipe.copyWith(isSavedByMe: saved.contains(recipe.id)))
          .toList();
    });
  }

  Future<void> _persistSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedRecipeStorageKey, _savedRecipeIds.toList());
  }

  Future<void> _loadOfferSafetyState() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden =
        prefs.getStringList(_hiddenOfferStorageKey) ?? const <String>[];
    final reported =
        prefs.getStringList(_reportedOfferStorageKey) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _hiddenOfferIds = hidden.toSet();
      _reportedOfferIds = reported.toSet();
      _posts =
          _posts.where((post) => !_hiddenOfferIds.contains(post.id)).toList();
    });
  }

  Future<void> _persistOfferSafetyState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenOfferStorageKey, _hiddenOfferIds.toList());
    await prefs.setStringList(
        _reportedOfferStorageKey, _reportedOfferIds.toList());
  }

  String get _savedRecipeStorageKey => '$_savedRecipeStoragePrefix.$_myUserId';

  String get _hiddenOfferStorageKey => '$_hiddenOfferStoragePrefix.$_myUserId';

  String get _reportedOfferStorageKey =>
      '$_reportedOfferStoragePrefix.$_myUserId';

  RecipeDifficulty _parseDifficulty(dynamic value) {
    final val = value?.toString().toLowerCase() ?? '';
    switch (val) {
      case 'einfach':
      case 'easy':
        return RecipeDifficulty.einfach;
      case 'mittel':
      case 'medium':
        return RecipeDifficulty.mittel;
      case 'leicht':
        return RecipeDifficulty.einfach;
      case 'schwer':
        return RecipeDifficulty.fortgeschritten;
      case 'fortgeschritten':
      case 'schwierig':
      case 'hard':
      case 'advanced':
        return RecipeDifficulty.fortgeschritten;
      default:
        return RecipeDifficulty.einfach;
    }
  }

  String _getUserDisplayName(String? userId) {
    if (userId == _myUserId) {
      return _myDisplayName;
    }
    final names = {
      'mueller': 'Familie Müller',
      'kaya': 'Familie Kaya',
      'nguyen': 'Familie Nguyen',
    };
    return names[userId] ?? 'Familie aus der Community';
  }

  String _getInitials(String userId) {
    final firstName = userId.split('_').first;
    return firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
  }

  Color _getColorForAuthor(String userId) {
    const colors = [
      Color(0xFF2563EB), // blue
      Color(0xFF16A34A), // green
      Color(0xFF8B5CF6), // purple
      Color(0xFFDC2626), // red
    ];
    return colors[userId.hashCode % colors.length];
  }

  String _getEmojiForCategory(String category) {
    final emojis = {
      'Suppe': '🍲',
      'Pasta': '🍝',
      'Salat': '🥗',
      'Fleisch': '🍖',
      'Fisch': '🐟',
      'Dessert': '🍰',
      'Frühstück': '🍳',
      'breakfast': '🍳',
      'lunch': '🍲',
      'dinner': '🍝',
      'snack': '🥙',
    };
    return emojis[category] ?? '🍽️';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        foregroundColor: const Color(0xFF1A2A3A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _brandLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🤝', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GemeinsamSatt',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
                Text(
                  'Essen teilen · Zusammen satt werden',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A9AB0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _brand,
          labelColor: _brand,
          unselectedLabelColor: const Color(0xFF8A9AB0),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          indicatorSize: TabBarIndicatorSize.tab,
          isScrollable: false,
          tabs: const [
            Tab(
              icon: Icon(Icons.location_on_rounded, size: 20),
              text: 'Nähe',
            ),
            Tab(
              icon: Icon(Icons.menu_book_rounded, size: 20),
              text: 'Rezepte',
            ),
            Tab(
              icon: Icon(Icons.calendar_month_rounded, size: 20),
              text: 'Planer',
            ),
            Tab(
              icon: Icon(Icons.favorite_rounded, size: 20),
              text: 'Angebote',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNearbyFeed(),
          _buildRecipesFeed(),
          _buildMealPlanTab(),
          _buildMyOffers(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final tabIndex = _tabController.index;
          final isRecipeTab = tabIndex == 1;
          final isMealTab = tabIndex == 2;
          return FloatingActionButton.extended(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            icon: Icon(isRecipeTab
                ? Icons.menu_book_rounded
                : isMealTab
                    ? Icons.add_rounded
                    : Icons.add_circle_outline_rounded),
            label: Text(
              isRecipeTab
                  ? 'Rezept teilen'
                  : isMealTab
                      ? 'Mahlzeit hinzufügen'
                      : 'Ich habe extra gekocht!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              if (isRecipeTab) {
                _openCreateRecipe(context);
              } else if (isMealTab) {
                _openAddMeal(context);
              } else {
                _openCreatePost(context);
              }
            },
          );
        },
      ),
    );
  }

  // -------------------------------------------------------
  // NEARBY FEED
  // -------------------------------------------------------

  Widget _buildNearbyFeed() {
    if (_isLoadingNearby) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nearbyLoadError != null && _posts.isEmpty) {
      return _buildBackendErrorState(
        title: 'Angebote konnten nicht geladen werden',
        subtitle: _nearbyLoadError!,
        onRetry: _loadNearbyFeed,
      );
    }

    final available = _filteredNearbyPosts;
    if (available.isEmpty) {
      return _buildEmptyState(
        emoji: '🍲',
        title: 'Noch keine Angebote in deiner Nähe',
        subtitle: 'Sei der Erste! Drücke unten auf „Ich habe extra gekocht!"',
      );
    }
    return Column(
      children: [
        if (_showNearbyInviteBanner)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF7D8A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.campaign_outlined,
                    color: Color(0xFF9A5A11), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nearbyGlobalDigitalMode
                        ? '🍲 Noch keine lokalen Angebote. Stöber global & teile ab sofort selbst — kostenlos!'
                        : '🔄 Suche in $_nearbyDiscoveryScope erweitert | Mehr Teller? Lade Eltern in deine Nähe ein.',
                    style: const TextStyle(
                      color: Color(0xFF74420D),
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF2D7D1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${available.length} passende Angebote',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2A3A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sortiert nach Nähe, Frische, Vertrauen und deinen aktiven Hinweisen.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B778C),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._nearbyFilterPresets.map((preset) {
                      final selected = _selectedNearbyPresetId == preset.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset.label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              if (selected) {
                                _selectedNearbyPresetId = null;
                                _activeNearbyFilters.clear();
                              } else {
                                _selectedNearbyPresetId = preset.id;
                                _activeNearbyFilters
                                  ..clear()
                                  ..addAll(preset.tags);
                              }
                            });
                          },
                          selectedColor: const Color(0xFFFED7CC),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? _brand : const Color(0xFF516072),
                          ),
                        ),
                      );
                    }),
                    if (_activeNearbyFilters.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedNearbyPresetId = null;
                            _activeNearbyFilters.clear();
                          });
                        },
                        child: const Text('Reset'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _foodInfoMetaByTag.entries.map((entry) {
                    final selected = _activeNearbyFilters.contains(entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.value.label),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              _activeNearbyFilters.remove(entry.key);
                            } else {
                              _activeNearbyFilters.add(entry.key);
                            }
                            _selectedNearbyPresetId = null;
                          });
                        },
                        selectedColor: entry.value.tint,
                        side: BorderSide(
                          color: selected ? _brand : const Color(0xFFE5E7EB),
                        ),
                        labelStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadNearbyFeed,
            color: _brand,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
              itemCount: available.length,
              itemBuilder: (context, i) {
                // Animate only first 8 items on initial load
                final shouldAnimate = i < 8;
                final delay = shouldAnimate ? i * 50 : 0;

                final card = _PostCard(
                  post: available[i],
                  myUserId: _myUserId,
                  onLike: () => _toggleLike(available[i].id),
                  onAbholen: () => _reservePost(available[i].id),
                  onComment: () => _showComments(available[i]),
                  onReport: () => _reportPost(available[i]),
                  onHide: () => _hidePost(available[i]),
                );

                return shouldAnimate
                    ? EntranceAnimation(
                        delayMs: delay,
                        duration: const Duration(milliseconds: 350),
                        child: card,
                      )
                    : card;
              },
            ),
          ),
        ),
      ],
    );
  }

  List<FoodSharePost> get _filteredNearbyPosts {
    final visible = _posts
        .where((p) => !_hiddenOfferIds.contains(p.id))
        .where((p) => p.isAvailable)
        .toList();

    final filtered = _activeNearbyFilters.isEmpty
        ? visible
        : visible.where((post) {
            final tags = post.tags.toSet();
            return _activeNearbyFilters.every(tags.contains);
          }).toList();

    filtered
        .sort((a, b) => _nearbyOfferScore(b).compareTo(_nearbyOfferScore(a)));
    return filtered;
  }

  double _nearbyOfferScore(FoodSharePost post) {
    final distanceScore = (1 - (post.distanceKm / 5)).clamp(0.0, 1.0);
    final freshnessHours = DateTime.now().difference(post.createdAt).inHours;
    final freshnessScore = freshnessHours <= 6
        ? 1.0
        : freshnessHours <= 24
            ? 0.75
            : freshnessHours <= 72
                ? 0.45
                : 0.2;
    final trustScore = post.authorTrustLevel == 'trusted'
        ? 1.0
        : post.authorTrustLevel == 'active'
            ? 0.7
            : 0.4;
    final hintScore = _activeNearbyFilters.isEmpty
        ? 0.5
        : _activeNearbyFilters.where(post.tags.contains).length /
            _activeNearbyFilters.length;

    return (0.35 * distanceScore) +
        (0.25 * freshnessScore) +
        (0.25 * trustScore) +
        (0.15 * hintScore);
  }

  // -------------------------------------------------------
  // MEAL PLANNER TAB
  // -------------------------------------------------------

  Widget _buildMealPlanTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: _cardBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Diese Woche',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF516072),
                ),
              ),
              Text(
                '${_weekPlan.weekStart.day}. - ${_weekPlan.weekStart.add(const Duration(days: 6)).day}. ${_monthName(_weekPlan.weekStart.month)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _brand,
                ),
              ),
            ],
          ),
        ),
        if (_mealPlanLoadError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _mealPlanLoadError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadWeekMealPlan,
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'reload')),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: 7,
            itemBuilder: (context, i) {
              final dayPlan = _weekPlan.getDay(i) ??
                  DayPlan(date: _weekPlan.weekStart.add(Duration(days: i)));
              final card = _DayPlanCard(
                dayPlan: dayPlan,
                onAddMeal: () => _openAddMealForDay(context, dayPlan.date),
                onRemoveMeal: (type) {
                  setState(() {
                    _weekPlan = _weekPlan.updateDay(dayPlan.removeMeal(type));
                  });
                  _showSnack('Mahlzeit entfernt');
                },
                onTapMeal: (meal) => _showMealDetail(meal),
              );

              return EntranceAnimation(
                delayMs: i * 60,
                duration: const Duration(milliseconds: 400),
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAddMeal(BuildContext context) {
    _openAddMealForDay(context, DateTime.now());
  }

  void _openAddMealForDay(BuildContext context, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMealSheet(
        date: date,
        onSubmit: (meal) {
          final dayPlan = _weekPlan.getDay(
                date.difference(_weekPlan.weekStart.toDateOnly).inDays,
              ) ??
              DayPlan(date: date);
          setState(() {
            _weekPlan = _weekPlan.updateDay(dayPlan.addMeal(meal));
          });
          _showSnack('Mahlzeit hinzugefügt ✅');
        },
      ),
    );
  }

  void _showMealDetail(Meal meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealDetailSheet(meal: meal),
    );
  }

  String _monthName(int month) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember'
    ];
    return months[month - 1];
  }

  // -------------------------------------------------------
  // RECIPES FEED
  // -------------------------------------------------------

  Widget _buildRecipesFeed() {
    if (_isLoadingRecipes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recipeLoadError != null && _recipes.isEmpty) {
      return _buildBackendErrorState(
        title: 'Rezepte konnten nicht geladen werden',
        subtitle: _recipeLoadError!,
        onRetry: _loadRecipes,
      );
    }

    if (_recipes.isEmpty) {
      return _buildEmptyState(
        emoji: '📖',
        title: 'Noch keine Rezepte geteilt',
        subtitle: 'Teile dein Lieblingsrezept mit anderen Eltern!',
      );
    }

    final recipes = _sortedRecipes;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF2D7D1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'So werden Rezepte gezeigt',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2A3A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Standard ist Für dich: kinderfreundlich, schnell, gut bewertet und aktuell.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B778C),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRecipeModeChip(
                      label: 'Für dich',
                      mode: _RecipeFeedMode.forYou,
                    ),
                    const SizedBox(width: 8),
                    _buildRecipeModeChip(
                      label: 'Neueste',
                      mode: _RecipeFeedMode.newest,
                    ),
                    const SizedBox(width: 8),
                    _buildRecipeModeChip(
                      label: 'Top bewertet',
                      mode: _RecipeFeedMode.bestRated,
                    ),
                    const SizedBox(width: 8),
                    _buildRecipeModeChip(
                      label: 'Schnell unter 30 min',
                      mode: _RecipeFeedMode.quickMeals,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRecipes,
            color: _brand,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
              itemCount: recipes.length,
              itemBuilder: (context, i) => _RecipeCard(
                recipe: recipes[i],
                myUserId: _myUserId,
                onLike: () => _toggleRecipeLike(recipes[i]),
                onSave: () => _toggleSave(recipes[i].id),
                onTap: () => _showRecipeDetail(recipes[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeModeChip({
    required String label,
    required _RecipeFeedMode mode,
  }) {
    final selected = _recipeFeedMode == mode;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _recipeFeedMode = mode);
        _loadRecipes();
      },
      selectedColor: _brandLight,
      checkmarkColor: _brand,
      side: BorderSide(
        color: selected ? _brand : const Color(0xFFE9EEF5),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? _brand : const Color(0xFF516072),
      ),
    );
  }

  Future<void> _toggleRecipeLike(SharedRecipe recipe) async {
    final alreadyLiked = recipe.likedByUserIds.contains(_myUserId);
    if (alreadyLiked) {
      _showSnack('Du hast dieses Rezept bereits empfohlen.');
      return;
    }

    final result = await _service.rateRecipe(
      recipeId: recipe.id,
      userId: _myUserId,
      rating: 5,
      comment: 'Sehr hilfreich für Familienalltag',
    );

    if (result == null) {
      _showSnack(_service.lastSyncError ??
          'Empfehlung konnte nicht gespeichert werden.');
      return;
    }

    setState(() {
      final idx = _recipes.indexWhere((r) => r.id == recipe.id);
      if (idx == -1) return;
      final updated = List<String>.from(_recipes[idx].likedByUserIds)
        ..add(_myUserId);
      _recipes[idx] = _recipes[idx].copyWith(
        likedByUserIds: updated,
        ratingCount: _recipes[idx].ratingCount + 1,
        averageRating: (_recipes[idx].averageRating + 5) / 2,
      );
    });
    HapticFeedback.lightImpact();
    _showSnack('Danke! Deine Empfehlung hilft anderen Eltern.');
  }

  Future<void> _toggleSave(String recipeId) async {
    setState(() {
      final idx = _recipes.indexWhere((r) => r.id == recipeId);
      if (idx == -1) return;
      if (_savedRecipeIds.contains(recipeId)) {
        _savedRecipeIds.remove(recipeId);
      } else {
        _savedRecipeIds.add(recipeId);
      }
      _recipes[idx] = _recipes[idx].copyWith(
        isSavedByMe: !_recipes[idx].isSavedByMe,
      );
    });
    await _persistSavedRecipes();
    final saved = _recipes.firstWhere((r) => r.id == recipeId).isSavedByMe;
    _showSnack(saved ? 'Rezept gespeichert ✅' : 'Rezept entfernt');
  }

  Future<void> _showRecipeDetail(SharedRecipe recipe) async {
    SharedRecipe detail = recipe;
    final backendDetail = await _service.getRecipe(recipe.id);
    if (backendDetail != null) {
      final mapped = _convertBackendRecipeToUI(backendDetail);
      detail = mapped.copyWith(
        isSavedByMe: _savedRecipeIds.contains(mapped.id),
        relevanceScore: _scoreForCurrentParent(mapped),
      );
      if (mounted) {
        setState(() {
          final idx = _recipes.indexWhere((r) => r.id == detail.id);
          if (idx != -1) {
            _recipes[idx] = detail;
          }
        });
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeDetailSheet(recipe: detail),
    );
  }

  void _openCreateRecipe(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateRecipeSheet(
        onSubmit: (draft) async {
          final created = await _service.createRecipe(
            userId: _myUserId,
            title: draft.title,
            description: draft.description,
            category: draft.category,
            difficulty: draft.difficulty,
            prepTimeMinutes: draft.durationMinutes,
            servings: draft.servings,
            ingredients: draft.ingredients,
            instructions: draft.steps,
            tags: draft.tags,
          );

          if (!mounted) return false;
          if (created == null) {
            _showSnack(_service.lastSyncError ??
                'Rezept konnte nicht geteilt werden.');
            return false;
          }

          final mappedRecipe = _convertBackendRecipeToUI(created);
          setState(() {
            _recipes.insert(
              0,
              mappedRecipe.copyWith(
                isSavedByMe: _savedRecipeIds.contains(mappedRecipe.id),
                relevanceScore: _scoreForCurrentParent(mappedRecipe),
              ),
            );
          });
          _showSnack('Dein Rezept ist jetzt für alle sichtbar!');
          return true;
        },
      ),
    );
  }

  Widget _buildMyOffers() {
    final mine = _posts
        .where((p) => !_hiddenOfferIds.contains(p.id))
        .where((p) => p.authorId == _myUserId)
        .toList();
    if (mine.isEmpty) {
      return _buildEmptyState(
        emoji: '👩‍🍳',
        title: 'Du hast noch nichts geteilt',
        subtitle: 'Hast du heute extra gekocht? Teile es mit anderen Eltern!',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: mine.length,
      itemBuilder: (context, i) => _PostCard(
        post: mine[i],
        myUserId: _myUserId,
        onLike: () => _toggleLike(mine[i].id),
        onAbholen: () => _reservePost(mine[i].id),
        onComment: () => _showComments(mine[i]),
        isOwner: true,
      ),
    );
  }

  Widget _buildEmptyState({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2A3A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8A9AB0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendErrorState({
    required String title,
    required String subtitle,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2A3A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'reload')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // ACTIONS
  // -------------------------------------------------------

  void _toggleLike(String postId) {
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx == -1) return;
      final post = _posts[idx];
      final liked = post.likedByUserIds.contains(_myUserId);
      final updated = liked
          ? (List<String>.from(post.likedByUserIds)..remove(_myUserId))
          : (List<String>.from(post.likedByUserIds)..add(_myUserId));
      _posts[idx] = post.copyWith(likedByUserIds: updated);
    });
    HapticFeedback.lightImpact();
  }

  void _reservePost(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = _posts[idx];

    if (post.isReservedByMe) {
      _showReservationActionSheet(post, idx);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickupBottomSheet(
        post: post,
        onConfirm: (message) {
          _confirmReservation(post, idx);
        },
      ),
    );
  }

  Future<void> _showReservationActionSheet(
      FoodSharePost post, int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Deine Reservierung',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2A3A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF516072),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('complete'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A)),
              child: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'confirm_pickup')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'cancel_reservation')),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('finance_close')),
            ),
          ],
        ),
      ),
    );

    if (action == 'complete') {
      await _completeReservation(post, index);
    } else if (action == 'cancel') {
      await _cancelReservation(post, index);
    }
  }

  Future<void> _confirmReservation(FoodSharePost post, int index) async {
    final result = await _service.reserveOffer(
      recipeId: post.id,
      userId: _myUserId,
      portions: 1,
    );

    if (result == null) {
      _showSnack(_service.lastSyncError ?? 'Reservierung fehlgeschlagen');
      return;
    }

    final reservedPortions = (result['reservedPortions'] as num?)?.toInt() ?? 0;
    final remaining =
        (post.totalPortions - reservedPortions).clamp(0, post.totalPortions);
    if (!mounted) return;
    setState(() {
      _posts[index] = post.copyWith(
        isReservedByMe: true,
        remainingPortions: remaining,
      );
    });
    _showSnack('${post.authorName} wurde benachrichtigt.');
  }

  Future<void> _cancelReservation(FoodSharePost post, int index) async {
    final ok = await _service.cancelOfferReservation(
      recipeId: post.id,
      userId: _myUserId,
    );

    if (!ok) {
      _showSnack(_service.lastSyncError ??
          'Reservierung konnte nicht aufgehoben werden');
      return;
    }

    final summary = await _service.fetchOfferReservationSummary(
      recipeId: post.id,
      userId: _myUserId,
    );
    final reservedPortions =
        (summary?['reservedPortions'] as num?)?.toInt() ?? 0;
    final remaining =
        (post.totalPortions - reservedPortions).clamp(0, post.totalPortions);
    if (!mounted) return;
    setState(() {
      _posts[index] = post.copyWith(
        isReservedByMe: false,
        remainingPortions: remaining,
      );
    });
    _showSnack('Reservierung aufgehoben');
  }

  Future<void> _completeReservation(FoodSharePost post, int index) async {
    final ok = await _service.completeOfferShare(
      recipeId: post.id,
      userId: _myUserId,
    );

    if (!ok) {
      _showSnack(
          _service.lastSyncError ?? 'Abholung konnte nicht bestaetigt werden');
      return;
    }

    setState(() {
      _hiddenOfferIds = {..._hiddenOfferIds, post.id};
      _posts = _posts.where((item) => item.id != post.id).toList();
    });
    await _persistOfferSafetyState();

    if (!mounted) return;
    _showSnack('Abholung bestätigt. Danke fürs Teilen!');
  }

  Future<void> _showComments(FoodSharePost post) async {
    final backendComments =
        await _service.fetchOfferComments(recipeId: post.id);
    final hydratedComments = backendComments.map((item) {
      final authorId = (item['userId'] ?? '').toString();
      return FoodShareComment(
        id: (item['id'] ?? '').toString(),
        authorId: authorId,
        authorName: _getUserDisplayName(authorId),
        authorInitials: _getInitials(authorId),
        authorColor: _getColorForAuthor(authorId),
        text: (item['text'] ?? '').toString(),
        createdAt: item['createdAt'] is String
            ? DateTime.tryParse(item['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
    }).toList();

    final mergedPost = post.copyWith(comments: hydratedComments);
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx != -1 && mounted) {
      setState(() {
        _posts[idx] = mergedPost;
      });
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: mergedPost,
        myUserId: _myUserId,
        onAddComment: (text) async {
          final created = await _service.createOfferComment(
            recipeId: post.id,
            userId: _myUserId,
            text: text,
          );

          if (created == null) {
            _showSnack(_service.lastSyncError ??
                'Kommentar konnte nicht gespeichert werden');
            return false;
          }

          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx == -1) return false;
          final authorId = (created['userId'] ?? _myUserId).toString();
          final newComment = FoodShareComment(
            id: (created['id'] ?? 'c-${DateTime.now().millisecondsSinceEpoch}')
                .toString(),
            authorId: authorId,
            authorName: _getUserDisplayName(authorId),
            authorInitials: _getInitials(authorId),
            authorColor: _getColorForAuthor(authorId),
            text: text,
            createdAt: created['createdAt'] is String
                ? DateTime.tryParse(created['createdAt'] as String) ??
                    DateTime.now()
                : DateTime.now(),
          );
          if (!mounted) return false;
          setState(() {
            _posts[idx] = _posts[idx].copyWith(
              comments: [..._posts[idx].comments, newComment],
            );
          });
          return true;
        },
      ),
    );
  }

  Future<void> _reportPost(FoodSharePost post) async {
    if (post.authorId == _myUserId) {
      _showSnack('Eigene Angebote kannst du nicht melden.');
      return;
    }

    String selectedReason = 'Spam oder Irrefuehrung';
    final noteController = TextEditingController();
    final reasons = <String>[
      'Spam oder Irrefuehrung',
      'Unpassender Inhalt',
      'Betrug oder Unsicherheit',
      'Andere Sorge',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(_t('satt_report_offer')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hilf uns, den Bereich sicher und hilfreich für Eltern zu halten.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: reasons
                        .map((reason) => DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value.isEmpty) return;
                      setDialogState(() => selectedReason = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Optional: kurze Notiz für die Moderation',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_t('satt_report')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      noteController.dispose();
      return;
    }

    final ok = await _service.reportOffer(
      recipeId: post.id,
      userId: _myUserId,
      reason: selectedReason,
      note: noteController.text.trim(),
    );
    noteController.dispose();

    if (ok) {
      setState(() {
        _reportedOfferIds = {..._reportedOfferIds, post.id};
        _hiddenOfferIds = {..._hiddenOfferIds, post.id};
        _posts = _posts.where((item) => item.id != post.id).toList();
      });
      await _persistOfferSafetyState();
    }

    if (!mounted) return;
    _showSnack(
      ok
          ? 'Danke, wir pruefen diese Meldung.'
          : (_service.lastSyncError ??
              'Meldung konnte nicht gespeichert werden.'),
    );
  }

  Future<void> _hidePost(FoodSharePost post) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('satt_hide_offer')),
        content: const Text(
          'Dieses Angebot wird nur für dich ausgeblendet und später nicht mehr im Feed angezeigt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t('satt_hide')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _hiddenOfferIds = {..._hiddenOfferIds, post.id};
      _posts = _posts.where((item) => item.id != post.id).toList();
    });
    await _persistOfferSafetyState();

    if (!mounted) return;
    _showSnack('Angebot wurde aus deinem Feed ausgeblendet.');
  }

  void _openCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        onSubmit: (title, description, portions, pickupWindow, infoTags) async {
          final created = await _service.createRecipe(
            userId: _myUserId,
            title: title,
            description: description,
            category: 'snack',
            difficulty: 'leicht',
            prepTimeMinutes: 20,
            servings: portions,
            ingredients: [
              {
                'name': 'Siehe Beschreibung',
                'quantity': '',
                'unit': '',
              }
            ],
            instructions: [
              'Kontakt aufnehmen und Abholzeit abstimmen: $pickupWindow',
            ],
            tags: ['angebot', 'gemeinsamsatt', 'teilen', ...infoTags],
          );

          if (!mounted) return false;
          if (created == null) {
            _showSnack(_service.lastSyncError ??
                'Angebot konnte nicht veröffentlicht werden.');
            return false;
          }

          final basePost = _mapBackendRecipeToOfferPost(created);
          final newPost = FoodSharePost(
            id: basePost.id,
            authorId: basePost.authorId,
            authorName: basePost.authorName,
            authorInitials: basePost.authorInitials,
            authorColor: basePost.authorColor,
            title: basePost.title,
            description: basePost.description,
            totalPortions: portions,
            remainingPortions: portions,
            pickupWindow: pickupWindow,
            distanceKm: 0.1,
            createdAt: basePost.createdAt,
            likedByUserIds: basePost.likedByUserIds,
            tags: basePost.tags,
            comments: basePost.comments,
            imageEmoji: basePost.imageEmoji,
          );

          setState(() {
            _posts.insert(0, newPost);
          });
          _showSnack('Dein Angebot ist jetzt für Eltern in der Nähe sichtbar!');
          _tabController.animateTo(0);
          return true;
        },
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  WeekPlan _buildEmptyWeekPlan() {
    final today = DateTime.now().toDateOnly;
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return WeekPlan(
      weekStart: weekStart,
      days: List.generate(
        7,
        (index) => DayPlan(date: weekStart.add(Duration(days: index))),
      ),
    );
  }
}

// ============================================================
// POST CARD
// ============================================================

class _PostCard extends StatefulWidget {
  final FoodSharePost post;
  final String myUserId;
  final VoidCallback onLike;
  final VoidCallback onAbholen;
  final VoidCallback onComment;
  final VoidCallback? onReport;
  final VoidCallback? onHide;
  final bool isOwner;

  const _PostCard({
    required this.post,
    required this.myUserId,
    required this.onLike,
    required this.onAbholen,
    required this.onComment,
    this.onReport,
    this.onHide,
    this.isOwner = false,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _likeController;
  late final Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScale = Tween<double>(begin: 1, end: 1.4).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _handleLike() {
    _likeController.forward().then((_) => _likeController.reverse());
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isLiked = post.likedByUserIds.contains(widget.myUserId);
    final likeCount = post.likedByUserIds.length;
    final visibleInfoTags = _visibleFoodInfoTags(post.tags);
    final familySummary = _familyFitSummaryForTags(post.tags);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FOOD IMAGE AREA
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [
                  post.authorColor.withValues(alpha: 0.15),
                  post.authorColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    post.imageEmoji ?? '🍽️',
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
                // Distance badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: post.authorColor),
                        const SizedBox(width: 3),
                        Text(
                          '${post.distanceKm.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: post.authorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Portions badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: post.isAvailable
                          ? const Color(0xFF16A34A).withValues(alpha: 0.9)
                          : Colors.grey.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      post.isAvailable
                          ? '${post.remainingPortions} Portion${post.remainingPortions != 1 ? 'en' : ''} frei'
                          : 'Ausgebucht',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CONTENT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: post.authorColor.withValues(alpha: 0.15),
                      child: Text(
                        post.authorInitials,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: post.authorColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2A3A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _trustColorForLevel(post.authorTrustLevel)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              post.authorTrustLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    _trustColorForLevel(post.authorTrustLevel),
                              ),
                            ),
                          ),
                          Text(
                            _timeAgo(post.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A9AB0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF516072),
                    height: 1.5,
                  ),
                ),

                if (familySummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    familySummary,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],

                if (visibleInfoTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: visibleInfoTags
                        .map((tag) => _buildFoodInfoChip(tag))
                        .toList(),
                  ),
                ],

                if (post.authorCompletedShares > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${post.authorCompletedShares} erfolgreiche Teilungen bisher',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (post.authorCompletionRate > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(post.authorCompletionRate * 100).round()}% Abschlussquote',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (post.authorReliabilityLevel != 'new') ...[
                    const SizedBox(height: 4),
                    Text(
                      post.authorReliabilityLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (post.authorLastSharedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _lastSharedLabelFor(post.authorLastSharedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 12),

                // Pickup time
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: Color(0xFFE07B39)),
                      const SizedBox(width: 6),
                      Text(
                        post.pickupWindow,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE07B39),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F4F8)),
                const SizedBox(height: 12),

                // ACTION ROW: Like, Comment, Abholen
                Row(
                  children: [
                    // LIKE
                    GestureDetector(
                      onTap: _handleLike,
                      child: ScaleTransition(
                        scale: _likeScale,
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isLiked ? _brand : const Color(0xFF8A9AB0),
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likeCount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    isLiked ? _brand : const Color(0xFF8A9AB0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // COMMENT
                    GestureDetector(
                      onTap: widget.onComment,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF8A9AB0),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.comments.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A9AB0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ABHOLEN BUTTON
                    if (!widget.isOwner)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: post.isReservedByMe
                                ? const Color(0xFFE8F5E9)
                                : post.isAvailable
                                    ? _brand
                                    : Colors.grey.shade300,
                            foregroundColor: post.isReservedByMe
                                ? const Color(0xFF16A34A)
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: post.isAvailable || post.isReservedByMe
                              ? widget.onAbholen
                              : null,
                          child: Text(
                            post.isReservedByMe
                                ? '✓ Reserviert'
                                : post.isAvailable
                                    ? 'Ich hole ab 🙌'
                                    : 'Ausgebucht',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                    if (widget.isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${post.totalPortions - post.remainingPortions}/${post.totalPortions} vergeben',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF516072),
                          ),
                        ),
                      ),
                    if (!widget.isOwner && widget.onReport != null)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'report') {
                            widget.onReport?.call();
                          } else if (value == 'hide') {
                            widget.onHide?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (widget.onHide != null)
                            PopupMenuItem<String>(
                              value: 'hide',
                              child: Text(_t('satt_hide_from_feed')),
                            ),
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Text(_t('satt_report_offer')),
                          ),
                        ],
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Color(0xFF8A9AB0),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} Tag(en)';
  }
}

// ============================================================
// PICKUP BOTTOM SHEET
// ============================================================

class _PickupBottomSheet extends StatelessWidget {
  final FoodSharePost post;
  final Function(String message) onConfirm;

  const _PickupBottomSheet({required this.post, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E3E8),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            post.imageEmoji ?? '🍽️',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2A3A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'von ${post.authorName}',
            style: const TextStyle(color: Color(0xFF8A9AB0)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _brandLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: _brand, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Abholzeit',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A9AB0),
                        ),
                      ),
                      Text(
                        post.pickupWindow,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF516072), size: 18),
                const SizedBox(width: 10),
                Text(
                  '${post.distanceKm.toStringAsFixed(1)} km entfernt',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF516072),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context);
                onConfirm('Ich komme!');
              },
              child: const Text(
                'Ich hole ab! 🙌',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: Color(0xFF8A9AB0)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMMENTS SHEET
// ============================================================

class _CommentsSheet extends StatefulWidget {
  final FoodSharePost post;
  final String myUserId;
  final Future<bool> Function(String text) onAddComment;

  const _CommentsSheet({
    required this.post,
    required this.myUserId,
    required this.onAddComment,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _ctrl = TextEditingController();
  late List<FoodShareComment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.post.comments);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final persisted = await widget.onAddComment(text);
    if (!persisted) return;
    final comment = FoodShareComment(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      authorId: widget.myUserId,
      authorName: 'Ich',
      authorInitials: 'ME',
      authorColor: _brand,
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _comments.add(comment);
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E3E8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kommentare · ${widget.post.title}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _comments.isEmpty
                ? const Center(
                    child: Text(
                      'Noch keine Kommentare.\nSei der Erste! 💬',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8A9AB0)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  c.authorColor.withValues(alpha: 0.15),
                              child: Text(
                                c.authorInitials,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: c.authorColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.authorName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A2A3A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.text,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF516072),
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
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Kommentar schreiben...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: _brand),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CREATE POST SHEET
// ============================================================

class _CreatePostSheet extends StatefulWidget {
  final Future<bool> Function(String title, String description, int portions,
      String pickupWindow, List<String> infoTags) onSubmit;

  const _CreatePostSheet({required this.onSubmit});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _portions = 2;
  String _pickupWindow = 'Heute 17:00 – 19:00 Uhr';
  final Set<String> _selectedInfoTags = {'kinderfreundlich', 'nicht_scharf'};

  final List<String> _presets = [
    'Heute 12:00 – 13:30 Uhr',
    'Heute 17:00 – 19:00 Uhr',
    'Heute 18:00 – 20:00 Uhr',
    'Morgen 12:00 – 13:00 Uhr',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E3E8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '🍲 Essen anbieten',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2A3A),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Was hast du heute zu viel gekocht?',
                style: TextStyle(color: Color(0xFF8A9AB0), fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            _label('Gericht'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: _inputDeco('z. B. Selbstgemachte Lasagne 🍝'),
            ),
            const SizedBox(height: 14),
            _label('Beschreibung'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: _inputDeco(
                  'Zutaten, besondere Hinweise (vegan, glutenfrei, scharf...)'),
            ),
            const SizedBox(height: 14),
            _label('Wie viele Portionen?'),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () {
                    if (_portions > 1) setState(() => _portions--);
                  },
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 12),
                Text(
                  '$_portions',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: _brand),
                  onPressed: () => setState(() => _portions++),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Hinweise für Eltern'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foodInfoMetaByTag.entries.map((entry) {
                final selected = _selectedInfoTags.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _selectedInfoTags.remove(entry.key);
                      } else {
                        _selectedInfoTags.add(entry.key);
                      }
                    });
                  },
                  selectedColor: entry.value.tint,
                  side: BorderSide(
                    color: selected ? _brand : const Color(0xFFE5E7EB),
                  ),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _label('Abholzeit'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final selected = _pickupWindow == p;
                return GestureDetector(
                  onTap: () => setState(() => _pickupWindow = p),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _brandLight : const Color(0xFFF0F4F8),
                      border: Border.all(
                        color: selected ? _brand : Colors.transparent,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? _brand : const Color(0xFF516072),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final title = _titleCtrl.text.trim();
                  final desc = _descCtrl.text.trim();
                  if (title.isEmpty) return;
                  final success = await widget.onSubmit(
                    title,
                    desc,
                    _portions,
                    _pickupWindow,
                    _selectedInfoTags.toList(),
                  );
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Jetzt teilen 🙌',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A2A3A),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0BBC8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
    );
  }
}

// ============================================================
// RECIPE CARD
// ============================================================

class _RecipeCard extends StatefulWidget {
  final SharedRecipe recipe;
  final String myUserId;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.myUserId,
    required this.onLike,
    required this.onSave,
    required this.onTap,
  });

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _likeCtrl;
  late final Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _likeScale = Tween<double>(begin: 1, end: 1.4)
        .animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final isLiked = recipe.likedByUserIds.contains(widget.myUserId);
    final visibleInfoTags = _visibleFoodInfoTags(recipe.tags);
    final familySummary = _familyFitSummaryForTags(recipe.tags);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE AREA
            Container(
              height: 130,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [
                    recipe.authorColor.withValues(alpha: 0.12),
                    recipe.authorColor.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(recipe.imageEmoji,
                        style: const TextStyle(fontSize: 60)),
                  ),
                  // Difficulty badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: recipe.difficultyColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        recipe.difficultyLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  // Time badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: Color(0xFF516072)),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.durationMinutes} min',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF516072)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            recipe.authorColor.withValues(alpha: 0.15),
                        child: Text(recipe.authorInitials,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: recipe.authorColor)),
                      ),
                      const SizedBox(width: 8),
                      Text(recipe.authorName,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF516072))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _trustColorForLevel(recipe.authorTrustLevel)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recipe.authorTrustLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _trustColorForLevel(recipe.authorTrustLevel),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (recipe.ratingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${recipe.averageRating.toStringAsFixed(1)} ★ · ${recipe.ratingCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE07B39),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(recipe.title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2A3A))),
                  const SizedBox(height: 4),
                  Text(recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF516072), height: 1.4)),

                  if (familySummary != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      familySummary,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],

                  if (visibleInfoTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: visibleInfoTags
                          .map((tag) => _buildFoodInfoChip(tag))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    'Reichweite: ${recipe.viewCount} Aufrufe',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A9AB0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Like
                      GestureDetector(
                        onTap: () {
                          _likeCtrl.forward().then((_) => _likeCtrl.reverse());
                          widget.onLike();
                        },
                        child: ScaleTransition(
                          scale: _likeScale,
                          child: Row(
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color:
                                    isLiked ? _brand : const Color(0xFF8A9AB0),
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text('${recipe.likedByUserIds.length}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isLiked
                                          ? _brand
                                          : const Color(0xFF8A9AB0))),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Save button
                      GestureDetector(
                        onTap: widget.onSave,
                        child: Icon(
                          recipe.isSavedByMe
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: recipe.isSavedByMe
                              ? _brand
                              : const Color(0xFF8A9AB0),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // View Recipe button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _brandLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Rezept ansehen →',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _brand),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RECIPE DETAIL SHEET
// ============================================================

class _RecipeDetailSheet extends StatelessWidget {
  final SharedRecipe recipe;

  const _RecipeDetailSheet({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final visibleInfoTags = _visibleFoodInfoTags(recipe.tags);
    final familySummary = _familyFitSummaryForTags(recipe.tags);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [
                  recipe.authorColor.withValues(alpha: 0.15),
                  recipe.authorColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Stack(
              children: [
                Center(
                    child: Text(recipe.imageEmoji,
                        style: const TextStyle(fontSize: 56))),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2A3A))),
                  const SizedBox(height: 4),
                  Text('von ${recipe.authorName}',
                      style: const TextStyle(
                          color: Color(0xFF8A9AB0), fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statChip(
                          Icons.verified_user_rounded, recipe.authorTrustLabel),
                      if (recipe.authorPublishedRecipesCount > 0)
                        _statChip(Icons.menu_book_rounded,
                            '${recipe.authorPublishedRecipesCount} Rezepte'),
                      if (recipe.authorActiveOffersCount > 0)
                        _statChip(Icons.favorite_rounded,
                            '${recipe.authorActiveOffersCount} Angebote'),
                      if (recipe.authorCompletedShares > 0)
                        _statChip(Icons.handshake_rounded,
                            '${recipe.authorCompletedShares} Teilungen'),
                      if (recipe.authorCompletionRate > 0)
                        _statChip(Icons.check_circle_outline_rounded,
                            '${(recipe.authorCompletionRate * 100).round()}% Abschluss'),
                      if (recipe.authorReliabilityLevel != 'new')
                        _statChip(Icons.shield_rounded,
                            recipe.authorReliabilityLabel),
                      if (recipe.authorLastSharedAt != null)
                        _statChip(Icons.update_rounded,
                            _lastSharedLabelFor(recipe.authorLastSharedAt)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (visibleInfoTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: visibleInfoTags
                          .map((tag) => _buildFoodInfoChip(tag))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Stats row
                  Row(
                    children: [
                      _statChip(Icons.schedule_rounded,
                          '${recipe.durationMinutes} min'),
                      const SizedBox(width: 8),
                      _statChip(
                          Icons.bar_chart_rounded, recipe.difficultyLabel),
                      const SizedBox(width: 8),
                      _statChip(Icons.star_rounded,
                          '${recipe.averageRating.toStringAsFixed(1)} (${recipe.ratingCount})'),
                      const SizedBox(width: 8),
                      _statChip(
                          Icons.visibility_rounded, '${recipe.viewCount}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(recipe.description,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF516072), height: 1.5)),
                  if (familySummary != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Kurz für Eltern: $familySummary',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Ingredients
                  const Text('🛒 Zutaten',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2A3A))),
                  const SizedBox(height: 10),
                  ...recipe.ingredients
                      .asMap()
                      .entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _brandLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _brand)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(e.value,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1A2A3A))),
                                ),
                              ],
                            ),
                          ))
                      .toList(),

                  const SizedBox(height: 20),

                  // Steps
                  const Text('👨‍🍳 Zubereitung',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2A3A))),
                  const SizedBox(height: 10),
                  ...recipe.steps
                      .asMap()
                      .entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _brand,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(e.value,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF516072),
                                            height: 1.5)),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _brandLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _brand),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _brand)),
        ],
      ),
    );
  }
}

class _RecipeDraft {
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int durationMinutes;
  final int servings;
  final List<Map<String, String>> ingredients;
  final List<String> steps;
  final List<String> tags;

  const _RecipeDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.tags,
  });
}

// ============================================================
// CREATE RECIPE SHEET
// ============================================================

class _CreateRecipeSheet extends StatefulWidget {
  final Future<bool> Function(_RecipeDraft) onSubmit;

  const _CreateRecipeSheet({required this.onSubmit});

  @override
  State<_CreateRecipeSheet> createState() => _CreateRecipeSheetState();
}

class _CreateRecipeSheetState extends State<_CreateRecipeSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  int _duration = 30;
  int _servings = 4;
  RecipeDifficulty _difficulty = RecipeDifficulty.einfach;
  String _category = 'dinner';
  String _emoji = '🍲';
  final Set<String> _selectedInfoTags = {'kinderfreundlich'};

  final List<String> _emojis = [
    '🍲',
    '🍝',
    '🥗',
    '🍱',
    '🥘',
    '🍜',
    '🥙',
    '🫕',
    '🍛',
    '🥞'
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _ingredientsCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E3E8),
                      borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 16),
            const Center(
                child: Text('📖 Rezept teilen',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2A3A)))),
            const SizedBox(height: 4),
            Center(
                child: Text(_t('satt_share_hint'),
                    style: TextStyle(color: Color(0xFF8A9AB0), fontSize: 13))),
            const SizedBox(height: 20),

            // Emoji picker
            Text(_t('satt_choose_emoji'),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _emojis
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? _brandLight
                                : const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    _emoji == e ? _brand : Colors.transparent,
                                width: 1.5),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),

            const Text('Rezeptname',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 6),
            TextField(
                controller: _titleCtrl,
                decoration: _inputDeco('z. B. Mamas Linsensuppe 🍲')),
            const SizedBox(height: 12),

            const Text('Kurze Beschreibung',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 6),
            TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: _inputDeco('Was macht dieses Rezept besonders?')),
            const SizedBox(height: 12),

            const Text('Kategorie',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                DropdownMenuItem(
                    value: 'breakfast',
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'breakfast'))),
                DropdownMenuItem(
                    value: 'lunch',
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'lunch'))),
                DropdownMenuItem(
                    value: 'dinner',
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'dinner'))),
                DropdownMenuItem(
                    value: 'snack',
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'snack'))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
              decoration: _inputDeco('Kategorie wählen'),
            ),
            const SizedBox(height: 12),

            const Text('Hinweise für Eltern',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foodInfoMetaByTag.entries.map((entry) {
                final selected = _selectedInfoTags.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _selectedInfoTags.remove(entry.key);
                      } else {
                        _selectedInfoTags.add(entry.key);
                      }
                    });
                  },
                  selectedColor: entry.value.tint,
                  side: BorderSide(
                    color: selected ? _brand : const Color(0xFFE5E7EB),
                  ),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            const Text('Zutaten (eine pro Zeile)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 6),
            TextField(
                controller: _ingredientsCtrl,
                maxLines: 4,
                decoration: _inputDeco(
                    'z. B.\n200g rote Linsen\n1 Zwiebel\n2 Karotten')),
            const SizedBox(height: 12),

            Text(_t('satt_preparation_steps'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A))),
            const SizedBox(height: 6),
            TextField(
                controller: _stepsCtrl,
                maxLines: 5,
                decoration: _inputDeco(
                    'z. B.\nZwiebeln anbraten\nLinsen hinzufügen...')),
            const SizedBox(height: 12),

            // Duration + Difficulty
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zeit (min)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2A3A))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton.outlined(
                            onPressed: () {
                              if (_duration > 5) setState(() => _duration -= 5);
                            },
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            padding: const EdgeInsets.all(4),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('$_duration',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                                backgroundColor: _brand,
                                padding: const EdgeInsets.all(4)),
                            onPressed: () => setState(() => _duration += 5),
                            icon: const Icon(Icons.add_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Portionen',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2A3A))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton.outlined(
                            onPressed: () {
                              if (_servings > 1) setState(() => _servings -= 1);
                            },
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            padding: const EdgeInsets.all(4),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_servings',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                                backgroundColor: _brand,
                                padding: const EdgeInsets.all(4)),
                            onPressed: () => setState(() => _servings += 1),
                            icon: const Icon(Icons.add_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schwierigkeit',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2A3A))),
                      const SizedBox(height: 6),
                      DropdownButton<RecipeDifficulty>(
                        value: _difficulty,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: RecipeDifficulty.values.map((d) {
                          final labels = [
                            'Einfach',
                            'Mittel',
                            'Fortgeschritten'
                          ];
                          return DropdownMenuItem(
                              value: d, child: Text(labels[d.index]));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _difficulty = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final title = _titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final ingredients = _ingredientsCtrl.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  final steps = _stepsCtrl.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  final draft = _RecipeDraft(
                    title: title,
                    description: _descCtrl.text.trim(),
                    category: _category,
                    difficulty: _difficulty == RecipeDifficulty.einfach
                        ? 'leicht'
                        : _difficulty == RecipeDifficulty.mittel
                            ? 'mittel'
                            : 'schwer',
                    durationMinutes: _duration,
                    servings: _servings,
                    ingredients: (ingredients.isEmpty
                            ? ['Zutaten werden noch ergänzt']
                            : ingredients)
                        .map(
                          (value) => {
                            'name': value,
                            'quantity': '',
                            'unit': '',
                          },
                        )
                        .toList(),
                    steps: steps.isEmpty
                        ? ['Zubereitung wird noch ergänzt']
                        : steps,
                    tags: _buildDraftTags(
                        _duration, _difficulty, _category, _selectedInfoTags),
                  );

                  final success = await widget.onSubmit(draft);
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  }
                },
                child: Text(_t('satt_share_recipe'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _buildDraftTags(
    int duration,
    RecipeDifficulty difficulty,
    String category,
    Set<String> selectedInfoTags,
  ) {
    final tags = <String>{'familie', ...selectedInfoTags};
    if (duration <= 30) tags.add('schnell');
    if (difficulty == RecipeDifficulty.einfach) tags.add('kinderfreundlich');
    if (category == 'snack') tags.add('alltagssnack');
    if (category == 'breakfast') tags.add('fruehstueck');
    return tags.toList();
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0BBC8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brand, width: 1.5)),
    );
  }
}

// ============================================================
// MEAL PLANNER COMPONENTS
// ============================================================

class _DayPlanCard extends StatelessWidget {
  final DayPlan dayPlan;
  final VoidCallback onAddMeal;
  final Function(MealType) onRemoveMeal;
  final Function(Meal) onTapMeal;

  const _DayPlanCard({
    required this.dayPlan,
    required this.onAddMeal,
    required this.onRemoveMeal,
    required this.onTapMeal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: dayPlan.isToday ? const Color(0xFFFFF1EE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dayPlan.isToday
              ? const Color(0xFFE8543A)
              : const Color(0xFFE8E8E8),
          width: dayPlan.isToday ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header with day name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dayPlan.isToday
                  ? const Color(0xFFE8543A)
                  : const Color(0xFFF5F5F5),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayPlan.dayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dayPlan.isToday
                            ? Colors.white
                            : const Color(0xFF516072),
                      ),
                    ),
                    Text(
                      '${dayPlan.dayOfMonth}.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: dayPlan.isToday
                            ? Colors.white70
                            : const Color(0xFF8A9BA8),
                      ),
                    ),
                  ],
                ),
                if (dayPlan.isToday)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Heute',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8543A),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Meals list
          if (dayPlan.meals.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text(
                    '📅 Nichts geplant',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF516072).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onAddMeal,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'add_meal')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE8543A),
                      side: const BorderSide(color: Color(0xFFE8543A)),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ...dayPlan.meals.map((meal) => _MealListItem(
                        meal: meal,
                        onTap: () => onTapMeal(meal),
                        onRemove: () => onRemoveMeal(meal.type),
                      )),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onAddMeal,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(_t('satt_add')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE8543A),
                          side: const BorderSide(color: Color(0xFFE8543A)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MealListItem extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _MealListItem({
    required this.meal,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: meal.type.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: meal.type.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Text(meal.type.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2A3A),
                      ),
                    ),
                    if (meal.description != null &&
                        meal.description!.isNotEmpty)
                      Text(
                        meal.description!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A9BA8),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: const Color(0xFF8A9BA8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMealSheet extends StatefulWidget {
  final DateTime date;
  final Function(Meal) onSubmit;

  const _AddMealSheet({
    required this.date,
    required this.onSubmit,
  });

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  late MealType _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _ingredientsController;

  @override
  void initState() {
    super.initState();
    _selectedType = MealType.lunch;
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _ingredientsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;

    final meal = Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      type: _selectedType,
      description: _descController.text.trim(),
      ingredients: _ingredientsController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    widget.onSubmit(meal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mahlzeit hinzufügen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2A3A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF516072),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Meal type selector
              const Text(
                'Mahlzeitentyp',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF516072),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MealType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return FilterChip(
                    label: Text('${type.emoji} ${type.label}'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedType = type),
                    backgroundColor: Colors.white,
                    selectedColor: type.color.withValues(alpha: 0.2),
                    side: BorderSide(
                      color: isSelected ? type.color : const Color(0xFFE8E8E8),
                      width: isSelected ? 2 : 1,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: type.color,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Title
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Mahlzeitenname *',
                  hintText: 'z.B. Spaghetti Carbonara',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFD),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8543A), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Description
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Beschreibung',
                  hintText: 'z.B. Mit frischem Parmesan',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFD),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8543A), width: 2),
                  ),
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Ingredients
              TextField(
                controller: _ingredientsController,
                decoration: InputDecoration(
                  labelText: 'Zutaten (optional)',
                  hintText: 'Eine pro Zeile:\nSpaghetti\nEier\nSpeck',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFD),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8543A), width: 2),
                  ),
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8543A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hinzufügen',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealDetailSheet extends StatelessWidget {
  final Meal meal;

  const _MealDetailSheet({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${meal.type.emoji} ${meal.type.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A9BA8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meal.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (meal.description != null && meal.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  meal.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF516072),
                    height: 1.5,
                  ),
                ),
              ],
              if (meal.ingredients.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Zutaten',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
                const SizedBox(height: 10),
                ...meal.ingredients.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE8543A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF516072),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
