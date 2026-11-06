import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/crisis_support.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/report_reasons.dart';
import 'package:parentpeak/services/block_report_service.dart';
import 'package:parentpeak/ui/widgets/content_report_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(String language, Widget home) => MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: const [
        AppLanguages.materialLocalizationsDelegate,
        AppLanguages.widgetsLocalizationsDelegate,
        AppLanguages.cupertinoLocalizationsDelegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Scaffold(body: home),
    );

Future<void> choose(WidgetTester tester, String reason) async {
  final option = find.byKey(ValueKey('report-reason-$reason'));
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  final submit = find.byKey(const ValueKey('report-submit'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the canonical set is exact and legacy labels stay readable', () {
    expect(ReportReasons.keys, [
      'child_safety',
      'sexual_content',
      'violence_threat',
      'self_harm',
      'harassment',
      'spam',
      'fraud',
      'inappropriate',
      'misinformation',
      'other',
    ]);
    expect(ReportReasons.canonical('insult'), 'harassment');
    expect(ReportReasons.canonical('fake'), 'fraud');
    expect(ReportReasons.canonical('false_info'), 'misinformation');
    expect(ReportReasons.canonical('hostile'), 'harassment');
    expect(ReportReasons.canonical('unsafe'), 'inappropriate');
    expect(ReportReasons.canonical('expired'), 'expired');
  });

  for (final language in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
    for (final reason in ReportReasons.keys) {
      testWidgets('$language: selects and submits canonical $reason',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? sent;
        final client = MockClient((request) async {
          expect(request.url.path, '/api/safety/report');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"ok":true}', 200);
        });
        addTearDown(client.close);
        final service = BlockReportService(
          api: BackendApiClient(
              baseUrl: 'https://test.example', httpClient: client),
          userIdProvider: () => 'reporter',
        );
        await tester.pumpWidget(app(
          language,
          Builder(
              builder: (context) => TextButton(
                    onPressed: () => showReportSheet(context,
                        userId: 'target',
                        userName: 'Family',
                        contentType: 'profile',
                        reportService: service),
                    child: const Text('open'),
                  )),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(RadioListTile<String>), findsNWidgets(10));
        expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(4));
        for (final key in ReportReasons.keys) {
          expect(
              find.text(
                  AppStringsManager.getString(language, 'report_reason_$key')),
              findsOneWidget);
        }
        expect(
            Directionality.of(tester.element(find.byType(ContentReportForm))),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        await choose(tester, reason);
        expect(sent?['reason'], reason);
        expect(sent?['severity'], isNull);
        expect(service.getReportCount('target'), 1);
        if (reason == 'self_harm') {
          expect(
              find.text(
                  AppStringsManager.getString(language, 'report_help_title')),
              findsOneWidget);
          expect(
              find.text(CrisisSupport.crisisResponse(
                  languageCode: language, countryCode: 'DE')),
              findsOneWidget);
        } else {
          expect(find.byType(SelectableText), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final success in [true, false]) {
      testWidgets(
          '$language: help does not wait for or depend on delivery $success',
          (tester) async {
        final pending = Completer<bool>();
        Future<bool>? delivered;
        var sends = 0;
        await tester.pumpWidget(app(
          language,
          Builder(
              builder: (context) => TextButton(
                    onPressed: () {
                      delivered = deliverContentReport(
                        context,
                        reason: 'self_harm',
                        countryProvider: () async => 'AT',
                        send: () {
                          sends++;
                          return pending.future;
                        },
                      );
                    },
                    child: const Text('send'),
                  )),
        ));
        await tester.tap(find.text('send'));
        await tester.pumpAndSettle();
        expect(sends, 1);
        expect(pending.isCompleted, isFalse);
        expect(
            find.text(CrisisSupport.crisisResponse(
                languageCode: language, countryCode: 'AT')),
            findsOneWidget);
        pending.complete(success);
        await tester.pumpAndSettle();
        expect(await delivered, success);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('report help reads the current account country and defaults to DE',
      () async {
    expect(await reportCountryCode(), 'DE');
    SharedPreferences.setMockInitialValues({
      ProfileAccountStore.storageKey: jsonEncode({
        'version': 1,
        'legacyOwners': <String, dynamic>{},
        'accounts': {
          'guest': {
            'owner': 'guest',
            'data': {ProfileAccountStore.countryKey: 'CH'},
          }
        },
      }),
    });
    expect(await reportCountryCode(), 'CH');
  });

  testWidgets('changing accounts while choosing never reports for the new user',
      (tester) async {
    var uid = 'first';
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{"ok":true}', 200);
    });
    addTearDown(client.close);
    final service = BlockReportService(
      api:
          BackendApiClient(baseUrl: 'https://test.example', httpClient: client),
      userIdProvider: () => uid,
    );
    await tester.pumpWidget(app(
      'en',
      Builder(
          builder: (context) => TextButton(
                onPressed: () => showReportSheet(context,
                    userId: 'target',
                    userName: 'Family',
                    contentType: 'profile',
                    reportService: service),
                child: const Text('open'),
              )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    uid = 'second';
    await choose(tester, 'spam');
    expect(requests, 0);
    expect(
        find.text(AppStringsManager.getString('en', 'report_delivery_failed')),
        findsOneWidget);
  });
}
