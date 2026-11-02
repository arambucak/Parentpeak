import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);

Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );

Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

Future<void> _next(WidgetTester tester) async {
  await tester
      .tap(find.widgetWithIcon(FilledButton, Icons.arrow_forward_rounded));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.widgetWithIcon(TextButton, Icons.arrow_back_rounded));
  await tester.pumpAndSettle();
}

Future<void> _submitAndConfirm(
  WidgetTester tester, {
  bool suspended = false,
}) async {
  await tester.tap(
    find.widgetWithText(FilledButton, _t('network_copy_create_profile')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester
      .tap(find.widgetWithText(FilledButton, _t('network_publish_accept')));
  if (suspended) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  for (final (status, key, suspended) in [
    (400, 'network_publish_invalid', false),
    (401, 'network_publish_unauthenticated', false),
    (403, 'account_suspended_message', true),
    (503, 'network_publish_server_unavailable', false),
  ]) {
    testWidgets('wizard inputs survive HTTP $status in the real screen', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => languageService.setLanguage('de'));
      await tester
          .runAsync(() => AuthService.instance.debugSeedSessionForTesting());
      final userId = AuthService.instance.currentUser!.uid;
      final oldFactory = AuthService.backendApiClientFactory;
      addTearDown(() async {
        AuthService.backendApiClientFactory = () => null;
        try {
          await AuthService.instance.logout();
        } finally {
          AuthService.backendApiClientFactory = oldFactory;
        }
      });

      final requests = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response('{}', 404);
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({
              'error': 'synthetic-private-response',
              'code': suspended ? 'account_suspended' : 'example',
            }),
            status);
      });
      addTearDown(client.close);
      final matching = ParentMatchingBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          authToken: 'synthetic-token',
          httpClient: client,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: const [Locale('de'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ElternNetzwerkScreen(initialTab: 2, matchingService: matching),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlaymateProfileForm), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(PlaymateProfileForm)))
          .clearSnackBars();
      await tester.pumpAndSettle();

      await tester.enterText(
        _fieldWithLabel(_t('network_copy_name_hint')),
        'Test family',
      );
      tester
          .widget<LocationPickerWidget>(find.byType(LocationPickerWidget))
          .onLocationPicked(
            const PickedLocation(
              displayName: 'Berlin',
              city: 'Berlin',
              postcode: '',
              lat: 52.52,
              lon: 13.40,
            ),
          );
      await tester.pump();
      await _next(tester);
      await tester.enterText(
        _fieldWithLabel(_t('network_child_name_local')),
        'Local child',
      );
      tester.widget<Slider>(find.byType(Slider).first).onChanged!(36);
      await tester.pump();
      await _next(tester);
      await _next(tester);
      await _next(tester);
      await tester.enterText(
          _fieldWithHint(_t('network_copy_bio_hint')), 'Test bio');

      ScaffoldMessenger.of(tester.element(find.byType(PlaymateProfileForm)))
          .clearSnackBars();
      await _submitAndConfirm(tester, suspended: suspended);
      expect(requests, hasLength(1));
      expect(requests.single['name'], 'Test family');
      expect(requests.single['city'], 'Berlin');
      expect(requests.single['childAges'], ['3J']);
      expect(requests.single['languages'], contains('de'));
      expect(requests.single['bio'], 'Test bio');
      expect(find.text(_t(key)), findsOneWidget);
      expect(find.textContaining('HTTP $status'), findsOneWidget);
      expect(find.textContaining('synthetic-private-response'), findsNothing);
      expect(find.textContaining('synthetic-token'), findsNothing);
      expect(find.byType(PlaymateProfileForm), findsOneWidget);
      expect(AuthService.instance.currentUser?.uid, userId);

      if (suspended) {
        await tester.tap(find.text(_t('common_understood')));
      } else {
        ScaffoldMessenger.of(tester.element(find.byType(PlaymateProfileForm)))
            .hideCurrentSnackBar();
      }
      await tester.pumpAndSettle();
      await _back(tester);
      await _back(tester);
      await _back(tester);
      expect(
        tester
            .widget<TextField>(_fieldWithLabel(_t('network_child_name_local')))
            .controller!
            .text,
        'Local child',
      );
      await _back(tester);
      expect(
        tester
            .widget<TextField>(_fieldWithLabel(_t('network_copy_name_hint')))
            .controller!
            .text,
        'Test family',
      );
      expect(find.text('Berlin'), findsWidgets);
      await _next(tester);
      await _next(tester);
      await _next(tester);
      await _next(tester);
      expect(
        tester
            .widget<TextField>(_fieldWithHint(_t('network_copy_bio_hint')))
            .controller!
            .text,
        'Test bio',
      );
      await _submitAndConfirm(tester, suspended: suspended);
      expect(requests, hasLength(2));
      expect(requests.last, requests.first);
      if (suspended) {
        await tester.tap(find.text(_t('common_understood')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
