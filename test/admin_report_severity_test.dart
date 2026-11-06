import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/admin_moderation_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/ui/admin_moderation_screen.dart';

void main() {
  test('severity uses the server field, not user-supplied content', () {
    expect(ReportGroup.fromJson({'severity': 'critical'}).severity, 'critical');
    expect(ReportGroup.fromJson({'severity': 'normal'}).severity, 'normal');
    expect(ReportDetail.fromJson({'reason': 'self_harm'}).severity, 'normal');
    expect(
        ReportDetail.fromJson({'severity': 'critical'}).severity, 'critical');
  });

  for (final language in ['de', 'ar']) {
    testWidgets('$language: dashboard prioritizes and marks critical reports',
        (tester) async {
      final client = MockClient((request) async {
        expect(request.url.path, '/admin/reports');
        return http.Response(
            jsonEncode({
              'groups': [
                {
                  'reportedUserId': 'ordinary',
                  'reportCount': 1,
                  'lastReason': 'spam',
                  'severity': 'normal'
                },
                {
                  'reportedUserId': 'urgent',
                  'reportCount': 1,
                  'lastReason': 'self_harm',
                  'severity': 'critical'
                },
              ],
              'reports': [
                {
                  'id': 'r1',
                  'reportedUserId': 'urgent',
                  'reason': 'self_harm',
                  'severity': 'critical'
                },
              ],
            }),
            200);
      });
      addTearDown(client.close);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: AdminModerationScreen(
          service: AdminModerationService(
              apiClient: BackendApiClient(
                  baseUrl: 'https://test.example', httpClient: client)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
          find.text(AppStringsManager.getString(
              language, 'report_severity_critical')),
          findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      final urgent = find.textContaining('urgent').first;
      final normal = find.textContaining('ordinary').first;
      expect(
          tester.getTopLeft(urgent).dy, lessThan(tester.getTopLeft(normal).dy));
      expect(tester.takeException(), isNull);
    });
  }
}
