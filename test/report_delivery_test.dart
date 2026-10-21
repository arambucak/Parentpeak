import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/services/block_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languages = ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  BlockReportService serviceFor(BackendApiClient api) => BlockReportService(
        api: api,
        userIdProvider: () => 'reporter',
      );

  Future<bool> send(BlockReportService service) => service.reportContent(
        reporterUserId: 'reporter',
        reportedUserId: 'reported',
        contentType: 'profile',
        content: 'Spam report',
        reason: 'spam',
      );

  test('server acceptance is required before recording a delivered report',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/safety/report');
      expect(request.headers['Authorization'], 'Bearer unit-test-token');
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final service = serviceFor(BackendApiClient(
      baseUrl: 'https://backend.example',
      authTokenProvider: () async => 'unit-test-token',
      requireAuthToken: true,
      httpClient: client,
    ));
    expect(await send(service), isTrue);
    expect(service.getReportCount('reported'), 1);
  });

  for (final failure in ['server', 'network', 'token']) {
    test('$failure failure never signals successful delivery', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        if (failure == 'network') throw http.ClientException('offline');
        return http.Response('{}', 503);
      });
      addTearDown(client.close);
      final service = serviceFor(BackendApiClient(
        baseUrl: 'https://backend.example',
        authTokenProvider: () async {
          if (failure == 'token') throw StateError('token unavailable');
          return 'unit-test-token';
        },
        requireAuthToken: true,
        httpClient: client,
      ));
      expect(await send(service), isFalse);
      expect(service.getReportCount('reported'), 0);
      expect(requests, failure == 'token' ? 0 : 1);
    });
  }

  test('401 with rejected refreshed token also reports delivery failure',
      () async {
    var refreshes = 0;
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 401);
    });
    addTearDown(client.close);
    final service = serviceFor(BackendApiClient(
      baseUrl: 'https://backend.example',
      authTokenProvider: () async => 'unit-test-token',
      forceRefreshTokenProvider: () async {
        refreshes++;
        return 'refreshed-unit-test-token';
      },
      requireAuthToken: true,
      httpClient: client,
    ));
    expect(await send(service), isFalse);
    expect(requests, 2);
    expect(refreshes, 1);
    expect(service.getReportCount('reported'), 0);
  });

  test('event reports use the same server delivery result', () async {
    final client = MockClient((_) async => http.Response('{}', 503));
    addTearDown(client.close);
    final service = serviceFor(BackendApiClient(
      baseUrl: 'https://backend.example',
      authTokenProvider: () async => 'unit-test-token',
      requireAuthToken: true,
      httpClient: client,
    ));
    expect(
        await service.reportEvent(
          eventId: 'event',
          eventTitle: 'Picnic',
          reason: 'spam',
        ),
        isFalse);
    expect(service.getReportCount('ai_event:event'), 0);
  });

  test('delivery feedback is explicit in all eight launch languages', () {
    for (final language in _languages) {
      for (final key in [
        'report_delivery_success',
        'report_delivery_failed',
        'request_failed_retry',
      ]) {
        final value = AppStringsManager.allStrings[language]![key];
        expect(value, isNotNull, reason: '$language:$key');
        expect(value!.trim(), isNotEmpty, reason: '$language:$key');
        if (language != 'en') {
          expect(value, isNot(AppStringsManager.allStrings['en']![key]),
              reason: '$language:$key must not fall back to English');
        }
      }
    }
  });

  for (final language in _languages) {
    for (final outcome in ['delivered', 'server failure', 'token failure']) {
      testWidgets(
          '$language: report UI only confirms accepted delivery ($outcome)',
          (tester) async {
        final delivered = outcome == 'delivered';
        final client =
            MockClient((_) async => http.Response('{}', delivered ? 200 : 503));
        addTearDown(client.close);
        final service = serviceFor(BackendApiClient(
          baseUrl: 'https://backend.example',
          authTokenProvider: () async {
            if (outcome == 'token failure') {
              throw StateError('token unavailable');
            }
            return 'unit-test-token';
          },
          requireAuthToken: true,
          httpClient: client,
        ));
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        onPressed: () => showReportSheet(
                          context,
                          userId: 'reported',
                          userName: 'Reported profile',
                          contentType: 'profile',
                          reportService: service,
                        ),
                        child: const Text('open report'),
                      ))),
        ));
        await tester.tap(find.text('open report'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Spam / Werbung'));
        await tester.pumpAndSettle();
        final strings = AppStringsManager.allStrings[language]!;
        expect(
            find.text(strings[delivered
                ? 'report_delivery_success'
                : 'report_delivery_failed']!),
            findsOneWidget);
        expect(
            find.text(strings[delivered
                ? 'report_delivery_failed'
                : 'report_delivery_success']!),
            findsNothing);
        expect(find.byIcon(Icons.check_circle_rounded),
            delivered ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.info_outline_rounded),
            delivered ? findsNothing : findsOneWidget);
        expect(service.getReportCount('reported'), delivered ? 1 : 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
