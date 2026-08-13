/// Laender-spezifische Finanz-Konfiguration für die Familien-Geld Kachel.
///
/// Jedes Land hat:
/// - Waehrung + Symbol
/// - Liste moeglicher Sozialleistungen
/// - Typische Meilenstein-Kosten für Kinder
/// - Kategorien für den Monats-Schnellcheck

class CountryFinanceConfig {
  final String code;           // "de", "at", "tr", "gb", "generic"
  final String name;           // "Deutschland"
  final String flag;           // Emoji
  final String currency;       // "EUR"
  final String currencySymbol; // "€"
  final List<SocialBenefit> benefits;
  final List<MilestoneCost> milestones;
  final List<MonthlyCategory> categories;

  const CountryFinanceConfig({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.currencySymbol,
    required this.benefits,
    required this.milestones,
    required this.categories,
  });

  /// Formatiert einen Betrag mit Waehrungssymbol.
  String formatAmount(double amount) {
    final rounded = amount.toStringAsFixed(0);
    return '$rounded$currencySymbol';
  }
}

/// Eine Sozialleistung die Familien zustehen koennte.
class SocialBenefit {
  final String id;
  final String name;
  final String description;
  final String? amount;          // z.B. "250€/Kind" oder "bis 292€"
  final String? eligibility;     // Kurze Beschreibung wer Anspruch hat
  final String? url;             // Link zum offiziellen Rechner/Antrag
  final BenefitStatus status;    // Fuer alle, einkommenabhaengig, etc.

  const SocialBenefit({
    required this.id,
    required this.name,
    required this.description,
    this.amount,
    this.eligibility,
    this.url,
    this.status = BenefitStatus.checkRequired,
  });
}

enum BenefitStatus {
  universal,       // Jeder bekommt es (z.B. Kindergeld)
  incomeDependent, // Einkommensabhaengig
  checkRequired,   // Muss individuell geprueft werden
}

/// Kosten eines Meilensteins im Kinderleben.
class MilestoneCost {
  final String id;
  final String label;         // z.B. "Schulstart"
  final String emoji;
  final double estimatedCost; // Durchschnittliche Kosten
  final int childAgeYears;    // Ab welchem Alter relevant
  final String? note;         // z.B. "Ranzen, Stifte, Turnbeutel"

  const MilestoneCost({
    required this.id,
    required this.label,
    required this.emoji,
    required this.estimatedCost,
    required this.childAgeYears,
    this.note,
  });
}

/// Kategorie für den monatlichen Schnellcheck.
class MonthlyCategory {
  final String id;
  final String label;
  final String emoji;
  final double? typicalAmount; // Durchschnitt als Hinweis

  const MonthlyCategory({
    required this.id,
    required this.label,
    required this.emoji,
    this.typicalAmount,
  });
}
