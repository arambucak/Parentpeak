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

class BackendServiceFactory {
  static BackendApiClient? createApiClient() {
    final baseUrl = APIConfig.getBackendBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }

    return BackendApiClient(
      baseUrl: baseUrl,
      authToken: APIConfig.getBackendApiToken(),
      authTokenProvider: () async =>
          FirebaseAuth.instance.currentUser?.getIdToken(),
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
