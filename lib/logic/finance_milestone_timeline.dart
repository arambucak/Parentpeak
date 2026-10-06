import 'package:parentpeak/models/child_development_data.dart';
import 'package:parentpeak/models/country_finance_config.dart';

class FinanceMilestoneEstimate {
  const FinanceMilestoneEstimate(this.milestone, this.date, this.monthsLeft);

  final MilestoneCost milestone;
  final DateTime date;
  final int monthsLeft;
}

/// Typical milestone ages estimate birthdays, not actual school/event dates.
class FinanceMilestoneTimeline {
  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static int completedYears(DateTime birth, DateTime now) =>
      ChildProfile.monthsBetween(birth, now) ~/ 12;

  static List<MilestoneCost> sorted(Iterable<MilestoneCost> milestones) =>
      milestones.toList()
        ..sort((a, b) => a.childAgeYears.compareTo(b.childAgeYears));

  static List<FinanceMilestoneEstimate> upcoming(
    Iterable<MilestoneCost> milestones,
    DateTime birth,
    DateTime now,
  ) {
    final today = day(now);
    return [
      for (final milestone in sorted(milestones))
        if (DateTime(birth.year + milestone.childAgeYears, birth.month, birth.day)
            .isAfter(today))
          _estimate(milestone, birth, today),
    ];
  }

  static FinanceMilestoneEstimate _estimate(
    MilestoneCost milestone,
    DateTime birth,
    DateTime today,
  ) {
    final date =
        DateTime(birth.year + milestone.childAgeYears, birth.month, birth.day);
    // A partial remaining calendar month counts as one planning month.
    final months = (date.year - today.year) * 12 +
        date.month - today.month + (date.day > today.day ? 1 : 0);
    return FinanceMilestoneEstimate(milestone, date, months);
  }

  static List<FinanceMilestoneEstimate> withinFiveYears(
    Iterable<MilestoneCost> milestones,
    DateTime birth,
    DateTime now,
  ) {
    final end = DateTime(now.year + 5, now.month, now.day);
    return upcoming(milestones, birth, now)
        .where((estimate) => !estimate.date.isAfter(end))
        .toList();
  }
}
