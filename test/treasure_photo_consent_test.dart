import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/logic/treasure_photo_analysis_service.dart';
import 'package:parentpeak/logic/treasure_photo_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/ui/treasure_upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Photo extends XFile {
  _Photo({this.onRead, String path = '/not-a-real-photo.jpg'}) : super(path);
  final Future<void> Function()? onRead;
  int reads = 0;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    await onRead?.call();
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _Picker extends ImagePicker {
  _Picker(this.photo);
  XFile photo;
  Future<XFile?> Function()? camera;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => camera == null ? photo : await camera!();

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [photo];
}

String _response({String title = 'Suggested bicycle'}) => jsonEncode({
  'text':
      '```json\n${jsonEncode({'title': title, 'description': 'Ready for another family.', 'category': 'vehicles', 'color': 'Blue', 'sizeAge': '3 years', 'condition': 'good'})}\n```',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String scope;
  late TreasurePhotoConsent consent;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  late TreasurePhotoAnalysisService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = 'account.photo-a';
    consent = TreasurePhotoConsent(scopeProvider: () => scope);
    requests = [];
    respond = (_) async => http.Response(_response(), 200);
    service = TreasurePhotoAnalysisService(
      consent: consent,
      aiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'audit-token',
          httpClient: MockClient((request) async {
            requests.add(request);
            return respond(request);
          }),
        ),
      ),
    );
  });

  Future<TreasurePhotoAnalysis> analyze(
    XFile photo, {
    String? expectedScope,
    String language = 'en',
    void Function()? guard,
  }) => service.analyze(
    photo,
    expectedScope: expectedScope ?? scope,
    languageCode: language,
    requireCurrentRequest: guard ?? () {},
  );

  test(
    'service blocks photo reads and HTTP without feature-specific consent',
    () async {
      final photo = _Photo();
      await FamilyRecipeConsent(scopeProvider: () => scope).grant(scope);
      await BenefitGuideConsent(scopeProvider: () => scope).grant(scope);
      await expectLater(
        analyze(photo),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(photo.reads, 0);
      expect(requests, isEmpty);
    },
  );

  test('versioned consent persists for only its originating account', () async {
    await consent.grant(scope);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('treasure.ai_photo_consent.v1.account.photo-a'),
      isTrue,
    );
    expect(
      await TreasurePhotoConsent(scopeProvider: () => scope).hasConsent(),
      isTrue,
    );
    scope = 'account.photo-b';
    expect(await consent.hasConsent(), isFalse);
    await consent.grant(scope);
    await expectLater(
      analyze(_Photo(), expectedScope: 'account.photo-a'),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    scope = 'guest';
    expect(await consent.hasConsent(), isFalse);
    expect(requests, isEmpty);
  });

  test('false and thrown consent writes do not enable analysis', () async {
    for (final throws in [false, true]) {
      final failed = TreasurePhotoConsent(
        scopeProvider: () => scope,
        persist: (_, __) async {
          if (throws) throw StateError('storage unavailable');
          return false;
        },
      );
      await expectLater(failed.grant(scope), throwsStateError);
      expect(await failed.hasConsent(), isFalse);
    }
    await expectLater(
      analyze(_Photo()),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'all four languages send photo bytes with JSON system instruction and no family context',
    () async {
      await consent.grant(scope);
      for (final entry in {
        'de': 'German',
        'en': 'English',
        'tr': 'Turkish',
        'ku': 'Kurmanji Kurdish',
      }.entries) {
        final result = await analyze(_Photo(), language: entry.key);
        expect(result.title, 'Suggested bicycle');
        final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
        expect(requests.last.url.path, '/ai/generate');
        expect(body['imageBase64'], 'AQID');
        expect(body['imageMimeType'], 'image/jpeg');
        expect(body['language'], entry.key);
        expect(body['systemInstruction'], contains(entry.value));
        expect(body['systemInstruction'], contains('Return only JSON'));
        expect(body.containsKey('childProfileId'), isFalse);
        expect(body['prompt'], isNot(contains('photo-a')));
        expect(body['useGoogleSearch'], isFalse);
      }
    },
  );

  test(
    'account change during photo read blocks HTTP even if new account has consent',
    () async {
      await consent.grant(scope);
      final photo = _Photo(
        onRead: () async {
          scope = 'account.photo-b';
          await consent.grant(scope);
        },
      );
      await expectLater(
        analyze(photo, expectedScope: 'account.photo-a'),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(photo.reads, 1);
      expect(requests, isEmpty);
    },
  );

  test(
    'stale request guard prevents sending and accepting responses',
    () async {
      await consent.grant(scope);
      var valid = true;
      void guard() {
        if (!valid) throw StateError('stale');
      }

      await expectLater(
        analyze(
          _Photo(
            onRead: () async {
              valid = false;
            },
          ),
          guard: guard,
        ),
        throwsStateError,
      );
      expect(requests, isEmpty);
      valid = true;
      respond = (_) async {
        valid = false;
        return http.Response(_response(), 200);
      };
      await expectLater(analyze(_Photo(), guard: guard), throwsStateError);
      expect(requests, hasLength(1));
    },
  );

  test('account change while HTTP is pending discards old result', () async {
    await consent.grant(scope);
    respond = (_) async {
      scope = 'account.photo-b';
      await consent.grant(scope);
      return http.Response(_response(), 200);
    };
    await expectLater(
      analyze(_Photo(), expectedScope: 'account.photo-a'),
      throwsA(isA<AccountAiConsentRequiredException>()),
    );
    expect(requests, hasLength(1));
  });

  test(
    'invalid analysis fields and unavailable AI are explicit failures',
    () async {
      await consent.grant(scope);
      for (final text in [
        'not JSON',
        '{"title":12}',
        '{"category":"unknown","condition":"good"}',
      ]) {
        respond = (_) async => http.Response(jsonEncode({'text': text}), 200);
        await expectLater(analyze(_Photo()), throwsFormatException);
      }
      respond = (_) async => http.Response('unavailable', 503);
      await expectLater(analyze(_Photo()), throwsException);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    _Picker picker, {
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: TreasureUploadScreen(
          imagePicker: picker,
          photoAnalysisService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> camera(
    WidgetTester tester, {
    String language = 'en',
    bool more = false,
  }) async {
    final label = AppLocalizations(
      Locale(language),
    ).t(more ? 'treasureAddMorePhotos' : 'treasureTakePhoto');
    await tester.scrollUntilVisible(
      find.text(label),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'four-language camera consent may be declined while keeping photo and manual editing',
    (tester) async {
      for (final language in ['de', 'en', 'tr', 'ku']) {
        await tester.pumpWidget(const SizedBox.shrink());
        final photo = _Photo();
        await mount(tester, _Picker(photo), language: language);
        await camera(tester, language: language);
        expect(
          find.text(
            AppStringsManager.getString(
              language,
              'treasure_photo_consent_title',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            AppStringsManager.getString(
              language,
              'treasure_photo_consent_body',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(
            TextButton,
            AppStringsManager.getString(language, 'cancel'),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(photo.reads, 0);
        expect(await consent.hasConsent(), isFalse);
        expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(TextField).first,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField).first, 'Manual item');
        expect(find.text('Manual item'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'camera acceptance sends once; later camera skips dialog; gallery stays local',
    (tester) async {
      final picker = _Picker(_Photo());
      await mount(tester, picker);
      await tester.tap(
        find.text(
          AppLocalizations(const Locale('en')).t('treasureChooseFromLibrary'),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      await camera(tester, more: true);
      await tester.tap(find.text('Agree and analyse photo'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(await consent.hasConsent(), isTrue);
      picker.photo = _Photo(path: '/second-photo.jpg');
      await camera(tester, more: true);
      expect(find.byType(AlertDialog), findsNothing);
      expect(requests, hasLength(2));
    },
  );

  testWidgets('failed consent persistence is visible and sends no photo', (
    tester,
  ) async {
    consent = TreasurePhotoConsent(
      scopeProvider: () => scope,
      persist: (_, __) async => false,
    );
    service = TreasurePhotoAnalysisService(consent: consent);
    final photo = _Photo();
    await mount(tester, _Picker(photo));
    await camera(tester);
    await tester.tap(find.text('Agree and analyse photo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Consent could not be saved. No photo was sent to AI.'),
      findsOneWidget,
    );
    expect(photo.reads, 0);
    expect(await consent.hasConsent(), isFalse);
  });

  testWidgets(
    'account change while camera or consent is pending cannot send old photo',
    (tester) async {
      final selected = Completer<XFile?>();
      final picker = _Picker(_Photo())..camera = () => selected.future;
      await mount(tester, picker);
      await tester.tap(
        find.text(AppLocalizations(const Locale('en')).t('treasureTakePhoto')),
      );
      await tester.pump();
      scope = 'account.photo-b';
      selected.complete(picker.photo);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(requests, isEmpty);
      picker.camera = null;
      await camera(tester);
      scope = 'account.photo-c';
      await tester.runAsync(() => AuthService.instance.logout());
      await tester.pumpAndSettle();
      expect(find.text('Agree and analyse photo'), findsNothing);
      expect(requests, isEmpty);
      await tester.tap(
        find.widgetWithText(
          TextButton,
          AppStringsManager.getString('en', 'cancel'),
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('newer photo and dispose cannot apply a late analysis response', (
    tester,
  ) async {
    await consent.grant(scope);
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final picker = _Picker(_Photo());
    await mount(tester, picker);
    await tester.tap(
      find.text(AppLocalizations(const Locale('en')).t('treasureTakePhoto')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(requests, hasLength(1));
    respond = (_) async => http.Response(_response(title: 'New photo'), 200);
    picker.photo = _Photo(path: '/new-photo.jpg');
    await camera(tester, more: true);
    expect(requests, hasLength(2));
    pending.complete(http.Response(_response(title: 'Old photo'), 200));
    await tester.pumpAndSettle();
    expect(find.text('Old photo'), findsNothing);
    await tester.scrollUntilVisible(
      find.byType(TextField).first,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('New photo'), findsWidgets);

    final disposed = Completer<http.Response>();
    respond = (_) => disposed.future;
    await tester.scrollUntilVisible(
      find.text(
        AppLocalizations(const Locale('en')).t('treasureAddMorePhotos'),
      ),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.text(
        AppLocalizations(const Locale('en')).t('treasureAddMorePhotos'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(requests, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
    disposed.complete(http.Response(_response(title: 'Disposed photo'), 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed analysis keeps manual fields and retry uses the consent service',
    (tester) async {
      await consent.grant(scope);
      respond = (_) async => http.Response('unavailable', 503);
      await mount(tester, _Picker(_Photo()));
      await camera(tester);
      final l10n = AppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.t('treasure_photo_analysis_failed')),
        findsOneWidget,
      );
      expect(requests, hasLength(1));
      await tester.scrollUntilVisible(
        find.byType(TextField).first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField).first, 'My manual title');
      respond = (_) async => http.Response(_response(), 200);
      await tester.scrollUntilVisible(
        find.text(l10n.t('try_again')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.t('try_again')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(find.byType(AlertDialog), findsNothing);
      await tester.scrollUntilVisible(
        find.byType(TextField).first,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('My manual title'), findsOneWidget);
      expect(find.text('Suggested bicycle'), findsNothing);
    },
  );

  testWidgets(
    'removed photo and account changes discard pending UI suggestions',
    (tester) async {
      await consent.grant(scope);
      final removed = Completer<http.Response>();
      respond = (_) => removed.future;
      final picker = _Picker(_Photo());
      await mount(tester, picker);
      final l10n = AppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.t('treasureTakePhoto')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requests, hasLength(1));
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      removed.complete(http.Response(_response(title: 'Removed photo'), 200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_a_photo_rounded), findsNothing);
      expect(find.text('Removed photo'), findsNothing);

      final changed = Completer<http.Response>();
      respond = (_) => changed.future;
      await tester.tap(find.text(l10n.t('treasureTakePhoto')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requests, hasLength(2));
      scope = 'account.photo-b';
      await tester.runAsync(() => AuthService.instance.logout());
      changed.complete(
        http.Response(_response(title: 'Previous account'), 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Previous account'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
