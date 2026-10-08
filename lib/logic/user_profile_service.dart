import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/profile_account_store.dart';

/// Die eine Identitaet: uid -> Anzeigename (app-weit). Der Name wird EINMAL
/// bei der Registrierung gesetzt und ueberall automatisch verwendet.
/// username/searchable/isPrivate sind optional (Default: privat, nicht
/// auffindbar) und werden erst in Schritt 2 (Suche) relevant.
class UserProfileService {
  UserProfileService({BackendApiClient? api, ProfileAccountStore? store,
      String? Function()? userIdProvider})
      : _api = api ?? BackendServiceFactory.createApiClient(),
        _store = store ?? ProfileAccountStore.instance,
        _userIdProvider = userIdProvider ??
            (() => FirebaseAuth.instance.currentUser?.uid);
  static final UserProfileService instance = UserProfileService();

  final BackendApiClient? _api;
  final ProfileAccountStore _store;
  final String? Function() _userIdProvider;
  String? get _uid => _userIdProvider();

  static String? resolveAvatarUrl(String? photoUrl, {String? apiBaseUrl}) {
    final value = photoUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return uri.scheme == 'https' || uri.scheme == 'http' ? value : null;
    }
    if (!value.startsWith('/') || value.startsWith('//')) return null;
    final base = Uri.tryParse(apiBaseUrl ??
        APIConfig.getBackendBaseUrl() ??
        'https://parentpeak.onrender.com');
    if (base == null || base.scheme != 'https' || base.host.isEmpty) return null;
    return base.resolve(value).toString();
  }

  /// Anzeigename serverseitig setzen/aktualisieren (app-weit gueltig).
  Future<void> setDisplayName(String displayName, {ProfileAccountTicket? ticket}) async {
    final store = _store;
    final expected = ticket ?? store.ticket;
    store.require(expected);
    final api = _api;
    final uid = _uid;
    final name = displayName.trim();
    if (api == null || uid == null || uid.isEmpty || name.isEmpty) {
      throw StateError('Profile identity or backend missing');
    }
      store.require(expected);
      await api.withRequestGuard(() => store.require(expected)).postJsonAny('/api/profile', {
        'userId': uid,
        'displayName': name,
      });
      store.require(expected);
  }

  Future<String?> avatarUrlFor(String uid) async {
    final api = _api;
    if (api == null || uid.isEmpty) return null;
    try {
      final data = await api.getJson('/api/profile/$uid');
      if (data is Map<String, dynamic> && data['exists'] == true) {
        return resolveAvatarUrl(data['avatarUrl']?.toString());
      }
    } catch (e) {
      debugPrint('UserProfileService.avatarUrlFor failed: $e');
    }
    return null;
  }

  Future<bool> setAvatarUrl(String? avatarUrl) async {
    final store = _store;
    final ticket = store.ticket;
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return false;
    try {
      store.require(ticket);
      await api.withRequestGuard(() => store.require(ticket)).postJsonAny('/api/profile', {
        'userId': uid,
        'avatarUrl': avatarUrl ?? '',
      });
      store.require(ticket);
      return true;
    } catch (e) {
      debugPrint('UserProfileService.setAvatarUrl failed: $e');
      return false;
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
  Future<void> setVisibility(
      {bool? searchable, bool? isPrivate, String? username}) async {
    final store = _store;
    final ticket = store.ticket;
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) {
      throw StateError('Profile identity or backend missing');
    }
    final body = <String, dynamic>{'userId': uid};
    if (searchable != null) body['searchable'] = searchable;
    if (isPrivate != null) body['isPrivate'] = isPrivate;
    if (username != null) body['username'] = username.trim().toLowerCase();
      store.require(ticket);
      await api.withRequestGuard(() => store.require(ticket)).postJsonAny('/api/profile', body);
      store.require(ticket);
  }
}
