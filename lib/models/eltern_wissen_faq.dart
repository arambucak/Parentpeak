/// Eine GfK-basierte Eltern-FAQ Antwort.
class ElternWissenEntry {
  final String id;
  final String question;
  final String akut;         // 1 Satz für den akuten Moment
  final String bedürfnis;   // Was steckt dahinter?
  final String gfkSatz;      // Konkreter GfK-Satz zum Nachsprechen
  final List<String> aktion; // 2-3 Handlungsschritte
  final String ermutigung;   // "Du bist nicht schuld" etc.
  final int minAge;          // Ab Alter relevant (Jahre)
  final int maxAge;          // Bis Alter relevant (Jahre)
  final List<String> tags;   // Suchbegriffe / Synonyme
  final String category;     // schlafen, essen, wut, grenzen, etc.

  const ElternWissenEntry({
    required this.id,
    required this.question,
    required this.akut,
    required this.bedürfnis,
    required this.gfkSatz,
    required this.aktion,
    required this.ermutigung,
    required this.minAge,
    required this.maxAge,
    required this.tags,
    required this.category,
  });
}
