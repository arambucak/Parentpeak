/// Ein „Moment" in der Familien-Community: Eltern teilen einen Alltags-Moment
/// (Text + optional mehrere Bilder) mit anderen Familien.
///
/// Sichtbarkeit (serverseitig durchgesetzt):
///   - 'public'  → alle in der Community
///   - 'friends' → nur verbundene Familien (Standard)
///   - 'private' → nur ich
///
/// Bewusst OHNE erkennbare Kinderfotos (Produktentscheidung, Kinderschutz) —
/// der Hinweis dazu erscheint beim Erstellen.
class Moment {
  final String id;
  final String authorUserId;
  final String authorName;
  final String text;
  final List<String> imageUrls;
  final String visibility;
  final DateTime? createdAt;

  final int heartCount;
  final int commentCount;
  final bool heartedByMe;
  final bool isMine;

  const Moment({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    this.text = '',
    this.imageUrls = const [],
    this.visibility = 'friends',
    this.createdAt,
    this.heartCount = 0,
    this.commentCount = 0,
    this.heartedByMe = false,
    this.isMine = false,
  });

  /// Kopie mit überschriebenen Feldern (für optimistische UI-Updates).
  Moment copyWith({
    int? heartCount,
    int? commentCount,
    bool? heartedByMe,
  }) {
    return Moment(
      id: id,
      authorUserId: authorUserId,
      authorName: authorName,
      text: text,
      imageUrls: imageUrls,
      visibility: visibility,
      createdAt: createdAt,
      heartCount: heartCount ?? this.heartCount,
      commentCount: commentCount ?? this.commentCount,
      heartedByMe: heartedByMe ?? this.heartedByMe,
      isMine: isMine,
    );
  }

  factory Moment.fromJson(Map<String, dynamic> j) {
    final name = (j['authorName'] as String?)?.trim();
    return Moment(
      id: j['id'] as String? ?? '',
      authorUserId: j['authorUserId'] as String? ?? '',
      authorName: (name != null && name.isNotEmpty) ? name : 'Familie',
      text: j['text'] as String? ?? '',
      imageUrls: (j['imageUrls'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      visibility: j['visibility'] as String? ?? 'friends',
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      heartCount: (j['heartCount'] as num?)?.toInt() ?? 0,
      commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
      heartedByMe: j['heartedByMe'] == true,
      isMine: j['isMine'] == true,
    );
  }
}

/// Ein Kommentar unter einem Moment.
class MomentComment {
  final String id;
  final String momentId;
  final String authorUserId;
  final String authorName;
  final String text;
  final DateTime? createdAt;
  final bool isMine;

  const MomentComment({
    required this.id,
    required this.momentId,
    required this.authorUserId,
    required this.authorName,
    required this.text,
    this.createdAt,
    this.isMine = false,
  });

  factory MomentComment.fromJson(Map<String, dynamic> j) {
    final name = (j['authorName'] as String?)?.trim();
    return MomentComment(
      id: j['id'] as String? ?? '',
      momentId: j['momentId'] as String? ?? '',
      authorUserId: j['authorUserId'] as String? ?? '',
      authorName: (name != null && name.isNotEmpty) ? name : 'Familie',
      text: j['text'] as String? ?? '',
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      isMine: j['isMine'] == true,
    );
  }
}
