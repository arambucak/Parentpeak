import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/development_checkin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<DevelopmentCheckinStore> store() async =>
      DevelopmentCheckinStore(prefs: await SharedPreferences.getInstance());

  group('Antworten pro Altersgruppe getrennt', () {
    test(
      'Antworten einer Altersgruppe landen NICHT in einer anderen',
      () async {
        final s = await store();
        await s.saveAnswers('2-3y', {'motorik_0': 2, 'sprache_1': 1});

        // Dieselbe Altersgruppe liefert die Antworten zurück ...
        expect(await s.loadAnswers('2-3y'), {'motorik_0': 2, 'sprache_1': 1});
        // ... eine ANDERE Altersgruppe ist leer (kein Übersprechen).
        expect(await s.loadAnswers('3-4y'), isEmpty);
      },
    );

    test(
      'Wachsen über eine Altersgrenze korrumpiert alte Antworten nicht',
      () async {
        final s = await store();
        // Kind beantwortet den Check mit 2-3 Jahren.
        await s.saveAnswers('2-3y', {'motorik_0': 2, 'motorik_1': 2});
        // Später beantwortet es (als 3-4-Jähriges) andere Fragen.
        await s.saveAnswers('3-4y', {'motorik_0': 0});

        // Beide Sätze bleiben strikt getrennt erhalten.
        expect(await s.loadAnswers('2-3y'), {'motorik_0': 2, 'motorik_1': 2});
        expect(await s.loadAnswers('3-4y'), {'motorik_0': 0});
      },
    );

    test('clearAnswers leert nur die betroffene Altersgruppe', () async {
      final s = await store();
      await s.saveAnswers('2-3y', {'motorik_0': 2});
      await s.saveAnswers('3-4y', {'sprache_0': 1});

      await s.clearAnswers('2-3y');

      expect(await s.loadAnswers('2-3y'), isEmpty);
      expect(await s.loadAnswers('3-4y'), {'sprache_0': 1});
    });

    test('Der alte globale Legacy-Key wird NICHT mehr gelesen', () async {
      SharedPreferences.setMockInitialValues({
        // So sah der buggy Legacy-Zustand aus.
        'dev.answers.v3': 'motorik_0:2,sprache_0:2',
      });
      final s = DevelopmentCheckinStore(
        prefs: await SharedPreferences.getInstance(),
      );
      // Keine Altersgruppe erbt die alten, nicht zuordenbaren Antworten.
      expect(await s.loadAnswers('2-3y'), isEmpty);
    });
  });

  group('Score-Verlauf (Snapshot) pro Altersgruppe', () {
    test('report snapshots remain account-scoped', () async {
      final s = await store();
      await s.saveSnapshot(
        '2-3y',
        DevelopmentScoreSnapshot(
          scores: const {'motorik': 1},
          date: DateTime(2026),
        ),
        scope: 'account.a',
      );
      expect(await s.loadPreviousSnapshot('2-3y', scope: 'account.b'), isNull);
      expect(await s.loadPreviousSnapshot('2-3y'), isNull);
      expect(
        await s.loadPreviousSnapshot('2-3y', scope: 'account.a'),
        isNotNull,
      );
    });

    test('invalidated request cannot write a report snapshot', () async {
      final s = await store();
      await expectLater(
        s.saveSnapshot(
          '2-3y',
          DevelopmentScoreSnapshot(scores: const {}, date: DateTime(2026)),
          scope: 'account.a',
          requestGuard: () => throw StateError('Account changed'),
        ),
        throwsStateError,
      );
      expect(await s.loadPreviousSnapshot('2-3y', scope: 'account.a'), isNull);
    });

    test('ohne vorherigen Check gibt es keinen Snapshot', () async {
      final s = await store();
      expect(await s.loadPreviousSnapshot('2-3y'), isNull);
    });

    test('gespeicherter Snapshot wird korrekt zurückgelesen', () async {
      final s = await store();
      final date = DateTime(2026, 9, 1, 10, 30);
      await s.saveSnapshot(
        '2-3y',
        DevelopmentScoreSnapshot(
          scores: const {'motorik': 0.8, 'sprache': 0.5},
          date: date,
        ),
      );

      final loaded = await s.loadPreviousSnapshot('2-3y');
      expect(loaded, isNotNull);
      expect(loaded!.scores['motorik'], closeTo(0.8, 1e-9));
      expect(loaded.scores['sprache'], closeTo(0.5, 1e-9));
      expect(loaded.date, date);
    });

    test('Snapshots verschiedener Altersgruppen sind getrennt', () async {
      final s = await store();
      await s.saveSnapshot(
        '2-3y',
        DevelopmentScoreSnapshot(
          scores: const {'motorik': 1.0},
          date: DateTime(2026, 1, 1),
        ),
      );

      expect(await s.loadPreviousSnapshot('3-4y'), isNull);
      expect(
        (await s.loadPreviousSnapshot('2-3y'))!.scores['motorik'],
        closeTo(1.0, 1e-9),
      );
    });
  });

  group('DevelopmentScoreSnapshot JSON', () {
    test('toJson/fromJson sind verlustfrei', () {
      final original = DevelopmentScoreSnapshot(
        scores: const {'a': 0.25, 'b': 0.75},
        date: DateTime(2026, 3, 15, 8, 0),
      );
      final restored = DevelopmentScoreSnapshot.fromJson(original.toJson());
      expect(restored.scores, original.scores);
      expect(restored.date, original.date);
    });

    test('fromJson toleriert fehlende/kaputte Felder', () {
      final restored = DevelopmentScoreSnapshot.fromJson(const {});
      expect(restored.scores, isEmpty);
      expect(restored.date, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });
}
