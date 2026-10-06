import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('year is not completed the day before the birthday', () {
    final now = DateTime.now();
    final birth = DateTime(now.year - 4, now.month, now.day + 1);
    final dossier = KindDossier(childName: 'Child', birthDate: birth);
    expect(dossier.ageYears, 3);
    expect(dossier.ageMonths, 47);
  });

  test('birthday and following day have the completed year', () {
    final now = DateTime.now();
    for (final day in [now.day, now.day - 1]) {
      final birth = DateTime(now.year - 4, now.month, day);
      expect(KindDossier(childName: 'Child', birthDate: birth).ageYears, 4);
    }
  });

  test('future birth date has zero completed months and years', () {
    final now = DateTime.now();
    final dossier = KindDossier(
      childName: 'Future',
      birthDate: DateTime(now.year + 1, now.month, now.day),
    );
    expect(dossier.ageMonths, 0);
    expect(dossier.ageYears, 0);
  });

  Future<void> saveProfile(List<ChildEntry> children) async {
    await AuthService.instance.debugSeedSessionForTesting();
    await FamilyMatchProfile(
      displayName: 'Family',
      district: 'District',
      children: children,
      languages: const ['de'],
      familyForm: 'family',
      values: const [],
      lookingFor: const [],
      createdAt: DateTime.now(),
    ).save(userId: AuthService.instance.currentUser!.uid);
  }

  Future<void> openChildren(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FamilienZentraleScreen()));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Children'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => AuthService.instance.logout());
  }

  testWidgets(
    'profile import preserves exact birth date, completed age and existing dossiers',
    (tester) async {
      final now = DateTime.now();
      final birth = DateTime(now.year - 4, now.month, now.day + 1);
      await tester.runAsync(
        () =>
            saveProfile([ChildEntry(name: 'Profile child', birthDate: birth)]),
      );
      await openChildren(tester);
      final imported = KindDossierService.instance.dossiers.single;
      expect(imported.birthDate, birth);
      expect(imported.uExams, hasLength(12));
      expect(find.text('3 years'), findsOneWidget);
      expect(find.text('4 years'), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
      final original = DateTime(2021, 2, 18);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await saveProfile([
          ChildEntry(name: 'Existing child', birthDate: DateTime(2022, 3, 19)),
          ChildEntry(name: 'New child', birthDate: DateTime(2023, 4, 20)),
        ]);
        final prefs = await SharedPreferences.getInstance();
        final scope = FamilyHubStore.instance.scope;
        await prefs.setString(FamilyHubStore.storageKey, jsonEncode({
          'accounts': {
            scope: {
              'owner': scope,
              'data': {
                FamilyHubStore.dossierKey: [
                  KindDossier(
                    id: 'existing',
                    childName: 'Existing child',
                    birthDate: original,
                    allergies: const ['Milk'],
                  ).toJson(),
                ],
              },
            },
          },
        }));
      });
      await openChildren(tester);
      final dossiers = KindDossierService.instance.dossiers;
      expect(dossiers, hasLength(2));
      final existing = dossiers.firstWhere((child) => child.id == 'existing');
      expect(existing.birthDate, original);
      expect(existing.allergies, ['Milk']);
      expect(dossiers.last.birthDate, DateTime(2023, 4, 20));
      expect(dossiers.last.uExams, hasLength(12));
      await close(tester);
    },
  );
}
