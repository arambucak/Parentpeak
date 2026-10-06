import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilyMatchProfile existingProfile({bool withCoordinates = true}) {
  final now = DateTime.now();
  return FamilyMatchProfile(
    displayName: 'Existing family',
    district: 'Munich district',
    city: withCoordinates ? 'Munich' : null,
    latitude: withCoordinates ? 48.14 : null,
    longitude: withCoordinates ? 11.58 : null,
    children: [
      ChildEntry(
        name: 'Local child',
        birthDate: DateTime(now.year - 4, 2, 17),
        gender: 'weiblich',
        interests: ['musik', 'natur'],
        interestsCustom: 'Local interest',
      ),
      ChildEntry(name: 'Older child', birthDate: DateTime(now.year - 20, 1, 1)),
    ],
    languages: ['en', 'tr'],
    familyForm: 'custom',
    familyFormCustom: 'Our family',
    values: ['gfk', 'montessori'],
    valuesCustom: 'Our values',
    lookingFor: ['spielplatz', 'natur'],
    lookingForCustom: 'Our activities',
    availDays: ['montag', 'samstag'],
    availTimes: ['nachmittags'],
    availCustom: 'Our availability',
    specials: ['allergien'],
    specialsCustom: 'Local health information',
    bio: 'Existing public bio',
    hasPhoto: true,
    createdAt: DateTime(2024, 1, 2),
  );
}

Future<void> openForm(
  WidgetTester tester,
  FamilyMatchProfile profile, {
  required Future<void> Function(FamilyMatchProfile) onSave,
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlaymateProfileForm(
          initialProfile: profile,
          onSave: onSave,
          onCancel: onCancel,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> goToSave(WidgetTester tester) async {
  for (var step = 0; step < 4; step++) {
    await tester.tap(
      find.widgetWithIcon(FilledButton, Icons.arrow_forward_rounded),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('editing preloads every field and preserves exact birthdays', (
    tester,
  ) async {
    final original = existingProfile();
    FamilyMatchProfile? submitted;
    await openForm(tester, original, onSave: (p) async => submitted = p);
    expect(find.text(original.displayName), findsOneWidget);
    expect(find.text(original.district), findsOneWidget);
    await goToSave(tester);
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        AppStringsManager.getString(languageService.currentLanguage, 'save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!.toJson(), original.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy text-only location is visible and survives editing', (
    tester,
  ) async {
    final original = existingProfile(withCoordinates: false);
    FamilyMatchProfile? submitted;
    await openForm(tester, original, onSave: (p) async => submitted = p);
    expect(find.text(original.district), findsOneWidget);
    await goToSave(tester);
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        AppStringsManager.getString(languageService.currentLanguage, 'save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(submitted!.toJson(), original.toJson());
  });

  testWidgets('cancel does not submit or overwrite the saved profile', (
    tester,
  ) async {
    final original = existingProfile();
    await original.save();
    var saved = false;
    var cancelled = false;
    await openForm(
      tester,
      original,
      onSave: (_) async => saved = true,
      onCancel: () => cancelled = true,
    );
    await tester.enterText(find.byType(TextField).first, 'Unsaved name');
    await tester.tap(
      find.widgetWithText(
        TextButton,
        AppStringsManager.getString(languageService.currentLanguage, 'cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(saved, isFalse);
    expect((await FamilyMatchProfile.load())!.toJson(), original.toJson());
  });

  for (final consent in [false, true]) {
    testWidgets('unsuccessful edit preserves stored data (consent: $consent)', (
      tester,
    ) async {
      final original = existingProfile();
      await original.save();
      var requests = 0;
      final profiles = PlaymateProfileService(
        matchingService: ParentMatchingBackendService(
          apiClient: BackendApiClient(
            baseUrl: 'https://backend.example',
            httpClient: MockClient((_) async {
              requests++;
              return http.Response('{"error":"unavailable"}', 503);
            }),
          ),
        ),
      );
      PlaymatePublicationResult? result;
      await openForm(
        tester,
        original,
        onSave: (p) async {
          result = await profiles.publishProfile(
            p,
            'owner',
            confirmPublication: () async => consent,
          );
        },
      );
      await tester.enterText(find.byType(TextField).first, 'Edited name');
      await goToSave(tester);
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          AppStringsManager.getString(languageService.currentLanguage, 'save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        result,
        consent
            ? PlaymatePublicationResult.failed
            : PlaymatePublicationResult.cancelled,
      );
      expect(requests, consent ? 1 : 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('spielfreunde.profile')!),
        original.toJson(),
      );
      expect(find.byType(PlaymateProfileForm), findsOneWidget);
    });
  }

  testWidgets('editing a child age updates only that child birthday', (
    tester,
  ) async {
    final original = existingProfile();
    FamilyMatchProfile? submitted;
    await openForm(tester, original, onSave: (p) async => submitted = p);
    await tester.tap(
      find.widgetWithIcon(FilledButton, Icons.arrow_forward_rounded),
    );
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChanged!(24);
    await tester.pump();
    for (var step = 1; step < 4; step++) {
      await tester.tap(
        find.widgetWithIcon(FilledButton, Icons.arrow_forward_rounded),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        AppStringsManager.getString(languageService.currentLanguage, 'save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(submitted!.children.first.ageMonths, 24);
    expect(
      submitted!.children.first.birthDate,
      isNot(original.children.first.birthDate),
    );
    expect(
      submitted!.children.last.birthDate,
      original.children.last.birthDate,
    );
    expect(original.children.first.ageMonths, isNot(24));
  });

  testWidgets(
    'confirmed edit persists all fields after server acknowledgement',
    (tester) async {
      final original = existingProfile();
      await original.save();
      final profiles = PlaymateProfileService(
        matchingService: ParentMatchingBackendService(
          apiClient: BackendApiClient(
            baseUrl: 'https://backend.example',
            httpClient: MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['name'], 'Edited family');
              return http.Response(
                jsonEncode({
                  'item': {'id': 'self-owner', 'ownerUserId': 'owner'},
                }),
                201,
              );
            }),
          ),
        ),
      );
      PlaymatePublicationResult? result;
      await openForm(
        tester,
        original,
        onSave: (p) async {
          result = await profiles.publishProfile(
            p,
            'owner',
            confirmPublication: () async => true,
          );
        },
      );
      await tester.enterText(find.byType(TextField).first, 'Edited family');
      await goToSave(tester);
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          AppStringsManager.getString(languageService.currentLanguage, 'save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(result, PlaymatePublicationResult.published);
      expect((await FamilyMatchProfile.load())!.toJson(), {
        ...original.toJson(),
        'displayName': 'Edited family',
      });
      expect(original.displayName, 'Existing family');
    },
  );
}
