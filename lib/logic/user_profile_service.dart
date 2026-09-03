import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Die eine Identitaet: uid -> Anzeigename (app-weit). Der Name wird EINMAL
/// bei der Registrierung gesetzt und ueberall automatisch verwendet.
/// username/searchable/isPrivate sind optional (Default: privat, nicht
/// auffindbar) und werden erst in Schritt 2 (Suche) relevant.
class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Anzeigename serverseitig setzen/aktualisieren (app-weit gueltig).
  Future<void> setDisplayName(String displayName) async {
    final api = _api;
    final uid = _uid;
    final name = displayName.trim();
    if (api == null || uid == null || uid.isEmpty || name.isEmpty) return;
    try {
      await api.postJsonAny('/api/profile', {
        'userId': uid,
        'displayName': name,
      });
    } catch (e) {
      debugPrint('UserProfileService.setDisplayName failed: $e');
    }
  }

  /// Anzeigename einer beliebigen UID laden (z.B. fuer Anzeige). Leer wenn
  /// unbekannt.
  Future<String> displayNameFor(String uid) async {
    final api = _api;
    if (api == null || uid.isEmpty) return '';
    try {
      final data = await api.getJson('/api/profile/$uid');
      if (data is Map<String, dynamic> && data['exists'] == true) {
        return (data['displayName'] as String?)?.trim() ?? '';
      }
    } catch (e) {
      debugPrint('UserProfileService.displayNameFor failed: $e');
    }
    return '';
  }

  /// Sichtbarkeit/Suchbarkeit setzen (Schritt 2). searchable=true macht das
  /// Profil ueber die Namenssuche auffindbar; isPrivate steuert, ob Anfragen
  /// bestaetigt werden muessen.
  Future<void> setVisibility({bool? searchable, bool? isPrivate, String? username}) async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return;
    final body = <String, dynamic>{'userId': uid};
    if (searchable != null) body['searchable'] = searchable;
    if (isPrivate != null) body['isPrivate'] = isPrivate;
    if (username != null) body['username'] = username.trim().toLowerCase();
    try {
      await api.postJsonAny('/api/profile', body);
    } catch (e) {
      debugPrint('UserProfileService.setVisibility failed: $e');
    }
  }
}
