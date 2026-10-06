import 'package:parentpeak/logic/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeAiConsentRequiredException implements Exception {
  const RecipeAiConsentRequiredException();

  @override
  String toString() => 'AI recipe consent is required for the current account.';
}

class FamilyRecipeConsent {
  FamilyRecipeConsent({String Function()? scopeProvider})
      : _scopeProvider = scopeProvider ?? _currentScope;

  static final instance = FamilyRecipeConsent();
  final String Function() _scopeProvider;

  static String _currentScope() {
    final uid = AuthService.instance.currentUser?.uid;
    return uid == null ? 'guest' : 'account.${Uri.encodeComponent(uid)}';
  }

  String get scope => _scopeProvider();
  String _key(String scope) => 'familykueche.ai_recipe_consent.v1.$scope';

  Future<bool> hasConsent() async {
    final requestedScope = scope;
    final prefs = await SharedPreferences.getInstance();
    return scope == requestedScope &&
        prefs.getBool(_key(requestedScope)) == true;
  }

  Future<void> grant(String requestedScope) async {
    final prefs = await SharedPreferences.getInstance();
    if (scope != requestedScope) {
      throw const RecipeAiConsentRequiredException();
    }
    if (!await prefs.setBool(_key(requestedScope), true)) {
      throw StateError('Could not persist AI recipe consent.');
    }
    if (scope != requestedScope) {
      throw const RecipeAiConsentRequiredException();
    }
  }

  Future<void> require(String contextScope) async {
    if (scope != contextScope || !await hasConsent() || scope != contextScope) {
      throw const RecipeAiConsentRequiredException();
    }
  }
}
