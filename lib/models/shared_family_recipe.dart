/// Ein geteiltes Familien-Rezept (Phase 3a).
///
/// Sichtbarkeit:
///   - 'public'  -> Fuer alle Familien
///   - 'friends' -> Nur meine Freunde (Standard)
///   - 'private' -> Nur fuer mich
///
/// Die Reaktionen sind bewusst warm und ohne Wettbewerb gehalten:
///   - "Das kochen wir nach!"  (cook)
///   - "Hat geschmeckt!"       (tasty)
class SharedFamilyRecipe {
  final String id;
  final String authorUserId;
  final String authorName;
  final String title;
  final String description;
  final String photoUrl;
  final List<String> ingredients;
  final List<String> steps;
  final int prepMinutes;
  final String visibility;
  final List<String> tags;
  final DateTime? createdAt;

  final int cookCount;
  final int tastyCount;
  final bool myCook;
  final bool myTasty;
  final bool isMine;

  const SharedFamilyRecipe({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    required this.title,
    this.description = '',
    this.photoUrl = '',
    this.ingredients = const [],
    this.steps = const [],
    this.prepMinutes = 0,
    this.visibility = 'friends',
    this.tags = const [],
    this.createdAt,
    this.cookCount = 0,
    this.tastyCount = 0,
    this.myCook = false,
    this.myTasty = false,
    this.isMine = false,
  });

  factory SharedFamilyRecipe.fromJson(Map<String, dynamic> j) {
    List<String> asStrings(dynamic v) => (v as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return SharedFamilyRecipe(
      id: j['id'] as String? ?? '',
      authorUserId: j['authorUserId'] as String? ?? '',
      authorName: (j['authorName'] as String?)?.trim().isNotEmpty == true
          ? (j['authorName'] as String).trim()
          : 'Familie',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      photoUrl: j['photoUrl'] as String? ?? '',
      ingredients: asStrings(j['ingredients']),
      steps: asStrings(j['steps']),
      prepMinutes: (j['prepMinutes'] as num?)?.toInt() ?? 0,
      visibility: j['visibility'] as String? ?? 'friends',
      tags: asStrings(j['tags']),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
      cookCount: (j['cookCount'] as num?)?.toInt() ?? 0,
      tastyCount: (j['tastyCount'] as num?)?.toInt() ?? 0,
      myCook: j['myCook'] == true,
      myTasty: j['myTasty'] == true,
      isMine: j['isMine'] == true,
    );
  }

  /// Lesbares Label fuer die Sichtbarkeit (fuer die Anzeige).
  String get visibilityLabel {
    switch (visibility) {
      case 'public':
        return 'Für alle Familien';
      case 'private':
        return 'Nur für mich';
      case 'friends':
      default:
        return 'Nur meine Freunde';
    }
  }
}
