class ReportReasons {
  const ReportReasons._();

  static const keys = [
    'child_safety',
    'sexual_content',
    'violence_threat',
    'self_harm',
    'harassment',
    'spam',
    'fraud',
    'inappropriate',
    'misinformation',
    'other',
  ];

  // Display only; moderation severity is always determined by the server.
  static bool needsAttention(String reason) => keys.take(4).contains(reason);

  static String canonical(String reason) => switch (reason) {
        'insult' || 'hostile' => 'harassment',
        'fake' => 'fraud',
        'false_info' => 'misinformation',
        'unsafe' => 'inappropriate',
        _ => reason,
      };
}
