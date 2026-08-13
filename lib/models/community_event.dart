import 'dart:convert';

/// Einheitliches Event-Model für KI-Events UND Community-Events.
///
/// Sicherheits-Features:
///   - [isPrivateAddress] verhindert Anzeige der exakten Adresse
///   - [flagCount] + [isHidden] für Community-Moderation
///   - [creatorType] unterscheidet Eltern-Tipp vs. Veranstalter
///   - Events nach [eventDate] werden automatisch ausgeblendet
///
/// Qualitaets-Features:
///   - Pflichtfelder: title, description, location, eventDate, ageGroups
///   - [isVerified] für gepruefts Partner-Events
///   - [source] zeigt woher das Event kommt (KI vs Community)

// ─── Enums ───────────────────────────────────────────────────────────────────

enum EventCategory {
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
  elternTreff,
  kurs,
  ausflug,
  flohmarkt,
  sonstiges;

  String get label {
    switch (this) {
      case EventCategory.theater:
        return '\u{1F3AD} Theater';
      case EventCategory.kino:
        return '\u{1F3AC} Kino';
      case EventCategory.sport:
        return '\u{26BD} Sport & Bewegung';
      case EventCategory.musik:
        return '\u{1F3B5} Musik & Konzerte';
      case EventCategory.natur:
        return '\u{1F333} Natur & Outdoor';
      case EventCategory.basteln:
        return '\u{2702}\u{FE0F} Basteln & Kreativ';
      case EventCategory.familienzentrum:
        return '\u{1F3E0} Familienzentrum';
      case EventCategory.museum:
        return '\u{1F3DB}\u{FE0F} Museum & Ausstellung';
      case EventCategory.festival:
        return '\u{1F389} Festival & Markt';
      case EventCategory.spielplatz:
        return '\u{1F3A0} Spielplatz';
      case EventCategory.elternTreff:
        return '\u{2615} Eltern-Treff';
      case EventCategory.kurs:
        return '\u{1F4DA} Kurs & Workshop';
      case EventCategory.ausflug:
        return '\u{1F697} Ausflug';
      case EventCategory.flohmarkt:
        return '\u{1F4E6} Flohmarkt';
      case EventCategory.sonstiges:
        return '\u{2728} Sonstiges';
    }
  }

  String get emoji {
    return label.split(' ').first;
  }
}

enum EventAgeGroup {
  baby,       // 0-1 Jahre
  kleinkind,  // 1-3 Jahre
  kita,       // 3-6 Jahre
  grundschule,// 6-10 Jahre
  teenie,     // 10-16 Jahre
  alle;       // Alle Altersgruppen

  String get label {
    switch (this) {
      case EventAgeGroup.baby:
        return '\u{1F476} 0\u20131 J.';
      case EventAgeGroup.kleinkind:
        return '\u{1F6B6} 1\u20133 J.';
      case EventAgeGroup.kita:
        return '\u{1F3A8} 3\u20136 J.';
      case EventAgeGroup.grundschule:
        return '\u{1F4DA} 6\u201310 J.';
      case EventAgeGroup.teenie:
        return '\u{1F3AE} 10\u201316 J.';
      case EventAgeGroup.alle:
        return '\u{1F46A} Alle';
    }
  }
}

enum EventVenue {
  indoor,
  outdoor,
  beides;

  String get label {
    switch (this) {
      case EventVenue.indoor:
        return '\u{1F3E0} Indoor';
      case EventVenue.outdoor:
        return '\u{2600}\u{FE0F} Outdoor';
      case EventVenue.beides:
        return '\u{1F504} Indoor & Outdoor';
    }
  }
}

enum EventSource {
  kiAgent,     // Vom KI-Agent generiert
  community,   // Von Eltern eingetragen
  partner,     // Von verifiziertem Partner eingetragen
}

enum CreatorType {
  eltern,      // Privatperson / Eltern-Tipp
  verein,      // Verein / Eltern-Initiative
  institution, // Kita, Schule, Familienzentrum
  unternehmen, // Kommerzieller Anbieter
}

// ─── Accessibility Tags ──────────────────────────────────────────────────────

enum AccessibilityTag {
  barrierefrei,
  wickelraum,
  kinderwagen,
  parkplaetze,
  oepnv,
  stillen;

  String get label {
    switch (this) {
      case AccessibilityTag.barrierefrei:
        return '\u{267F} Barrierefrei';
      case AccessibilityTag.wickelraum:
        return '\u{1F6BC} Wickelraum';
      case AccessibilityTag.kinderwagen:
        return '\u{1F6D2} Kinderwagenfreundlich';
      case AccessibilityTag.parkplaetze:
        return '\u{1F697} Parkplaetze';
      case AccessibilityTag.oepnv:
        return '\u{1F687} OEPNV erreichbar';
      case AccessibilityTag.stillen:
        return '\u{1F930} Stillfreundlich';
    }
  }
}

// ─── Haupt-Model ─────────────────────────────────────────────────────────────

class CommunityEvent {
  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final List<EventAgeGroup> ageGroups;
  final EventVenue venue;
  final String location;         // Adresse oder Ortsname
  final String city;             // Stadt/Stadtteil für Suche
  final double? lat;
  final double? lon;
  final bool isPrivateAddress;   // Wenn true: nur Stadtteil anzeigen
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final bool isRecurring;
  final String? recurringNote;   // z.B. "Jeden Samstag 10-12 Uhr"
  final String? rainPlan;        // Bei Regen: faellt aus / Alternative
  final String price;            // "kostenlos" oder "5 EUR" etc.
  final bool isFree;
  final String? url;             // Link zur Quelle/Veranstalter
  final String? imageUrl;
  final String organizer;        // Name des Veranstalters
  final CreatorType creatorType;
  final String? contactName;     // Ansprechpartner (nur bei Teilnahme sichtbar)
  final String? contactPhone;    // Telefon (nur bei Teilnahme sichtbar)
  final String? contactEmail;
  final List<AccessibilityTag> accessibility;
  final String eventLanguage;    // "de", "tr", "en" etc.
  final EventSource source;
  final bool isVerified;         // Verifizierter Partner
  final String creatorId;        // User-ID des Erstellers
  final DateTime createdAt;
  final int interestCount;       // Familien die Interesse zeigen
  final int flagCount;           // Meldungen
  final bool isHidden;           // Versteckt nach zu vielen Meldungen
  final int maxPerDay;           // Rate-Limit Tracking

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.ageGroups,
    this.venue = EventVenue.beides,
    required this.location,
    required this.city,
    this.lat,
    this.lon,
    this.isPrivateAddress = false,
    required this.eventDate,
    this.eventEndDate,
    this.isRecurring = false,
    this.recurringNote,
    this.rainPlan,
    this.price = 'kostenlos',
    this.isFree = true,
    this.url,
    this.imageUrl,
    required this.organizer,
    this.creatorType = CreatorType.eltern,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.accessibility = const [],
    this.eventLanguage = 'de',
    this.source = EventSource.community,
    this.isVerified = false,
    required this.creatorId,
    required this.createdAt,
    this.interestCount = 0,
    this.flagCount = 0,
    this.isHidden = false,
    this.maxPerDay = 3,
  });

  // ─── Computed Properties ──────────────────────────────────────────────────

  /// Event ist in der Vergangenheit (soll ausgeblendet werden)
  bool get isExpired =>
      !isRecurring && eventDate.isBefore(DateTime.now());

  /// Soll angezeigt werden (nicht expired, nicht hidden, nicht zu viele Flags)
  bool get isVisible =>
      !isHidden && !isExpired && flagCount < 3;

  /// Sicherer Ort-Text (versteckt private Adressen)
  String get safeLocation {
    if (isPrivateAddress) return '$city (privater Ort)';
    return location;
  }

  /// Preis-Display
  String get priceDisplay => isFree ? 'Kostenlos' : price;

  /// Source-Label für UI
  String get sourceLabel {
    switch (source) {
      case EventSource.kiAgent:
        return 'KI-Vorschlag';
      case EventSource.community:
        return 'Eltern-Tipp';
      case EventSource.partner:
        return isVerified ? 'Verifiziert \u{2714}' : 'Partner';
    }
  }

  // ─── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'ageGroups': ageGroups.map((a) => a.name).toList(),
        'venue': venue.name,
        'location': location,
        'city': city,
        'lat': lat,
        'lon': lon,
        'isPrivateAddress': isPrivateAddress,
        'eventDate': eventDate.toIso8601String(),
        'eventEndDate': eventEndDate?.toIso8601String(),
        'isRecurring': isRecurring,
        'recurringNote': recurringNote,
        'rainPlan': rainPlan,
        'price': price,
        'isFree': isFree,
        'url': url,
        'imageUrl': imageUrl,
        'organizer': organizer,
        'creatorType': creatorType.name,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'accessibility': accessibility.map((a) => a.name).toList(),
        'eventLanguage': eventLanguage,
        'source': source.name,
        'isVerified': isVerified,
        'creatorId': creatorId,
        'createdAt': createdAt.toIso8601String(),
        'interestCount': interestCount,
        'flagCount': flagCount,
        'isHidden': isHidden,
      };

  factory CommunityEvent.fromJson(Map<String, dynamic> j) => CommunityEvent(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: _parseCategory(j['category'] as String?),
        ageGroups: _parseAgeGroups(j['ageGroups']),
        venue: _parseVenue(j['venue'] as String?),
        location: j['location'] as String? ?? '',
        city: j['city'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        isPrivateAddress: j['isPrivateAddress'] as bool? ?? false,
        eventDate: DateTime.tryParse(j['eventDate'] as String? ?? '') ??
            DateTime.now(),
        eventEndDate: j['eventEndDate'] != null
            ? DateTime.tryParse(j['eventEndDate'] as String)
            : null,
        isRecurring: j['isRecurring'] as bool? ?? false,
        recurringNote: j['recurringNote'] as String?,
        rainPlan: j['rainPlan'] as String?,
        price: j['price'] as String? ?? 'kostenlos',
        isFree: j['isFree'] as bool? ?? true,
        url: j['url'] as String?,
        imageUrl: j['imageUrl'] as String?,
        organizer: j['organizer'] as String? ?? '',
        creatorType: _parseCreatorType(j['creatorType'] as String?),
        contactName: j['contactName'] as String?,
        contactPhone: j['contactPhone'] as String?,
        contactEmail: j['contactEmail'] as String?,
        accessibility: _parseAccessibility(j['accessibility']),
        eventLanguage: j['eventLanguage'] as String? ?? 'de',
        source: _parseSource(j['source'] as String?),
        isVerified: j['isVerified'] as bool? ?? false,
        creatorId: j['creatorId'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        interestCount: j['interestCount'] as int? ?? 0,
        flagCount: j['flagCount'] as int? ?? 0,
        isHidden: j['isHidden'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory CommunityEvent.fromJsonString(String s) =>
      CommunityEvent.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // ─── Parse Helpers ────────────────────────────────────────────────────────

  static EventCategory _parseCategory(String? raw) {
    if (raw == null) return EventCategory.sonstiges;
    try {
      return EventCategory.values.byName(raw);
    } catch (_) {
      return EventCategory.sonstiges;
    }
  }

  static List<EventAgeGroup> _parseAgeGroups(dynamic raw) {
    if (raw == null) return [EventAgeGroup.alle];
    if (raw is List) {
      return raw
          .map((e) {
            try {
              return EventAgeGroup.values.byName(e.toString());
            } catch (_) {
              return EventAgeGroup.alle;
            }
          })
          .toSet()
          .toList();
    }
    return [EventAgeGroup.alle];
  }

  static EventVenue _parseVenue(String? raw) {
    if (raw == null) return EventVenue.beides;
    try {
      return EventVenue.values.byName(raw);
    } catch (_) {
      return EventVenue.beides;
    }
  }

  static CreatorType _parseCreatorType(String? raw) {
    if (raw == null) return CreatorType.eltern;
    try {
      return CreatorType.values.byName(raw);
    } catch (_) {
      return CreatorType.eltern;
    }
  }

  static EventSource _parseSource(String? raw) {
    if (raw == null) return EventSource.community;
    try {
      return EventSource.values.byName(raw);
    } catch (_) {
      return EventSource.community;
    }
  }

  static List<AccessibilityTag> _parseAccessibility(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) {
            try {
              return AccessibilityTag.values.byName(e.toString());
            } catch (_) {
              return null;
            }
          })
          .whereType<AccessibilityTag>()
          .toList();
    }
    return [];
  }
}
