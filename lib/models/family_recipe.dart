/// Ein KI-generiertes Familien-Rezept.
class FamilyRecipe {
  final String id;
  final String title;
  final String description;
  final int prepMinutes;
  final double costPerPortion;
  final int portions;
  final int minChildAge; // Ab welchem Alter geeignet (in Jahren)
  final List<String> ingredients;
  final List<String> steps;
  final List<String> allergensFree; // Frei von: nuesse, laktose, etc.
  final String season; // fruehling, sommer, herbst, winter
  final String tip; // Eltern-Tipp (picky eater, gemeinsam kochen, etc.)
  final bool isSaved;

  const FamilyRecipe({
    required this.id,
    required this.title,
    required this.description,
    required this.prepMinutes,
    required this.costPerPortion,
    this.portions = 4,
    required this.minChildAge,
    required this.ingredients,
    required this.steps,
    this.allergensFree = const [],
    required this.season,
    this.tip = '',
    this.isSaved = false,
  });

  String get timeLabel => '$prepMinutes Min.';
  String get costLabel => '~${costPerPortion.toStringAsFixed(2)}\u{20AC}/Portion';
  String get ageLabel => minChildAge == 0 ? 'ab 6 Mon.' : 'ab $minChildAge J.';

  factory FamilyRecipe.fromJson(Map<String, dynamic> j) => FamilyRecipe(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        prepMinutes: j['prepMinutes'] as int? ?? 30,
        costPerPortion: (j['costPerPortion'] as num?)?.toDouble() ?? 2.0,
        portions: j['portions'] as int? ?? 4,
        minChildAge: j['minChildAge'] as int? ?? 1,
        ingredients: List<String>.from(j['ingredients'] ?? []),
        steps: List<String>.from(j['steps'] ?? []),
        allergensFree: List<String>.from(j['allergensFree'] ?? []),
        season: j['season'] as String? ?? 'alle',
        tip: j['tip'] as String? ?? '',
        isSaved: j['isSaved'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'prepMinutes': prepMinutes,
        'costPerPortion': costPerPortion,
        'portions': portions,
        'minChildAge': minChildAge,
        'ingredients': ingredients,
        'steps': steps,
        'allergensFree': allergensFree,
        'season': season,
        'tip': tip,
        'isSaved': isSaved,
      };
}
