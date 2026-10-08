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
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/family_recipe_consent.dart';
import 'package:parentpeak/logic/fridge_photo_consent.dart';
import 'package:parentpeak/logic/fridge_recipe_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/ui/fridge_recipe_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Photo extends XFile {
  _Photo({this.onRead}) : super('/not-a-real-fridge.jpg');
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
  int picks = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    picks++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String owner;
  late FridgePhotoConsent consent;
  late FridgeRecipeService service;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    owner = 'account.fridge-a';
    consent = FridgePhotoConsent(scopeProvider: () => owner);
    requests = [];
    respond = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({
        'text': body.containsKey('imageBase64')
            ? '["Rice"]'
            : jsonEncode({
                'title': 'Rice', 'ingredients': ['Rice'], 'steps': ['Cook'],
                'minChildAge': 0,
              }),
      }), 200);
    };
    service = FridgeRecipeService(
      consent: consent,
      aiService: GeminiAIService(apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        authToken: 'audit-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      )),
    );
  });

  test('legacy and separate recipe consent cannot authorize either fridge path', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fridge.ai_photo_consent', true);
    await FamilyRecipeConsent(scopeProvider: () => owner).grant(owner);
    final photo = _Photo();
    await expectLater(
      service.detectIngredients(photo, expectedScope: owner),
      throwsA(isA<FridgePhotoConsentRequiredException>()),
    );
    await expectLater(
      service.generateFromIngredients(['Rice'], expectedScope: owner),
      throwsA(isA<FridgePhotoConsentRequiredException>()),
    );
    expect(photo.reads, 0);
    expect(requests, isEmpty);
    expect(prefs.getBool('fridge.ai_photo_consent'), isTrue);
  });

  test('versioned account and guest scopes never inherit another approval', () async {
    await consent.grant(owner);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fridge.ai_photo_consent.v1.account.fridge-a'), isTrue);
    expect(await FridgePhotoConsent(scopeProvider: () => owner).hasConsent(), isTrue);
    owner = 'account.fridge-b';
    expect(await consent.hasConsent(), isFalse);
    await expectLater(consent.grant('account.fridge-a'),
        throwsA(isA<FridgePhotoConsentRequiredException>()));
    owner = 'guest';
    expect(await consent.hasConsent(), isFalse);
  });

  test('false and thrown write acknowledgements do not enable consent', () async {
    for (final throws in [false, true]) {
      final failed = FridgePhotoConsent(scopeProvider: () => owner,
        persist: (_, __) async {
          if (throws) throw StateError('storage unavailable');
          return false;
        });
      await expectLater(failed.grant(owner), throwsStateError);
      expect(await failed.hasConsent(), isFalse);
    }
    expect(requests, isEmpty);
  });

  test('four languages transmit photo bytes and recipe only with consent', () async {
    await consent.grant(owner);
    for (final language in ['de', 'en', 'tr', 'ku']) {
      final photo = _Photo();
      expect(await service.detectIngredients(photo,
          expectedScope: owner, languageCode: language), ['Rice']);
      expect(photo.reads, 1);
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body['imageBase64'], 'AQID');
      expect(body['language'], language);
      expect(body['systemInstruction'], contains('JSON'));
      expect(body.containsKey('childProfileId'), isFalse);
      expect(await service.generateFromIngredients(['Rice'],
          expectedScope: owner, languageCode: language), isNotNull);
      final recipe = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(recipe.containsKey('imageBase64'), isFalse);
      expect(recipe['language'], language);
    }
    expect(requests, hasLength(8));
  });

  test('account change during image read blocks even an approved new account', () async {
    await consent.grant(owner);
    final original = owner;
    final photo = _Photo(onRead: () async {
      owner = 'account.fridge-b';
      await consent.grant(owner);
    });
    await expectLater(service.detectIngredients(photo, expectedScope: original),
        throwsA(isA<FridgePhotoConsentRequiredException>()));
    expect(photo.reads, 1);
    expect(requests, isEmpty);
  });

  test('removed consent during image read blocks HTTP', () async {
    await consent.grant(owner);
    final photo = _Photo(onRead: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${consent.storagePrefix}.$owner');
    });
    await expectLater(service.detectIngredients(photo, expectedScope: owner),
        throwsA(isA<FridgePhotoConsentRequiredException>()));
    expect(requests, isEmpty);
  });

  test('both late response paths reject changed accounts instead of fallback success', () async {
    for (final photoPath in [true, false]) {
      owner = 'account.fridge-a';
      await consent.grant(owner);
      final original = owner;
      respond = (_) async {
        owner = 'account.fridge-b';
        await consent.grant(owner);
        return http.Response(jsonEncode({'text': '["Rice"]'}), 200);
      };
      await expectLater(
        photoPath
            ? service.detectIngredients(_Photo(), expectedScope: original)
            : service.generateFromIngredients(['Rice'], expectedScope: original),
        throwsA(isA<FridgePhotoConsentRequiredException>()),
      );
    }
  });

  test('account change before 401 retry prevents a second HTTP transfer', () async {
    await consent.grant(owner);
    final original = owner;
    respond = (_) async {
      owner = 'account.fridge-b';
      await consent.grant(owner);
      return http.Response('{}', 401);
    };
    await expectLater(service.detectIngredients(_Photo(), expectedScope: original),
        throwsA(isA<FridgePhotoConsentRequiredException>()));
    expect(requests, hasLength(1));
  });

  test('removed consent after HTTP rejects both result paths', () async {
    for (final photoPath in [true, false]) {
      await consent.grant(owner);
      respond = (_) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('${consent.storagePrefix}.$owner');
        return http.Response(jsonEncode({'text': '["Rice"]'}), 200);
      };
      await expectLater(
        photoPath
            ? service.detectIngredients(_Photo(), expectedScope: owner)
            : service.generateFromIngredients(['Rice'], expectedScope: owner),
        throwsA(isA<FridgePhotoConsentRequiredException>()),
      );
    }
  });

  for (final language in ['de', 'en', 'tr', 'ku']) {
    testWidgets('$language production dialog names recipient and refusal blocks picker',
        (tester) async {
      final picker = _Picker();
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate, AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: FridgeRecipeScreen(service: service, picker: picker),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStringsManager.getString(language, 'fridge_take_photo')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google Gemini'), findsOneWidget);
      await tester.tap(find.text(AppStringsManager.getString(language, 'cancel')));
      await tester.pumpAndSettle();
      expect(picker.picks, 0);
      expect(requests, isEmpty);
    });
  }

  testWidgets('production consent write failure is visible and blocks picker',
      (tester) async {
    final failing = FridgePhotoConsent(scopeProvider: () => owner,
      persist: (_, __) async => false);
    final picker = _Picker();
    await tester.pumpWidget(MaterialApp(home: FridgeRecipeScreen(
      service: FridgeRecipeService(consent: failing), picker: picker)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and analyze photo'));
    await tester.pumpAndSettle();
    expect(find.text(AppStringsManager.getString('en', 'fridge_consent_failed')), findsOneWidget);
    expect(picker.picks, 0);
    expect(await failing.hasConsent(), isFalse);
  });
}
