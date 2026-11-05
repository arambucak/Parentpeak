import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/services/feature_quota_service.dart';

BackendApiClient disabledQuotaClient() => BackendApiClient(
      baseUrl: 'https://quota.example.test',
      authToken: 'synthetic-test-token',
      httpClient: MockClient((request) async {
        if (request.url.path != '/usage/me') {
          throw StateError('Unexpected quota request: ${request.url.path}');
        }
        return http.Response(
            jsonEncode({
              'enabled': false,
              'tier': 'free',
              'serverTime': '2026-11-05T12:00:00Z',
              'items': {},
            }),
            200);
      }),
    );

void disableQuotasForTest() {
  FeatureQuotaService.apiClientFactory = disabledQuotaClient;
}

void exhaustChatQuotaForTest() {
  FeatureQuotaService.apiClientFactory = () => BackendApiClient(
        baseUrl: 'https://quota.example.test',
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'enabled': true,
              'tier': 'free',
              'serverTime': '2026-11-05T12:00:00Z',
              'items': {
                'chat': {'remaining': 0}
              },
            }),
            200)),
      );
}
