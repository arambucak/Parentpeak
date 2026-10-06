import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/logic/family_hub_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KindDossier id', () {
    test('vergibt automatisch eine ID, wenn keine übergeben wird', () {
      final a = KindDossier(childName: 'A');
      final b = KindDossier(childName: 'A');
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id), reason: 'IDs müssen eindeutig sein');
    });

    test('übernimmt eine explizit übergebene ID', () {
      final d = KindDossier(id: 'kd_fix', childName: 'A');
      expect(d.id, 'kd_fix');
    });

    test('copyWith behält die ID bei', () {
      final d = KindDossier(id: 'kd_fix', childName: 'A');
      expect(d.copyWith(childName: 'B').id, 'kd_fix');
    });

    test('fromJson ohne id vergibt eine neue (Migration)', () {
      final json = {'childName': 'Alt', 'ageMonths': 12};
      final d = KindDossier.fromJson(json);
      expect(d.id, isNotEmpty);
      expect(d.childName, 'Alt');
    });

    test('toJson enthält die id und round-trip erhält sie', () {
      final d = KindDossier(id: 'kd_fix', childName: 'A', ageMonths: 24);
      final restored = KindDossier.fromJson(d.toJson());
      expect(restored.id, 'kd_fix');
    });
  });

  group('KindDossierService Identität', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('addOrUpdate per ID: gleichnamige Kinder kollidieren nicht', () async {
      final service = KindDossierService.instance;
      await service.save([]);
      final max1 = KindDossier(id: 'id1', childName: 'Max', ageMonths: 24);
      final max2 = KindDossier(id: 'id2', childName: 'Max', ageMonths: 60);
      await service.addOrUpdate(max1);
      await service.addOrUpdate(max2);
      expect(service.dossiers.length, 2,
          reason: 'zwei gleichnamige Kinder bleiben getrennt');
    });

    test('Umbenennen aktualisiert dasselbe Dossier (keine Dublette)', () async {
      final service = KindDossierService.instance;
      await service.save([]);
      final mila = KindDossier(id: 'id1', childName: 'Mila', ageMonths: 24);
      await service.addOrUpdate(mila);
      // Umbenennen: gleiche ID, neuer Name.
      await service.addOrUpdate(mila.copyWith(childName: 'Mila-Sophie'));
      expect(service.dossiers.length, 1);
      expect(service.dossiers.first.childName, 'Mila-Sophie');
      expect(service.dossiers.first.id, 'id1');
    });

    test('findByName findet nach Namen (für Profil-Resync)', () async {
      final service = KindDossierService.instance;
      await service.save([
        KindDossier(id: 'id1', childName: 'Mila', ageMonths: 24),
      ]);
      expect(service.findByName('Mila')?.id, 'id1');
      expect(service.findByName('Unbekannt'), isNull);
    });

    test('load migriert Alt-Daten ohne id und schreibt sie zurück', () async {
      // Alt-Datensatz ohne 'id' direkt in die Prefs legen.
      final legacy = [
        {'childName': 'Alt', 'ageMonths': 12}
      ];
      SharedPreferences.setMockInitialValues(
          {'kinddossier.data': jsonEncode(legacy)});

      final store = FamilyHubStore(userIdProvider: () => 'legacy-owner');
      final service = KindDossierService(store: store);
      await service.load();
      expect(service.dossiers, isEmpty);
      await claimFamilyHubLegacy(expectedScope: store.scope, store: store);
      await service.load();
      expect(service.dossiers.length, 1);
      final id = service.dossiers.first.id;
      expect(id, isNotEmpty);

      // Zurückgeschrieben: erneutes Laden liefert dieselbe (stabile) ID.
      await service.load();
      expect(service.dossiers.first.id, id);
    });
  });
}
