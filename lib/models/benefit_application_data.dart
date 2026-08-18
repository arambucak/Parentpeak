/// Datenmodell für den Antragshelfer.
///
/// Pro Sozialleistung: Unterlagen-Checkliste, Schritt-für-Schritt-Anleitung,
/// Links, KI-Prompt-Vorlage, Erinnerungs-Info.

class BenefitApplicationData {
  final String benefitId;
  final String benefitName;
  final String emoji;
  final String countryCode;

  /// Schritt 1: Welche Unterlagen brauche ich?
  final List<RequiredDocument> documents;

  /// Schritt 2: Anleitung
  final List<ApplicationStep> steps;

  /// Direkter Link zum Online-Antrag (wenn vorhanden)
  final String? onlineApplicationUrl;

  /// Zuständige Stelle
  final String responsibleAuthority;

  /// Durchschnittliche Bearbeitungszeit
  final String processingTime;

  /// Wann muss man den Folgeantrag stellen?
  final String? renewalNote;

  /// KI-Prompt für Textvorlagen (z.B. Begründung)
  final String? aiTemplatePrompt;

  /// Tipp für Eltern
  final String? proTip;

  const BenefitApplicationData({
    required this.benefitId,
    required this.benefitName,
    required this.emoji,
    required this.countryCode,
    required this.documents,
    required this.steps,
    this.onlineApplicationUrl,
    required this.responsibleAuthority,
    required this.processingTime,
    this.renewalNote,
    this.aiTemplatePrompt,
    this.proTip,
  });
}

class RequiredDocument {
  final String name;
  final String? whereToGet;
  final bool isOptional;

  const RequiredDocument({
    required this.name,
    this.whereToGet,
    this.isOptional = false,
  });
}

class ApplicationStep {
  final int stepNumber;
  final String title;
  final String description;
  final String? url;

  const ApplicationStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.url,
  });
}
