enum EventCategory { sports, outdoor, education, arts, socialGathering, other }

enum AgeGroup { infant, toddler, preschool, elementary, teenager, mixed }

enum ParticipationStatus { pending, approved, declined, cancelled, interested }

enum ParticipationMode { legacyApproval, direct, interest }

enum EventStatus { active, completed, cancelled }

enum EventVisibility { privateOnly, familyCircle, inviteOnly, publicNearby }

class MeetupEvent {
  final String id;
  final String hosterId;
  final String title;
  final String description;
  final EventCategory category;
  final List<AgeGroup> ageGroups;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime eventDate;
  final DateTime createdAt;
  final DateTime? paymentDate;
  final int maxParticipants;
  final int currentParticipants;
  final String photoUrl;
  final EventStatus status;
  final double? price; // Preis für die Veröffentlichung
  final EventVisibility visibility;
  final double? shareRadiusKm;
  final List<String> invitedUserIds;
  final DateTime? inviteCodeExpiresAt;

  /// Serien-ID eines wiederkehrenden Angebots. Mehrere Termine mit derselben
  /// seriesId gehören zusammen; Eltern können der Serie folgen (Issue #47).
  final String? seriesId;
    final ParticipationMode participationMode;
    final String? externalUrl;

  MeetupEvent({
    required this.id,
    required this.hosterId,
    required this.title,
    required this.description,
    required this.category,
    required this.ageGroups,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.eventDate,
    required this.createdAt,
    this.paymentDate,
    required this.maxParticipants,
    this.currentParticipants = 0,
    required this.photoUrl,
    this.status = EventStatus.active,
    this.price,
    this.visibility = EventVisibility.publicNearby,
    this.shareRadiusKm = 25,
    this.invitedUserIds = const [],
    this.inviteCodeExpiresAt,
    this.seriesId,
        this.participationMode = ParticipationMode.legacyApproval,
        this.externalUrl,
  });

    bool get isSharedOffer => participationMode == ParticipationMode.interest;
    bool get hasCapacity => !isSharedOffer && maxParticipants > 0;
    bool get isFull => hasCapacity && currentParticipants >= maxParticipants;
  bool get isPaid => paymentDate != null;
    int get spotsAvailable => (maxParticipants - currentParticipants).clamp(0, maxParticipants);

    Uri? get organizerUri {
        final uri = Uri.tryParse(externalUrl ?? '');
        return uri != null && ['http', 'https'].contains(uri.scheme) &&
                uri.host.isNotEmpty && uri.userInfo.isEmpty ? uri : null;
    }

  factory MeetupEvent.fromJson(Map<String, dynamic> json) => MeetupEvent(
        id: json['id'] as String,
        hosterId: json['hosterId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: EventCategory.values.byName(json['category'] as String),
        ageGroups: (json['ageGroups'] as List<dynamic>)
            .map((e) => AgeGroup.values.byName(e as String))
            .toList(),
        location: json['location'] as String,
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        eventDate: DateTime.parse(json['eventDate'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        paymentDate: json['paymentDate'] != null
            ? DateTime.parse(json['paymentDate'] as String)
            : null,
        maxParticipants: json['maxParticipants'] as int,
        currentParticipants: json['currentParticipants'] as int? ?? 0,
        photoUrl: json['photoUrl'] as String,
        status: EventStatus.values.byName(json['status'] as String),
        price: json['price'] as double?,
        visibility: EventVisibility.values.byName(
            json['visibility'] as String? ?? EventVisibility.publicNearby.name),
        shareRadiusKm: (json['shareRadiusKm'] as num?)?.toDouble(),
        invitedUserIds: (json['invitedUserIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        inviteCodeExpiresAt: json['inviteCodeExpiresAt'] != null
            ? DateTime.parse(json['inviteCodeExpiresAt'] as String)
            : null,
        seriesId: json['seriesId'] as String?,
        participationMode: ParticipationMode.values.byName(
            json['participationMode'] as String? ?? 'legacyApproval'),
        externalUrl: json['externalUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hosterId': hosterId,
        'title': title,
        'description': description,
        'category': category.name,
        'ageGroups': ageGroups.map((e) => e.name).toList(),
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'eventDate': eventDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'paymentDate': paymentDate?.toIso8601String(),
        'maxParticipants': maxParticipants,
        'currentParticipants': currentParticipants,
        'photoUrl': photoUrl,
        'status': status.name,
        'price': price,
        'visibility': visibility.name,
        'shareRadiusKm': shareRadiusKm,
        'invitedUserIds': invitedUserIds,
        'inviteCodeExpiresAt': inviteCodeExpiresAt?.toIso8601String(),
        'seriesId': seriesId,
        'participationMode': participationMode.name,
        'externalUrl': externalUrl,
      };
}
