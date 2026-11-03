import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/models/moment.dart';

/// Backend-Client für die Familien-Community-Momente.
///
/// Erstellen (Text + mehrere Bilder), Feed laden (Sichtbarkeit serverseitig
/// durchgesetzt), Herz-Reaktion, Kommentare und Löschen. Bilder laufen über
/// den bestehenden sanitisierten `/uploads/image`-Endpoint.
class MomentsService {
  static final MomentsService instance = MomentsService._();
  MomentsService._();

  // Verifizierter Client: Momente sind owner-/sichtbarkeitsgeprüft, daher ist
  // ein echtes Firebase-Token nötig (kein statischer Fallback).
  final BackendApiClient? _api =
      BackendServiceFactory.createVerifiedApiClient();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String get _myName {
    final n = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return (n != null && n.isNotEmpty) ? n : 'Familie';
  }

  /// Lädt den sichtbaren Feed (eigene + öffentliche + von verbundenen Familien).
  Future<List<Moment>> loadFeed() async {
    final api = _api;
    if (api == null) return [];
    try {
      final res = await api.getJson('/api/moments');
      if (res is Map<String, dynamic> && res['moments'] is List) {
        return (res['moments'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Moment.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('MomentsService.loadFeed failed: $e');
    }
    return [];
  }

  /// Lädt ein Bild hoch und liefert die öffentliche URL (web-sicher: Bytes).
  Future<String?> uploadImage(XFile image) async {
    final api = _api;
    if (api == null) return null;
    try {
      final bytes = await image.readAsBytes();
      final response = await api.uploadImageBytes(
        '/uploads/image',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'moment.jpg',
      );
      final url = response['url'] as String?;
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (e) {
      debugPrint('MomentsService.uploadImage failed: $e');
    }
    return null;
  }

  /// Erstellt einen Moment. Braucht Text ODER mindestens ein Bild.
  Future<Moment?> createMoment({
    String text = '',
    List<String> imageUrls = const [],
    String visibility = 'friends',
  }) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return null;
    if (text.trim().isEmpty && imageUrls.isEmpty) return null;
    try {
      final res = await api.postJsonAny('/api/moments', {
        'authorUserId': uid,
        'authorName': _myName,
        'text': text.trim(),
        'imageUrls': imageUrls,
        'visibility': visibility,
      });
      if (res is Map<String, dynamic> && res['moment'] is Map) {
        return Moment.fromJson((res['moment'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('MomentsService.createMoment failed: $e');
      rethrow;
    }
    return null;
  }

  /// Herz toggeln. Gibt den aktualisierten Moment zurück oder null.
  Future<Moment?> toggleHeart(String momentId) async {
    final api = _api;
    if (api == null) return null;
    try {
      final res = await api.postJsonAny('/api/moments/$momentId/react', {});
      if (res is Map<String, dynamic> && res['moment'] is Map) {
        return Moment.fromJson((res['moment'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('MomentsService.toggleHeart failed: $e');
      rethrow;
    }
    return null;
  }

  /// Lädt die Kommentare eines Moments.
  Future<List<MomentComment>> loadComments(String momentId) async {
    final api = _api;
    if (api == null) return [];
    try {
      final res = await api.getJson('/api/moments/$momentId/comments');
      if (res is Map<String, dynamic> && res['comments'] is List) {
        return (res['comments'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MomentComment.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('MomentsService.loadComments failed: $e');
    }
    return [];
  }

  /// Fügt einen Kommentar hinzu. Gibt den erstellten Kommentar zurück.
  Future<MomentComment?> addComment(String momentId, String text) async {
    final api = _api;
    if (api == null || text.trim().isEmpty) return null;
    try {
      final res = await api.postJsonAny('/api/moments/$momentId/comments', {
        'authorName': _myName,
        'text': text.trim(),
      });
      if (res is Map<String, dynamic> && res['comment'] is Map) {
        return MomentComment.fromJson(
            (res['comment'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('MomentsService.addComment failed: $e');
      rethrow;
    }
    return null;
  }

  /// Löscht einen Kommentar (Kommentar- oder Moment-Autor).
  Future<bool> deleteComment(String momentId, String commentId) async {
    final api = _api;
    if (api == null) return false;
    try {
      await api.delete('/api/moments/$momentId/comments/$commentId');
      return true;
    } catch (e) {
      debugPrint('MomentsService.deleteComment failed: $e');
      return false;
    }
  }

  /// Löscht einen eigenen Moment.
  Future<bool> deleteMoment(String momentId) async {
    final api = _api;
    if (api == null) return false;
    try {
      await api.delete('/api/moments/$momentId');
      return true;
    } catch (e) {
      debugPrint('MomentsService.deleteMoment failed: $e');
      return false;
    }
  }
}
