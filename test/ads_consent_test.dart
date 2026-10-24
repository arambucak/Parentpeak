import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/ads_consent_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/entitlement_service.dart';
import 'package:parentpeak/ui/ads_consent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const revision1 = '00000000-0000-4000-8000-000000000001';
const revision2 = '00000000-0000-4000-8000-000000000002';

Map<String, dynamic> payload(
  String decision, {
  String version = AdsConsentService.version,
  String revision = revision1,
}) =>
    {
      'item': {
        'decision': decision,
        'consentVersion': version,
        'consentRevision': revision,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? owner;
  late String decision;
  late String revision;
  late bool fail;
  late List<http.Request> requests;
  late AdsConsentService service;
  late ChangeNotifier accounts;
  Completer<void>? writeGate;

  BackendApiClient client() => BackendApiClient(
        baseUrl: 'https://backend.example.test',
        authTokenProvider: () async => 'test-token',
        requireAuthToken: true,
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.url.path, AdsConsentService.path);
          expect(request.url.query, isEmpty);
          if (fail) return http.Response('{}', 503);
          if (request.method == 'PUT') {
            await writeGate?.future;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.keys.toSet(), {
              'decision',
              'consentVersion',
              'consentRevision',
            });
            decision = body['decision'] as String;
            revision = revision2;
          }
          return http.Response(
              jsonEncode(payload(decision, revision: revision)), 200);
        }),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    owner = 'account-a';
    decision = 'unknown';
    revision = revision1;
    fail = false;
    requests = [];
    writeGate = null;
    accounts = ChangeNotifier();
    service = AdsConsentService(
      ownerProvider: () => owner,
      apiClientFactory: client,
      accountChanges: accounts,
    );
  });
  tearDown(() {
    service.dispose();
    accounts.dispose();
  });

  Future<void> settleNetwork(WidgetTester tester) async {
    for (var turn = 0;
        turn < 100 && service.snapshot.state == AdsConsentState.loading;
        turn++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(service.snapshot.state, isNot(AdsConsentState.loading));
    await tester.pumpAndSettle();
  }

  test('default is no consent; grant and denial sync to second client',
      () async {
    expect(service.snapshot.isGranted, isFalse);
    await service.refresh();
    expect(service.snapshot.decision, AdsConsentDecision.unknown);
    await service.decide(AdsConsentDecision.granted);
    expect(service.snapshot.isGranted, isTrue);
    final second = AdsConsentService(
      ownerProvider: () => owner,
      apiClientFactory: client,
    );
    addTearDown(second.dispose);
    await second.refresh();
    expect(second.snapshot.isGranted, isTrue);
    await service.decide(AdsConsentDecision.denied);
    expect(service.snapshot.isGranted, isFalse);
    await second.refresh();
    expect(second.snapshot.decision, AdsConsentDecision.denied);
    expect(requests.every((r) => r.url.path == AdsConsentService.path), isTrue);
  });

  test('withdrawal blocks synchronously before the server write completes',
      () async {
    decision = 'granted';
    await service.refresh();
    expect(service.snapshot.isGranted, isTrue);
    writeGate = Completer<void>();
    final revoke = service.decide(AdsConsentDecision.denied);
    expect(service.snapshot.isGranted, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(service.snapshot.isGranted, isFalse);
    writeGate!.complete();
    await revoke;
    expect(service.snapshot.decision, AdsConsentDecision.denied);
  });

  test('offline withdrawal survives new instance and retries before any grant',
      () async {
    decision = 'granted';
    await service.refresh();
    fail = true;
    await expectLater(
        service.decide(AdsConsentDecision.denied), throwsException);
    expect(service.snapshot.state, AdsConsentState.unavailable);
    expect(service.snapshot.isGranted, isFalse);
    final restarted = AdsConsentService(
      ownerProvider: () => owner,
      apiClientFactory: client,
    );
    addTearDown(restarted.dispose);
    fail = false;
    await restarted.refresh();
    expect(restarted.snapshot.decision, AdsConsentDecision.denied);
    expect(decision, 'denied');
  });

  test('a simultaneous refresh cannot discard a queued withdrawal', () async {
    decision = 'granted';
    await service.refresh();
    final withdrawal = service.decide(AdsConsentDecision.denied);
    final failedWrite = expectLater(withdrawal, throwsStateError);
    final refresh = service.refresh();
    expect(service.snapshot.isGranted, isFalse);
    await failedWrite;
    await refresh;
    expect(service.snapshot.decision, AdsConsentDecision.denied);
    expect(decision, 'denied');
  });

  test('pending withdrawal must sync before another positive decision',
      () async {
    decision = 'granted';
    await service.refresh();
    fail = true;
    await expectLater(
        service.decide(AdsConsentDecision.denied), throwsException);
    fail = false;
    await expectLater(
        service.decide(AdsConsentDecision.granted), throwsStateError);
    expect(service.snapshot.isGranted, isFalse);
    await service.refresh();
    expect(decision, 'denied');
  });

  test('guest or absent identity cannot issue any consent request', () async {
    for (final value in [null, '', 'guest', ' a ']) {
      owner = value;
      await expectLater(service.refresh(), throwsStateError);
      await expectLater(
          service.decide(AdsConsentDecision.granted), throwsStateError);
      expect(service.snapshot.isGranted, isFalse);
    }
    expect(requests, isEmpty);
  });

  test('network, token and database errors stay unavailable, never granted',
      () async {
    decision = 'granted';
    await service.refresh();
    fail = true;
    await expectLater(service.refresh(), throwsException);
    expect(service.snapshot.state, AdsConsentState.unavailable);
    expect(service.snapshot.isGranted, isFalse);
    final noToken = AdsConsentService(
      ownerProvider: () => owner,
      apiClientFactory: () => BackendApiClient(
        baseUrl: 'https://backend.example.test',
        requireAuthToken: true,
        authTokenProvider: () async => null,
        httpClient: MockClient((_) async => throw StateError('must not send')),
      ),
    );
    addTearDown(noToken.dispose);
    await expectLater(noToken.refresh(), throwsStateError);
    expect(noToken.snapshot.isGranted, isFalse);
    final offline = AdsConsentService(
      ownerProvider: () => owner,
      apiClientFactory: () => BackendApiClient(
        baseUrl: 'https://backend.example.test',
        httpClient:
            MockClient((_) async => throw http.ClientException('offline')),
      ),
    );
    addTearDown(offline.dispose);
    await expectLater(offline.refresh(), throwsException);
    expect(offline.snapshot.isGranted, isFalse);
  });

  test(
      'account changes invalidate even same-account re-login and late responses',
      () async {
    decision = 'granted';
    await service.refresh();
    accounts.notifyListeners();
    expect(service.snapshot.isGranted, isFalse);
    await service.refresh();
    writeGate = Completer<void>();
    final write = service.decide(AdsConsentDecision.granted);
    final result = expectLater(write, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    owner = 'account-b';
    accounts.notifyListeners();
    writeGate!.complete();
    await result;
    expect(service.snapshot.isGranted, isFalse);
  });

  test('version mismatch, invalid metadata and disabled flags fail closed', () {
    expect(
        AdsConsentSnapshot.fromResponse(
          payload('granted', version: 'old'),
        ).isGranted,
        isFalse);
    expect(() => AdsConsentSnapshot.fromResponse(payload('invalid')),
        throwsFormatException);
    expect(
        () => AdsConsentSnapshot.fromResponse({
              'item': {
                'decision': 'granted',
                'consentVersion': AdsConsentService.version
              },
            }),
        throwsFormatException);
    final consent = AdsConsentSnapshot.fromResponse(payload('granted'));
    for (final entitlement in [
      const EntitlementSnapshot.loading(),
      const EntitlementSnapshot.unavailable(),
      const EntitlementSnapshot(
        state: EntitlementState.verified,
        tier: SubscriptionTier.premium,
      ),
      const EntitlementSnapshot(
        state: EntitlementState.verified,
        tier: SubscriptionTier.free,
        adsEligibleByEntitlement: true,
      ),
    ]) {
      for (final public in [true, false]) {
        expect(
            allowsSponsorProcessing(
              entitlement: entitlement,
              consent: consent,
              isPublicEventDiscovery: public,
            ),
            isFalse);
      }
    }
    expect(MonetizationConfig.enabled, isFalse);
    expect(MonetizationConfig.adsEnabled, isFalse);
  });

  const keys = [
    'ads_consent_title',
    'ads_consent_body',
    'ads_consent_grant',
    'ads_consent_deny',
    'ads_consent_revoke',
    'ads_consent_status_unknown',
    'ads_consent_status_denied',
    'ads_consent_status_granted',
    'ads_consent_status_unavailable',
    'ads_consent_version',
    'ads_consent_failed',
    'ads_consent_legal_draft',
  ];
  for (final code in ['de', 'en', 'tr', 'ku', 'fr', 'es', 'it', 'ar']) {
    test('$code strings are complete and preserve placeholders', () {
      for (final key in keys) {
        final text = AppStringsManager.allStrings[code]![key];
        expect(text, isNotNull, reason: '$code:$key');
        expect(text!.trim(), isNotEmpty);
        if (code != 'en') {
          expect(text, isNot(AppStringsManager.allStrings['en']![key]));
        }
      }
      expect(AppStringsManager.allStrings[code]!['ads_consent_version'],
          contains('{version}'));
    });

    testWidgets('$code consent dialog has equal choices, fits and respects RTL',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8),
          ),
          child: child!,
        ),
        home: AdsConsentScreen(service: service),
      ));
      await settleNetwork(tester);
      final button = find.byKey(const Key('ads-consent-grant'));
      await tester.scrollUntilVisible(button, 250);
      await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await settleNetwork(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.byType(OutlinedButton)),
          findsNWidgets(2));
      expect(Directionality.of(tester.element(dialog)),
          code == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(service.snapshot.isGranted, isFalse);
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    });
  }

  testWidgets('dialog grant, decline and direct withdrawal persist selections',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: AdsConsentScreen(service: service),
    ));
    await settleNetwork(tester);
    await tester.tap(find.byKey(const Key('ads-consent-grant')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester
        .tap(find.descendant(of: dialog, matching: find.text('Decline')));
    await settleNetwork(tester);
    expect(decision, 'denied');
    await tester.tap(find.byKey(const Key('ads-consent-grant')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: dialog, matching: find.text('Agree')));
    await settleNetwork(tester);
    expect(service.snapshot.isGranted, isTrue);
    await tester.tap(find.byKey(const Key('ads-consent-deny')));
    await settleNetwork(tester);
    expect(decision, 'denied');
  });

  testWidgets('declining still blocks after another device changes consent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: AdsConsentScreen(service: service),
    ));
    await settleNetwork(tester);
    await tester.tap(find.byKey(const Key('ads-consent-grant')));
    await tester.pumpAndSettle();
    decision = 'granted';
    revision = revision2;
    await tester.runAsync(service.refresh);
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Decline')));
    expect(service.snapshot.isGranted, isFalse);
    await settleNetwork(tester);
    expect(decision, 'denied');
  });

  testWidgets('a dialog cannot write consent for a different login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: AdsConsentScreen(service: service),
    ));
    await settleNetwork(tester);
    await tester.tap(find.byKey(const Key('ads-consent-grant')));
    await tester.pumpAndSettle();
    owner = 'account-b';
    accounts.notifyListeners();
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Decline')));
    await tester.pumpAndSettle();
    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
    expect(service.snapshot.isGranted, isFalse);
  });
}
