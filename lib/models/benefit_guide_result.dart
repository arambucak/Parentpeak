/// Ergebnis des Familien-Leistungs-Wegweisers.
///
/// WICHTIG: Dies ist Orientierung, KEINE Rechts- oder Finanzberatung. Es werden
/// bewusst keine konkreten Anspruchshöhen zugesagt.
class BenefitGuideResult {
  /// Passende Leistungen für die geschilderte Situation.
  final List<GuideBenefit> matched;

  /// Persönliche Unterlagen-/Aufgaben-Checkliste.
  final List<String> checklist;

  /// Nächste konkrete Schritte.
  final List<String> nextSteps;

  /// Quellen-Links (aus Google-Grounding), falls vorhanden.
  final List<String> sources;

  const BenefitGuideResult({
    this.matched = const [],
    this.checklist = const [],
    this.nextSteps = const [],
    this.sources = const [],
  });

  bool get isEmpty =>
      matched.isEmpty && checklist.isEmpty && nextSteps.isEmpty;
}

/// Eine für die Situation passende Leistung (aus kuratierten Daten + KI-Bezug).
class GuideBenefit {
  /// Kuratierte Benefit-ID, falls die Leistung aus CountryFinanceData stammt
  /// (ermöglicht die Verlinkung zum Antragshelfer). Sonst leer.
  final String benefitId;
  final String name;

  /// Warum diese Leistung zur geschilderten Situation passt.
  final String why;

  /// Zuständige Stelle (Behörde/Amt).
  final String authority;

  /// Offizieller Link zur Prüfung/zum Antrag (falls vorhanden).
  final String url;

  const GuideBenefit({
    this.benefitId = '',
    required this.name,
    this.why = '',
    this.authority = '',
    this.url = '',
  });

  factory GuideBenefit.fromJson(Map<String, dynamic> j) => GuideBenefit(
        benefitId: j['benefitId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        why: j['why'] as String? ?? '',
        authority: j['authority'] as String? ?? '',
        url: j['url'] as String? ?? '',
      );
}
