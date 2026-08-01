/// Datenmodell für KI-entdeckte Events aus dem Internet.
/// Vom AI-Agent gefüllt, auf der Discover-Karte angezeigt.

enum DiscoveredEventCategory {
  theater,
  kino,
  sport,
  musik,
  natur,
  basteln,
  familienzentrum,
  museum,
  festival,
  spielplatz,
  sonstiges,
}

enum DiscoveredEventSource {
  kiAgent,    // Vom KI-Agent generiert/zusammengeführt
  manual,     // Manuell von Eltern erstellt
}

class DiscoveredEvent {
  final String id;
  final String title;
  final String description;
  final DiscoveredEventCategory category;
  final List<String> ageLabels; // z.B. ["0–3 Jahre", "4–6 Jahre"]
  final String location;
  final String cityHint;
  final double? latitude;
  final double? longitude;
  final DateTime? eventDate;
  final bool isRecurring;
  final String? recurringNote; // z.B. "Jeden Samstag 10–12 Uhr"
  final String? eventTimeRange; // z.B. "10:00 – 12:30 Uhr"
  final String? price;         // z.B. "kostenlos", "5 €"
  final String? url;           // Link zur Original-Quelle
  final String? organizer;     // Veranstalter/Institution
  final String? imageUrl;
  final DiscoveredEventSource source;
  final DateTime discoveredAt;
  final int interestCount;     // Wer ist interessiert (lokal gezählt)

  const DiscoveredEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.ageLabels,
    required this.location,
    required this.cityHint,
    this.latitude,
    this.longitude,
    this.eventDate,
    this.isRecurring = false,
    this.recurringNote,
    this.eventTimeRange,
    this.price,
    this.url,
    this.organizer,
    this.imageUrl,
    this.source = DiscoveredEventSource.kiAgent,
    required this.discoveredAt,
    this.interestCount = 0,
  });

  DiscoveredEvent copyWith({int? interestCount}) => DiscoveredEvent(
        id: id,
        title: title,
        description: description,
        category: category,
        ageLabels: ageLabels,
        location: location,
        cityHint: cityHint,
        latitude: latitude,
        longitude: longitude,
        eventDate: eventDate,
        isRecurring: isRecurring,
        recurringNote: recurringNote,
        eventTimeRange: eventTimeRange,
        price: price,
        url: url,
        organizer: organizer,
        imageUrl: imageUrl,
        source: source,
        discoveredAt: discoveredAt,
        interestCount: interestCount ?? this.interestCount,
      );

  String get categoryLabel {
    switch (category) {
      case DiscoveredEventCategory.theater:
        return 'Theater';
      case DiscoveredEventCategory.kino:
        return 'Kino';
      case DiscoveredEventCategory.sport:
        return 'Sport';
      case DiscoveredEventCategory.musik:
        return 'Musik';
      case DiscoveredEventCategory.natur:
        return 'Natur & Outdoor';
      case DiscoveredEventCategory.basteln:
        return 'Basteln & Kreativ';
      case DiscoveredEventCategory.familienzentrum:
        return 'Familienzentrum';
      case DiscoveredEventCategory.museum:
        return 'Museum';
      case DiscoveredEventCategory.festival:
        return 'Festival';
      case DiscoveredEventCategory.spielplatz:
        return 'Spielplatz';
      case DiscoveredEventCategory.sonstiges:
        return 'Sonstiges';
    }
  }
}
