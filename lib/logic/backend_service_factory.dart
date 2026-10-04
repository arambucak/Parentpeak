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

/// Waits for the Firebase session to restore before returning the ID token.
/// On web, [FirebaseAuth.currentUser] is null for ~500ms after init while
/// the session is restored from IndexedDB — requests in that window get 401.
Future<String?> _getFirebaseIdToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    try {
      user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          // Etwas großzügiger als bisher (2s): auf Web dauert der Session-
          // Restore aus IndexedDB gelegentlich länger.
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
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
/// wiederholen — ohne jeden normalen Call zu verlangsamen.
Future<String?> _forceRefreshFirebaseIdToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  try {
    return await user.getIdToken(true);
  } catch (_) {
    return null;
  }
}

class BackendServiceFactory {
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
