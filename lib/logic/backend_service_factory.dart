import 'package:parentpeak/config/api_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend_api_client.dart';
import 'calendar_backend_service.dart';
import 'finance_storage_service.dart';
import 'kettenbrecher_backend_service.dart';
import 'next_gen_food_feed_backend_service.dart';
import 'parent_matching_backend_service.dart';
import 'photo_backend_service.dart';
import 'shopping_backend_service.dart';
import 'todo_backend_service.dart';
import 'weekly_planner_storage_service.dart';
import 'weekly_impulse_service.dart';

/// Wartet, bis die Firebase-Session wiederhergestellt ist, und liefert den
/// aktuellen eingeloggten Nutzer — oder null, wenn niemand eingeloggt ist.
/// Auf Web ist [FirebaseAuth.currentUser] für ~500ms+ nach dem Init null,
/// während die Session aus IndexedDB restored wird. Anfragen in diesem Fenster
/// würden sonst ohne Token laufen und 401 bekommen.
Future<User?> _awaitRestoredUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) return user;
  try {
    return await FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((u) => u != null)
        // Auf Web dauert der Session-Restore aus IndexedDB gelegentlich länger;
        // auf Mobil ist der Nutzer sofort da, der Timeout greift dort nie.
        .timeout(const Duration(seconds: 6));
  } catch (_) {
    return null;
  }
}

/// Liefert den (ggf. gecachten) Firebase-ID-Token. Wartet bei Bedarf auf den
/// Session-Restore (Web).
Future<String?> _getFirebaseIdToken() async {
  final user = await _awaitRestoredUser();
  if (user != null) {
    // getIdToken() OHNE Force-Refresh: Firebase gibt den gecachten Token zurück
    // und erneuert ihn automatisch, wenn er bald abläuft. Ein erzwungener
    // Refresh bei JEDEM Call verursacht einen langsamen Netzwerk-Roundtrip —
    // auf Mobilfunk kann das zusammen mit dem KI-Call ins Timeout laufen und den
    // Feed scheitern lassen. Abgelaufene Token werden stattdessen gezielt per
    // 401-Retry im BackendApiClient erneuert.
    try {
      return await user.getIdToken();
    } catch (_) {}
  }
  // Fallback: return null so BackendApiClient uses static authToken
  return null;
}

/// Erzwingt einen frischen Firebase-ID-Token (Force-Refresh). Wird vom
/// BackendApiClient genutzt, um nach einem 401 einmal mit frischem Token zu
/// wiederholen — ohne jeden normalen Call zu verlangsamen. Wartet (wie der
/// normale Abruf) auf den Session-Restore, damit der 401-Retry auf Web eine
/// noch ladende Session nicht verpasst.
Future<String?> _forceRefreshFirebaseIdToken() async {
  final user = await _awaitRestoredUser();
  if (user == null) return null;
  try {
    return await user.getIdToken(true);
  } catch (_) {
    return null;
  }
}

class BackendServiceFactory {
  static BackendApiClient? createVerifiedApiClient() {
    final baseUrl = APIConfig.getBackendBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return null;
    return BackendApiClient(
      baseUrl: baseUrl,
      authTokenProvider: _getFirebaseIdToken,
      forceRefreshTokenProvider: _forceRefreshFirebaseIdToken,
      requireAuthToken: true,
    );
  }

  static BackendApiClient? createApiClient() {
    final baseUrl = APIConfig.getBackendBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }

    return BackendApiClient(
      baseUrl: baseUrl,
      authToken: APIConfig.getBackendApiToken(),
      authTokenProvider: _getFirebaseIdToken,
      forceRefreshTokenProvider: _forceRefreshFirebaseIdToken,
    );
  }

  static TodoBackendService createTodoService() {
    return TodoBackendService(apiClient: createApiClient());
  }

  static ShoppingBackendService createShoppingService() {
    return ShoppingBackendService(apiClient: createApiClient());
  }

  static CalendarBackendService createCalendarService() {
    return CalendarBackendService(apiClient: createApiClient());
  }

  static WeeklyImpulseService createWeeklyImpulseService() {
    return WeeklyImpulseService(apiClient: createApiClient());
  }

  static PhotoBackendService createPhotoService() {
    return PhotoBackendService(apiClient: createApiClient());
  }

  static ParentMatchingBackendService createParentMatchingService() {
    return ParentMatchingBackendService(apiClient: createApiClient());
  }

  static WeeklyPlannerStorageService createWeeklyPlannerStorageService() {
    return WeeklyPlannerStorageService(apiClient: createApiClient());
  }

  static FinanceStorageService createFinanceStorageService() {
    return FinanceStorageService(apiClient: createApiClient());
  }

  static KettenbrecherBackendService createKettenbrecherBackendService() {
    return KettenbrecherBackendService(apiClient: createApiClient());
  }

  static NextGenFoodFeedBackendService createNextGenFoodFeedBackendService() {
    return NextGenFoodFeedBackendService(apiClient: createApiClient());
  }
}
