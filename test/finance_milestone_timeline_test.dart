import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/logic/finance_milestone_timeline.dart';
import 'package:parentpeak/models/country_finance_config.dart';

void main() {
  test('every country is sorted without modifying its configured data', () {
    for (final country in CountryFinanceData.availableCountries) {
      final original = country.milestones.toList();
      final sorted = FinanceMilestoneTimeline.sorted(original);
      for (var i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].childAgeYears,
          greaterThanOrEqualTo(sorted[i - 1].childAgeYears),
        );
      }
      expect(country.milestones, orderedEquals(original));
    }
    expect(
      FinanceMilestoneTimeline.sorted(
        CountryFinanceData.germany.milestones,
      ).map((m) => m.id),
      [
        'fahrrad',
        'schulstart',
        'klassenfahrt',
        'smartphone',
        'fuehrerschein',
        'ausbildung',
      ],
    );
  });

  test('three years seven months keeps bicycle with five months remaining', () {
    final birth = DateTime(2023, 3, 6);
    final now = DateTime(2026, 10, 6);
    expect(FinanceMilestoneTimeline.completedYears(birth, now), 3);
    final estimates = FinanceMilestoneTimeline.upcoming(
      CountryFinanceData.germany.milestones,
      birth,
      now,
    );
    expect(estimates.first.milestone.id, 'fahrrad');
    expect(estimates.first.date, DateTime(2027, 3, 6));
    expect(estimates.first.monthsLeft, 5);
  });

  test('birthday boundary uses calendar days, not rounding or time of day', () {
    final birth = DateTime(2022, 12, 20, 18);
    for (final day in [19, 20, 21]) {
      final now = DateTime(2026, 12, day, 23);
      final estimates = FinanceMilestoneTimeline.upcoming(
        CountryFinanceData.germany.milestones,
        birth,
        now,
      );
      expect(
        FinanceMilestoneTimeline.completedYears(birth, now),
        day < 20 ? 3 : 4,
      );
      expect(estimates.first.milestone.id, day < 20 ? 'fahrrad' : 'schulstart');
      if (day < 20) {
        expect(estimates.first.date.year, 2026);
        expect(estimates.first.monthsLeft, 1);
      }
    }
  });

  test(
    'calendar year follows birthday, not current year plus integer age gap',
    () {
      final estimate = FinanceMilestoneTimeline.upcoming(
        CountryFinanceData.germany.milestones,
        DateTime(2023, 12, 20),
        DateTime(2026, 1, 1),
      ).first;
      expect(estimate.date, DateTime(2027, 12, 20));
      expect(estimate.monthsLeft, 24);
    },
  );

  test(
    'five-year horizon includes this year and exact endpoint, not next day',
    () {
      const milestones = [
        MilestoneCost(
          id: 'soon',
          label: '',
          emoji: '',
          estimatedCost: 10,
          childAgeYears: 3,
        ),
        MilestoneCost(
          id: 'limit',
          label: '',
          emoji: '',
          estimatedCost: 20,
          childAgeYears: 8,
        ),
      ];
      final now = DateTime(2026, 10, 6);
      expect(
        FinanceMilestoneTimeline.withinFiveYears(
          milestones,
          DateTime(2023, 10, 7),
          now,
        ).map((e) => e.milestone.id),
        ['soon'],
      );
      expect(
        FinanceMilestoneTimeline.withinFiveYears(
          milestones,
          DateTime(2023, 10, 6),
          now,
        ).map((e) => e.milestone.id),
        ['limit'],
      );
      expect(
        FinanceMilestoneTimeline.withinFiveYears(
          milestones,
          DateTime(2023, 10, 5),
          now,
        ).map((e) => e.milestone.id),
        ['limit'],
      );
    },
  );

  test('leap-day birthdays retain the existing March normalization', () {
    final birth = DateTime(2024, 2, 29);
    final estimates = FinanceMilestoneTimeline.upcoming(
      CountryFinanceData.germany.milestones,
      birth,
      DateTime(2027, 2, 28),
    );
    expect(
      FinanceMilestoneTimeline.completedYears(birth, DateTime(2027, 2, 28)),
      2,
    );
    expect(
      FinanceMilestoneTimeline.completedYears(birth, DateTime(2027, 3, 1)),
      3,
    );
    expect(estimates.first.date, DateTime(2028, 2, 29));
    expect(estimates.first.monthsLeft, 13);
  });

  test(
    'no future goals after last birthday and no negative age for future birth',
    () {
      expect(
        FinanceMilestoneTimeline.upcoming(
          CountryFinanceData.germany.milestones,
          DateTime(2000),
          DateTime(2026),
        ),
        isEmpty,
      );
      expect(
        FinanceMilestoneTimeline.completedYears(DateTime(2027), DateTime(2026)),
        0,
      );
    },
  );
}
