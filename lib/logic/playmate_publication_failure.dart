import 'package:flutter/foundation.dart';

enum PlaymatePublicationFailureReason {
  unauthenticated,
  forbidden,
  invalid,
  rateLimited,
  serverUnavailable,
  network,
  timeout,
  invalidResponse,
  missingUser,
  unknown,
}

class PlaymatePublicationFailure {
  const PlaymatePublicationFailure(this.reason, {this.statusCode});

  factory PlaymatePublicationFailure.fromStatus(int statusCode) {
    final reason = switch (statusCode) {
      400 => PlaymatePublicationFailureReason.invalid,
      401 => PlaymatePublicationFailureReason.unauthenticated,
      403 => PlaymatePublicationFailureReason.forbidden,
      408 => PlaymatePublicationFailureReason.timeout,
      429 => PlaymatePublicationFailureReason.rateLimited,
      >= 500 && < 600 => PlaymatePublicationFailureReason.serverUnavailable,
      _ => PlaymatePublicationFailureReason.unknown,
    };
    return PlaymatePublicationFailure(reason, statusCode: statusCode);
  }

  final PlaymatePublicationFailureReason reason;
  final int? statusCode;

  String get messageKey => switch (reason) {
        PlaymatePublicationFailureReason.unauthenticated =>
          'network_publish_unauthenticated',
        PlaymatePublicationFailureReason.invalid => 'network_publish_invalid',
        PlaymatePublicationFailureReason.serverUnavailable =>
          'network_publish_server_unavailable',
        PlaymatePublicationFailureReason.network ||
        PlaymatePublicationFailureReason.timeout =>
          'network_publish_no_connection',
        _ => 'network_publish_failed',
      };

  String get diagnosticCode =>
      statusCode == null ? reason.name : 'HTTP $statusCode';
}

void logPlaymatePublicationFailure(PlaymatePublicationFailure failure) {
  debugPrint(
    'Playmate publication failed: reason=${failure.reason.name} '
    'status=${failure.statusCode ?? "none"}',
  );
}
