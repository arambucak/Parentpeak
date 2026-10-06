import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fallback and exam date follow locale; editor owns controller lifecycle',
    (tester) async {
      final birth = DateTime(2022, 3, 18);
      final doneDate = DateTime(2025, 2, 18);
      for (final language in ['de', 'en', 'tr', 'ku']) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({});
          await AuthService.instance.debugSeedSessionForTesting();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            FamilyMatchProfile.storageKey(
              AuthService.instance.currentUser!.uid,
            ),
            jsonEncode({
              'ownerUserId': AuthService.instance.currentUser!.uid,
              'profile': {
                'children': [ChildEntry(name: '', birthDate: birth).toJson()],
              },
            }),
          );
          final scope = FamilyHubStore.instance.scope;
          await prefs.setString(
            FamilyHubStore.storageKey,
            jsonEncode({
              'accounts': {
                scope: {
                  'owner': scope,
                  'data': {
                    FamilyHubStore.dossierKey: [
                      KindDossier(
                        id: 'known',
                        childName: 'Known child',
                        birthDate: DateTime(2020, 1, 20),
                        doctorName: 'Doctor',
                        uExams: [
                          UExamination(
                            id: 'u3',
                            dueAtMonths: 1,
                            isDone: true,
                            doneDate: doneDate.toIso8601String(),
                          ),
                        ],
                      ).toJson(),
                    ],
                  },
                },
              },
            }),
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLanguages.supportedLocales,
            localizationsDelegates: const [
              AppLanguages.materialLocalizationsDelegate,
              AppLanguages.widgetsLocalizationsDelegate,
              AppLanguages.cupertinoLocalizationsDelegate,
            ],
            home: const FamilienZentraleScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        String tr(String key) => AppStringsManager.getString(language, key);
        await tester.tap(find.text(tr('family_hub_tab_children')));
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(ListView).first,
          matching: find.text(tr('family_hub_child_fallback'))), findsOneWidget);
        expect(KindDossierService.instance.dossiers, hasLength(2));
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pumpAndSettle();
        final tileContext = tester.element(find.byType(ExpansionTile).first);
        final expectedDate = MaterialLocalizations.of(
          tileContext,
        ).formatShortDate(doneDate);
        expect(
          find.text(
            AppStringsManager.getString(
              language,
              'family_hub_uexam_done_on',
            ).replaceAll('{date}', expectedDate),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.edit_rounded).first);
        await tester.pumpAndSettle();
        final controllers = <TextEditingController>{};
        for (var step = 0; step < 6; step++) {
          controllers.addAll(
            tester
                .widgetList<TextField>(find.byType(TextField))
                .map((field) => field.controller!),
          );
          await tester.drag(find.byType(ListView).last, const Offset(0, -250));
          await tester.pumpAndSettle();
        }
        expect(controllers, hasLength(13));
        Navigator.of(
          tester.element(find.byType(DraggableScrollableSheet)),
        ).pop();
        await tester.pumpAndSettle();
        for (final controller in controllers) {
          expect(() => controller.addListener(() {}), throwsAssertionError);
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.edit_rounded).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Renamed child');
        final save = find.widgetWithText(
          FilledButton,
          AppStringsManager.getString('de', 'save_btn'),
        );
        await tester.scrollUntilVisible(
          save,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(find.text('Renamed child'), findsOneWidget);
        expect(KindDossierService.instance.dossiers.first.doctorName, 'Doctor');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.edit_rounded).first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(save, 250,
          scrollable: find.descendant(of: find.byType(ListView).last,
            matching: find.byType(Scrollable)).first);
        final sheetContext = tester.element(find.byType(DraggableScrollableSheet));
        tester.widget<FilledButton>(save).onPressed!();
        Navigator.of(sheetContext).pop();
        await tester.pumpAndSettle();
        await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
        await tester.pumpAndSettle();
        expect(find.byType(FamilienZentraleScreen), findsOneWidget);
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(tester.takeException(), isNull);
      }

      final persisted = KindDossierService.instance.dossiers;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: const [
            AppLanguages.materialLocalizationsDelegate,
            AppLanguages.widgetsLocalizationsDelegate,
            AppLanguages.cupertinoLocalizationsDelegate,
          ],
          home: const FamilienZentraleScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        KindDossierService.instance.dossiers.map((dossier) => dossier.id),
        persisted.map((dossier) => dossier.id),
        reason: 'Locale switch must not create another unnamed imported child',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final oldBirth = DateTime(2022, 3, 1);
      await tester.runAsync(() async {
        final prefs = await SharedPreferences.getInstance();
        final scope = FamilyHubStore.instance.scope;
        await prefs.setString(FamilyHubStore.storageKey, jsonEncode({
          'accounts': {
            scope: {
              'owner': scope,
              'data': {
                FamilyHubStore.dossierKey: [
                  KindDossier(id: 'old-fallback', childName: 'Kind',
                    birthDate: oldBirth, allergies: const ['Milk']).toJson(),
                ],
              },
            },
          },
        }));
      });
      await tester.pumpWidget(const MaterialApp(home: FamilienZentraleScreen()));
      await tester.pumpAndSettle();
      expect(KindDossierService.instance.dossiers.single.id, 'old-fallback');
      expect(KindDossierService.instance.dossiers.single.birthDate, oldBirth);
      expect(KindDossierService.instance.dossiers.single.allergies, ['Milk']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => AuthService.instance.logout());
    },
  );
}
