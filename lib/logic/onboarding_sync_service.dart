import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

/// Onboarding Minimal-Sync (Option A): synchronisiert NUR den Abschluss-Status
/// und unkritische Stammdaten (Familienname, Rolle, Prioritaeten) account-
/// gebunden. So muss der Nutzer auf einem neuen Geraet nicht erneut durchs
/// Onboarding. Sensible Kinderdaten bleiben ausschliesslich lokal.
class OnboardingSyncService {
  OnboardingSyncService._();
  static final OnboardingSyncService instance = OnboardingSyncService._();

  final BackendApiClient? _api = BackendServiceFactory.createApiClient();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Nach Abschluss: unkritische Stammdaten zum Server pushen (best-effort).
  Future<void> pushCompleted() async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await api.postJsonAny('/api/onboarding', {
        'userId': uid,
        'completed': true,
        'familyName': prefs.getString('onboarding.family_name') ?? '',
        'parentRole': prefs.getString('onboarding.parent_role') ?? '',
        'priorities': prefs.getStringList('onboarding.priorities') ?? <String>[],
      });
    } catch (e) {
      debugPrint('OnboardingSyncService.pushCompleted failed: $e');
    }
  }

  /// Beim Login/Start: Server-Status holen. Gibt true zurueck, wenn der Nutzer
  /// das Onboarding (auf irgendeinem Geraet) bereits abgeschlossen hat, und
  /// spiegelt den Zustand + Stammdaten lokal, damit die App direkt startet.
  /// Best-effort: bei Fehler false -> lokaler Zustand bleibt massgeblich.
  Future<bool> pullCompleted() async {
    final api = _api;
    final uid = _uid;
    if (api == null || uid == null || uid.isEmpty) return false;
    try {
      final data = await api.getJson('/api/onboarding/$uid');
      if (data is Map<String, dynamic> && data['completed'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding.completed', true);
        final familyName = (data['familyName'] as String?)?.trim() ?? '';
        if (familyName.isNotEmpty) {
          await prefs.setString('onboarding.family_name', familyName);
        }
        final parentRole = (data['parentRole'] as String?)?.trim() ?? '';
        if (parentRole.isNotEmpty) {
          await prefs.setString('onboarding.parent_role', parentRole);
        }
        final priorities = (data['priorities'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            <String>[];
        if (priorities.isNotEmpty) {
          await prefs.setStringList('onboarding.priorities', priorities);
        }
        return true;
      }
    } catch (e) {
      debugPrint('OnboardingSyncService.pullCompleted failed: $e');
    }
    return false;
  }
}
