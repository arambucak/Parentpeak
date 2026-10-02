import 'package:parentpeak/models/meetup_event.dart';

class EventParticipation {
  final String id;
  final String eventId;
  final String userId;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? declinedAt;
  final DateTime? cancelledAt;
  final ParticipationStatus status;

  EventParticipation({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.requestedAt,
    this.approvedAt,
    this.declinedAt,
    this.cancelledAt,
    required this.status,
  });

  bool get isPending => status == ParticipationStatus.pending;
  bool get isApproved => status == ParticipationStatus.approved;
  bool get isDeclined => status == ParticipationStatus.declined;

  factory EventParticipation.fromJson(Map<String, dynamic> json) =>
      EventParticipation(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        userId: json['userId'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        approvedAt: json['approvedAt'] != null
            ? DateTime.parse(json['approvedAt'] as String)
            : null,
        declinedAt: json['declinedAt'] != null
            ? DateTime.parse(json['declinedAt'] as String)
            : null,
        cancelledAt: json['cancelledAt'] != null
            ? DateTime.parse(json['cancelledAt'] as String)
            : null,
        status: ParticipationStatus.values.byName(
          ['accepted', 'attended'].contains(json['status'])
            ? 'approved' : json['status'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'userId': userId,
        'requestedAt': requestedAt.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'declinedAt': declinedAt?.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
        'status': status.name,
      };
}
