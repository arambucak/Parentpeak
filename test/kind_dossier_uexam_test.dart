import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/kind_dossier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UExaminationData.generateForChild', () {
    test('erzeugt immer alle 12 Untersuchungen (unabhängig vom Alter)', () {
      expect(UExaminationData.generateForChild(0).length, 12);
      expect(UExaminationData.generateForChild(200).length, 12);
    });

    test('übernimmt den Erledigt-Status aus existing', () {
      final existing = [
        const UExamination(
            id: 'u1',
            dueAtMonths: 0,
            isDone: true,
            doneDate: '2026-01-01T00:00:00.000'),
      ];
      final result = UExaminationData.generateForChild(12, existing: existing);
      final u1 = result.firstWhere((e) => e.id == 'u1');
      expect(u1.isDone, isTrue);
      expect(u1.doneDate, '2026-01-01T00:00:00.000');
      // Nicht übernommene bleiben offen.
      expect(result.firstWhere((e) => e.id == 'u2').isDone, isFalse);
    });
  });

  group('UExaminationData.localizedLabel', () {
    const exam =
        UExamination(id: 'u3', label: 'U3 — 4.-5. Woche', dueAtMonths: 1);

    test('baut Label aus sprachneutraler ID + übersetztem Zeitfenster', () {
      expect(UExaminationData.localizedLabel(exam, 'de'), 'U3 — 4.–5. Woche');
      expect(UExaminationData.localizedLabel(exam, 'en'), 'U3 — week 4–5');
      expect(UExaminationData.localizedLabel(exam, 'tr'), 'U3 — 4.–5. hafta');
      expect(UExaminationData.localizedLabel(exam, 'ku'), 'U3 — hefteya 4.–5.');
    });

    test('ID behält Suffix-Kleinschreibung (u7a -> U7a)', () {
      const u7a = UExamination(id: 'u7a', dueAtMonths: 34);
      expect(
          UExaminationData.localizedLabel(u7a, 'de').startsWith('U7a'), isTrue);
    });

    test('bare-ID-Fallback nutzt dieselbe Groß-/Kleinschreibung (x99 -> X99)',
        () {
      const bare = UExamination(id: 'x99', dueAtMonths: 0);
      expect(UExaminationData.localizedLabel(bare, 'de'), 'X99');
    });

    test('fällt auf rohes Label zurück, wenn kein Zeitfenster bekannt ist', () {
      const unknown =
          UExamination(id: 'x99', label: 'Alt-Label', dueAtMonths: 0);
      expect(UExaminationData.localizedLabel(unknown, 'de'), 'Alt-Label');
    });

    test('fällt auf ID zurück, wenn weder Zeitfenster noch Label vorhanden',
        () {
      const bare = UExamination(id: 'x99', dueAtMonths: 0);
      expect(UExaminationData.localizedLabel(bare, 'de'), 'X99');
    });
  });

  group('KindDossierService.setUExamDone (per Dossier-ID)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    KindDossier mila() => KindDossier(
          id: 'id_mila',
          childName: 'Mila',
          ageMonths: 24,
          uExams: UExaminationData.generateForChild(24),
        );

    test('hakt eine Untersuchung ab und setzt doneDate', () async {
      final service = KindDossierService.instance;
      await service.save([mila()]);

      final updated = await service.setUExamDone('id_mila', 'u3', true);
      expect(updated, isNotNull);
      final u3 = updated!.uExams.firstWhere((e) => e.id == 'u3');
      expect(u3.isDone, isTrue);
      expect(u3.doneDate, isNotNull);
    });

    test('entfernt den Haken wieder und löscht doneDate', () async {
      final service = KindDossierService.instance;
      await service.save([mila()]);
      await service.setUExamDone('id_mila', 'u3', true);

      final updated = await service.setUExamDone('id_mila', 'u3', false);
      final u3 = updated!.uExams.firstWhere((e) => e.id == 'u3');
      expect(u3.isDone, isFalse);
      expect(u3.doneDate, isNull);
    });

    test('persistiert über Neuladen hinweg', () async {
      final service = KindDossierService.instance;
      await service.save([mila()]);
      await service.setUExamDone('id_mila', 'u3', true);

      // Frisch laden simuliert App-Neustart.
      await service.load();
      final u3 = service.dossiers
          .firstWhere((d) => d.id == 'id_mila')
          .uExams
          .firstWhere((e) => e.id == 'u3');
      expect(u3.isDone, isTrue);
    });

    test('meldet unbekanntes Kind oder unbekannte Untersuchung als Fehler',
        () async {
      final service = KindDossierService.instance;
      await service.save([mila()]);
      await expectLater(service.setUExamDone('id_unbekannt', 'u3', true), throwsStateError);
      await expectLater(service.setUExamDone('id_mila', 'u999', true), throwsStateError);
    });
  });
}
