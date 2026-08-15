class AccessConfig {
  AccessConfig._();

  static const bool isBetaFreeAccess = bool.fromEnvironment(
    'PP_BETA_FREE_ACCESS',
    defaultValue: true,
  );

  static const int postLaunchTrialDays = 30;

  static const String _publicLaunchDateRaw = String.fromEnvironment(
    'PP_PUBLIC_LAUNCH_DATE',
    defaultValue: '',
  );

  static DateTime? get publicLaunchDate {
    if (_publicLaunchDateRaw.isEmpty) return null;
    return DateTime.tryParse(_publicLaunchDateRaw)?.toUtc();
  }

  static DateTime trialStartsAt(
    DateTime registeredAt, {
    DateTime? launchDate,
  }) {
    final registration = registeredAt.toUtc();
    final launch = launchDate?.toUtc() ?? publicLaunchDate;
    if (launch != null && registration.isBefore(launch)) return launch;
    return registration;
  }

  static DateTime trialEndsAt(
    DateTime registeredAt, {
    DateTime? launchDate,
  }) =>
      trialStartsAt(
        registeredAt,
        launchDate: launchDate,
      ).add(const Duration(days: postLaunchTrialDays));

  static int trialDaysRemaining(
    DateTime registeredAt, {
    DateTime? now,
    DateTime? launchDate,
    bool? betaFreeAccess,
  }) {
    if (betaFreeAccess ?? isBetaFreeAccess) return 0;
    final remaining = trialEndsAt(
      registeredAt,
      launchDate: launchDate,
    ).difference(
      (now ?? DateTime.now()).toUtc(),
    );
    if (remaining.isNegative) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }
}