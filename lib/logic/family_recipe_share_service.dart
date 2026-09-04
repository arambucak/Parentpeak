import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/models/shared_family_recipe.dart';

/// Service fuer geteilte Familien-Rezepte (Phase 3a).
///
/// Erstellen (mit optionalem Foto-Upload), Laden inkl. Suche + Filter,
/// Reaktionen ("Das kochen wir nach!" / "Hat geschmeckt!") und Loeschen.
/// Die Sichtbarkeit wird serverseitig durchgesetzt — der Client zeigt nur an,
/// was der Server ausliefert.
class FamilyRecipeShareService {
  static final FamilyRecipeShareService instance = FamilyRecipeShareService._();
  FamilyRecipeShareService._();

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
          ? FirebaseAuth.instance.currentUser!.displayName!.trim()
          : 'Familie';

  /// Laedt sichtbare Rezepte (eigene + oeffentliche + von Freunden).
  /// [query] durchsucht Gericht-Name und Zutaten.
  Future<List<SharedFamilyRecipe>> loadRecipes({String query = ''}) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return [];
    try {
      final q = query.trim();
      final path = q.isEmpty
          ? '/api/recipes?userId=${Uri.encodeComponent(uid)}'
          : '/api/recipes?userId=${Uri.encodeComponent(uid)}&q=${Uri.encodeComponent(q)}';
      final res = await api.getJson(path);
      if (res is Map<String, dynamic> && res['recipes'] is List) {
        return (res['recipes'] as List)
            .whereType<Map<String, dynamic>>()
            .map(SharedFamilyRecipe.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('FamilyRecipeShareService.loadRecipes failed: $e');
    }
    return [];
  }

  /// Laedt ein optionales Foto hoch und liefert die oeffentliche URL zurueck.
  /// Web-sicher: nutzt Bytes statt Datei-Pfad. Gibt null zurueck bei Fehler.
  Future<String?> uploadPhoto(XFile image) async {
    final api = _api;
    if (api == null) return null;
    try {
      final bytes = await image.readAsBytes();
      final response = await api.uploadImageBytes(
        '/uploads/image',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'rezept.jpg',
      );
      final url = response['url'] as String?;
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (e) {
      debugPrint('FamilyRecipeShareService.uploadPhoto failed: $e');
    }
    return null;
  }

  /// Erstellt ein neues Rezept. Gibt das erstellte Rezept zurueck oder null.
  Future<SharedFamilyRecipe?> createRecipe({
    required String title,
    String description = '',
    String photoUrl = '',
    List<String> ingredients = const [],
    List<String> steps = const [],
    int prepMinutes = 0,
    String visibility = 'friends',
    List<String> tags = const [],
  }) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return null;
    if (title.trim().isEmpty) return null;
    try {
      final res = await api.postJsonAny('/api/recipes', {
        'authorUserId': uid,
        'authorName': _myName,
        'title': title.trim(),
        'description': description.trim(),
        'photoUrl': photoUrl,
        'ingredients': ingredients,
        'steps': steps,
        'prepMinutes': prepMinutes,
        'visibility': visibility,
        'tags': tags,
      });
      if (res is Map<String, dynamic> && res['recipe'] is Map) {
        return SharedFamilyRecipe.fromJson(
            (res['recipe'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('FamilyRecipeShareService.createRecipe failed: $e');
      rethrow;
    }
    return null;
  }

  /// Reaktion toggeln: 'cook' oder 'tasty'. Gibt das aktualisierte Rezept
  /// zurueck oder null.
  Future<SharedFamilyRecipe?> react(String recipeId, String type) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return null;
    if (type != 'cook' && type != 'tasty') return null;
    try {
      final res = await api.postJsonAny('/api/recipes/$recipeId/react', {
        'userId': uid,
        'type': type,
      });
      if (res is Map<String, dynamic> && res['recipe'] is Map) {
        return SharedFamilyRecipe.fromJson(
            (res['recipe'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('FamilyRecipeShareService.react failed: $e');
      rethrow;
    }
    return null;
  }

  /// Loescht ein eigenes Rezept.
  Future<bool> deleteRecipe(String recipeId) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return false;
    try {
      await api
          .delete('/api/recipes/$recipeId?userId=${Uri.encodeComponent(uid)}');
      return true;
    } catch (e) {
      debugPrint('FamilyRecipeShareService.deleteRecipe failed: $e');
      return false;
    }
  }
}
