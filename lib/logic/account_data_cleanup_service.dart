import 'package:parentpeak/config/api_config.dart';

import 'backend_api_client.dart';
import 'backend_service_factory.dart';

class AccountDataCleanupService {
  AccountDataCleanupService({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _apiClient;
  String? lastError;

  bool get isEnabled => _apiClient != null;

  Future<bool> deleteAccountData({required String userId}) async {
    final apiClient = _apiClient;
    if (apiClient == null) {
      // No backend configured: keep existing local/Firebase deletion path.
      return true;
    }

    try {
      await apiClient.postJsonAny(
        APIConfig.getBackendAccountDeleteDataPath(),
        <String, dynamic>{'userId': userId},
      );
      await apiClient.delete('/api/account/$userId');
      return true;
    } catch (e) {
      lastError = 'Backend-Daten konnten nicht geloescht werden: $e';
      return false;
    }
  }
}
