/// Gemeinsam Satt - Shared Recipes Service
/// Modern, secure recipe sharing with Postgres persistence
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/config/api_config.dart';

class AuthorTrustSummary {
  final String level;
  final String label;
  final int publishedRecipesCount;
  final int activeOffersCount;
  final int completedShares;
  final double completionRate;
  final String reliabilityLevel;
  final String reliabilityLabel;
  final DateTime? lastSharedAt;
  final double averageRating;
  final int totalReports;

  const AuthorTrustSummary({
    required this.level,
    required this.label,
    required this.publishedRecipesCount,
    required this.activeOffersCount,
    required this.completedShares,
    required this.completionRate,
    required this.reliabilityLevel,
    required this.reliabilityLabel,
    required this.lastSharedAt,
    required this.averageRating,
    required this.totalReports,
  });

  factory AuthorTrustSummary.fromJson(Map<String, dynamic> json) {
    return AuthorTrustSummary(
      level: (json['level'] ?? 'new').toString(),
      label: (json['label'] ?? 'Neu im Teilen').toString(),
      publishedRecipesCount: (json['publishedRecipesCount'] as num?)?.toInt() ?? 0,
      activeOffersCount: (json['activeOffersCount'] as num?)?.toInt() ?? 0,
      completedShares: (json['completedShares'] as num?)?.toInt() ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      reliabilityLevel: (json['reliabilityLevel'] ?? 'new').toString(),
      reliabilityLabel: (json['reliabilityLabel'] ?? 'Noch wenig Nachweise').toString(),
      lastSharedAt: json['lastSharedAt'] != null
          ? DateTime.tryParse(json['lastSharedAt'].toString())
          : null,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      totalReports: (json['totalReports'] as num?)?.toInt() ?? 0,
    );
  }
}

class SharedRecipe {
  final String id;
  final String? creatorUserId;
  final String? familyId;
  final String title;
  final String? description;
  final String category;
  final String difficulty; // leicht, mittel, schwer
  final int? prepTimeMinutes;
  final int servings;
  final List<Map<String, String>> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final String? imageUrl;
  final double rating;
  final int ratingCount;
  final int viewCount;
  final bool isPublished;
  final bool isFeatured;
  final AuthorTrustSummary? authorTrust;
  final DateTime createdAt;
  final DateTime updatedAt;

  SharedRecipe({
    required this.id,
    this.creatorUserId,
    this.familyId,
    required this.title,
    this.description,
    required this.category,
    required this.difficulty,
    this.prepTimeMinutes,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.tags,
    this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.viewCount,
    required this.isPublished,
    required this.isFeatured,
    this.authorTrust,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharedRecipe.fromJson(Map<String, dynamic> json) {
    final ingredientsJson = json['ingredients'];
    List<Map<String, String>> parsedIngredients = [];
    if (ingredientsJson is String) {
      try {
        final decoded = jsonDecode(ingredientsJson) as List;
        parsedIngredients = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }

    final instructionsJson = json['instructions'];
    List<String> parsedInstructions = [];
    if (instructionsJson is String) {
      try {
        final decoded = jsonDecode(instructionsJson) as List;
        parsedInstructions = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    return SharedRecipe(
      id: json['id'] ?? '',
      creatorUserId: json['creatorUserId'],
      familyId: json['familyId'],
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'dinner',
      difficulty: json['difficulty'] ?? 'mittel',
      prepTimeMinutes: json['prepTimeMinutes'],
      servings: json['servings'] ?? 2,
      ingredients: parsedIngredients,
      instructions: parsedInstructions,
      tags: List<String>.from(json['tags'] ?? []),
      imageUrl: json['imageUrl'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      isPublished: json['isPublished'] ?? true,
      isFeatured: json['isFeatured'] ?? false,
      authorTrust: json['authorTrust'] is Map<String, dynamic>
          ? AuthorTrustSummary.fromJson(json['authorTrust'] as Map<String, dynamic>)
          : json['authorTrust'] is Map
              ? AuthorTrustSummary.fromJson(Map<String, dynamic>.from(json['authorTrust'] as Map))
              : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'difficulty': difficulty,
    'prepTimeMinutes': prepTimeMinutes,
    'servings': servings,
    'ingredients': ingredients,
    'instructions': instructions,
    'tags': tags,
    'imageUrl': imageUrl,
  };
}

class RecipeRating {
  final String id;
  final String recipeId;
  final String userId;
  final int rating; // 1-5
  final String? comment;
  final DateTime createdAt;

  RecipeRating({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory RecipeRating.fromJson(Map<String, dynamic> json) {
    return RecipeRating(
      id: json['id'] ?? '',
      recipeId: json['recipeId'] ?? '',
      userId: json['userId'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
    );
  }
}

class GemeinsamSattBackendService {
  final String? _apiUrl = APIConfig.getBackendBaseUrl();
  final String? _apiToken = APIConfig.getBackendApiToken();
  final http.Client _httpClient;
  final Future<String?> Function() _firebaseTokenProvider;
  String? lastSyncError;

  GemeinsamSattBackendService({
    http.Client? httpClient,
    Future<String?> Function()? firebaseTokenProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _firebaseTokenProvider = firebaseTokenProvider ??
            (() async => FirebaseAuth.instance.currentUser?.getIdToken());

  Future<Map<String, String>> _jsonHeaders(
      {bool requireFirebase = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final firebaseToken = await _firebaseTokenProvider();
    if (requireFirebase &&
        (firebaseToken == null || firebaseToken.trim().isEmpty)) {
      throw StateError('Firebase session required for this request.');
    }
    final token = (firebaseToken ?? _apiToken)?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Get published recipes with pagination, filtering, and sorting
  /// Modern query support: category, difficulty, search, sortBy
  Future<Map<String, dynamic>> fetchRecipes({
    int skip = 0,
    int take = 20,
    String? category,
    String? difficulty,
    String? search,
    String sortBy = 'createdAt', // 'createdAt' or 'rating'
  }) async {
    lastSyncError = null;

    if (_apiUrl == null) {
      lastSyncError = 'Backend-URL nicht konfiguriert';
      return {'recipes': [], 'total': 0};
    }

    try {
      final queryParams = {
        'skip': skip.toString(),
        'take': take.toString(),
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
        if (search != null) 'search': search,
        'sortBy': sortBy,
      };

      final uri = Uri.parse('$_apiUrl/api/food-feed/recipes').replace(queryParameters: queryParams);

      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        lastSyncError = 'Rezepte konnten nicht geladen werden: ${response.statusCode}';
        return {'recipes': [], 'total': 0};
      }

      final data = jsonDecode(response.body);
      final recipes = List<SharedRecipe>.from(
        (data['recipes'] as List? ?? []).map((r) => SharedRecipe.fromJson(r as Map<String, dynamic>)),
      );
      final total = data['total'] ?? 0;

      return {'recipes': recipes, 'total': total};
    } catch (e) {
      lastSyncError = 'Fehler beim Abrufen von Rezepten: $e';
      return {'recipes': [], 'total': 0};
    }
  }

  /// Get full recipe details including ratings
  Future<SharedRecipe?> getRecipe(String id) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.get(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$id'),
      );

      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        lastSyncError = 'Rezept konnte nicht geladen werden: ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body);
      return SharedRecipe.fromJson(data['recipe']);
    } catch (e) {
      lastSyncError = 'Fehler beim Abrufen des Rezepts: $e';
      return null;
    }
  }

  /// Create a new shared recipe (auth required)
  /// Validates all fields server-side for security
  Future<SharedRecipe?> createRecipe({
    required String userId,
    String? familyId,
    required String title,
    String? description,
    required String category,
    required String difficulty,
    int? prepTimeMinutes,
    required int servings,
    required List<Map<String, String>> ingredients,
    required List<String> instructions,
    List<String>? tags,
    String? imageUrl,
  }) async {
    lastSyncError = null;

    if (title.isEmpty) {
      lastSyncError = 'Titel ist erforderlich';
      return null;
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/food-feed/recipes'),
        headers: await _jsonHeaders(requireFirebase: true),
        body: jsonEncode({
          'userId': userId,
          if (familyId != null) 'familyId': familyId,
          'title': title,
          'description': description,
          'category': category,
          'difficulty': difficulty,
          'prepTimeMinutes': prepTimeMinutes,
          'servings': servings,
          'ingredients': ingredients,
          'instructions': instructions,
          'tags': tags ?? [],
          'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode != 201) {
        lastSyncError = 'Rezept konnte nicht erstellt werden: ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body);
      return SharedRecipe.fromJson(data['recipe']);
    } catch (e) {
      lastSyncError = 'Fehler beim Erstellen des Rezepts: $e';
      return null;
    }
  }

  /// Update an existing recipe (owner/creator only)
  Future<SharedRecipe?> updateRecipe({
    required String id,
    required String userId,
    String? title,
    String? description,
    String? category,
    String? difficulty,
    int? prepTimeMinutes,
    int? servings,
    List<Map<String, String>>? ingredients,
    List<String>? instructions,
    List<String>? tags,
  }) async {
    lastSyncError = null;

    try {
      final body = <String, dynamic>{'userId': userId};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;
      if (difficulty != null) body['difficulty'] = difficulty;
      if (prepTimeMinutes != null) body['prepTimeMinutes'] = prepTimeMinutes;
      if (servings != null) body['servings'] = servings;
      if (ingredients != null) body['ingredients'] = ingredients;
      if (instructions != null) body['instructions'] = instructions;
      if (tags != null) body['tags'] = tags;

      final response = await _httpClient.put(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$id'),
        headers: await _jsonHeaders(requireFirebase: true),
        body: jsonEncode(body),
      );

      if (response.statusCode == 403) {
        lastSyncError = 'Nur der Ersteller kann dieses Rezept bearbeiten';
        return null;
      }

      if (response.statusCode != 200) {
        lastSyncError = 'Rezept konnte nicht aktualisiert werden: ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body);
      return SharedRecipe.fromJson(data['recipe']);
    } catch (e) {
      lastSyncError = 'Fehler beim Aktualisieren des Rezepts: $e';
      return null;
    }
  }

  /// Delete a recipe (owner/creator only)
  Future<bool> deleteRecipe({
    required String id,
    required String userId,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.delete(
        Uri.parse(
          '$_apiUrl/api/food-feed/recipes/$id?userId=${Uri.encodeQueryComponent(userId)}',
        ),
        headers: await _jsonHeaders(requireFirebase: true),
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 403) {
        lastSyncError = 'Nur der Ersteller kann dieses Rezept löschen';
        return false;
      }

      if (response.statusCode != 200) {
        lastSyncError = 'Rezept konnte nicht gelöscht werden: ${response.statusCode}';
        return false;
      }

      return true;
    } catch (e) {
      lastSyncError = 'Fehler beim Löschen des Rezepts: $e';
      return false;
    }
  }

  /// Rate a recipe (1-5 stars with optional comment)
  /// Automatically recalculates average rating when submitted
  Future<RecipeRating?> rateRecipe({
    required String recipeId,
    required String userId,
    required int rating, // 1-5
    String? comment,
  }) async {
    lastSyncError = null;

    if (rating < 1 || rating > 5) {
      lastSyncError = 'Rating muss zwischen 1 und 5 Sternen liegen';
      return null;
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/rate'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'userId': userId,
          'rating': rating,
          'comment': comment,
        }),
      );

      if (response.statusCode != 201) {
        lastSyncError = 'Rating konnte nicht gespeichert werden: ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body);
      return RecipeRating.fromJson(data['rating']);
    } catch (e) {
      lastSyncError = 'Fehler beim Speichern des Ratings: $e';
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOfferComments({
    required String recipeId,
    int limit = 40,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.get(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/comments?limit=$limit'),
      );

      if (response.statusCode != 200) {
        lastSyncError =
            'Kommentare konnten nicht geladen werden: ${response.statusCode}';
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final comments = (data['comments'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const <Map<String, dynamic>>[];
      return comments;
    } catch (e) {
      lastSyncError = 'Fehler beim Laden der Kommentare: $e';
      return const [];
    }
  }

  Future<Map<String, dynamic>?> createOfferComment({
    required String recipeId,
    required String userId,
    required String text,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/comments'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId, 'text': text}),
      );

      if (response.statusCode != 201) {
        lastSyncError =
            'Kommentar konnte nicht gespeichert werden: ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['comment'] is! Map) return null;
      return Map<String, dynamic>.from(data['comment'] as Map);
    } catch (e) {
      lastSyncError = 'Fehler beim Speichern des Kommentars: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> reserveOffer({
    required String recipeId,
    required String userId,
    int portions = 1,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/reserve'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'userId': userId,
          'portions': portions,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        lastSyncError =
            'Reservierung konnte nicht gespeichert werden: ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      lastSyncError = 'Fehler bei der Reservierung: $e';
      return null;
    }
  }

  Future<bool> cancelOfferReservation({
    required String recipeId,
    required String userId,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.delete(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/reserve?userId=$userId'),
        headers: await _jsonHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        lastSyncError =
            'Reservierung konnte nicht entfernt werden: ${response.statusCode}';
        return false;
      }

      return true;
    } catch (e) {
      lastSyncError = 'Fehler beim Entfernen der Reservierung: $e';
      return false;
    }
  }

  Future<bool> completeOfferShare({
    required String recipeId,
    required String userId,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/complete'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode != 200) {
        lastSyncError =
            'Abholung konnte nicht bestaetigt werden: ${response.statusCode}';
        return false;
      }

      return true;
    } catch (e) {
      lastSyncError = 'Fehler beim Bestaetigen der Abholung: $e';
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchOfferReservationSummary({
    required String recipeId,
    required String userId,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.get(
        Uri.parse(
          '$_apiUrl/api/food-feed/recipes/$recipeId/reservations?userId=$userId',
        ),
      );

      if (response.statusCode != 200) {
        lastSyncError =
            'Reservierungsstatus konnte nicht geladen werden: ${response.statusCode}';
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      lastSyncError = 'Fehler beim Laden des Reservierungsstatus: $e';
      return null;
    }
  }

  Future<bool> reportOffer({
    required String recipeId,
    required String userId,
    required String reason,
    String? note,
  }) async {
    lastSyncError = null;

    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/food-feed/recipes/$recipeId/report'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'reportedById': userId,
          'reason': reason,
          if (note != null && note.trim().isNotEmpty) 'details': note.trim(),
        }),
      );

      if (response.statusCode == 409) {
        lastSyncError = 'Dieses Angebot wurde bereits von dir gemeldet';
        return false;
      }

      if (response.statusCode != 201) {
        lastSyncError = 'Meldung konnte nicht gespeichert werden: ${response.statusCode}';
        return false;
      }

      return true;
    } catch (e) {
      lastSyncError = 'Fehler beim Melden des Angebots: $e';
      return false;
    }
  }
}
