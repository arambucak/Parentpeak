/// Ein Teilnehmer/Interessent an einem Community-Event.
class EventAttendee {
  final String userId;
  final String displayName;
  final String? message;
  final DateTime createdAt;
  final bool isNetworkContact; // Ist diese Person in meinem Eltern-Netzwerk?

  const EventAttendee({
    required this.userId,
    required this.displayName,
    this.message,
    required this.createdAt,
    this.isNetworkContact = false,
  });

  /// Vorname + Initial (z.B. "Sarah M.")
  String get shortName {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last[0]}.';
    }
    return displayName;
  }

  factory EventAttendee.fromJson(Map<String, dynamic> j) => EventAttendee(
        userId: j['userId'] as String? ?? '',
        displayName: j['displayName'] as String? ?? 'Elternteil',
        message: j['message'] as String?,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        isNetworkContact: j['isNetworkContact'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'isNetworkContact': isNetworkContact,
      };
}

/// Ergebnis des Attendees-Endpoint.
class EventAttendeesResult {
  final List<EventAttendee> attendees;
  final int total;
  final List<EventAttendee> networkContacts; // Gefiltert: nur aus meinem Netzwerk

  const EventAttendeesResult({
    required this.attendees,
    required this.total,
    this.networkContacts = const [],
  });

  bool get hasNetworkContacts => networkContacts.isNotEmpty;
  int get othersCount => total - networkContacts.length;
}
