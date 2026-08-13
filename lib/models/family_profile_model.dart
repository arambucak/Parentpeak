import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Familien-Profil für "Spielfreunde finden".
class FamilyMatchProfile {
  final String displayName;
  final String district;
  final List<ChildEntry> children;
  final List<String> languages;
  final String familyForm;
  final String? familyFormCustom;
  final List<String> values;
  final String? valuesCustom;
  final List<String> lookingFor;
  final String? lookingForCustom;
  final List<String> availDays;
  final List<String> availTimes;
  final String? availCustom;
  final List<String> specials;
  final String? specialsCustom;
  final String bio;
  final bool hasPhoto;
  final DateTime createdAt;

  const FamilyMatchProfile({
    required this.displayName,
    required this.district,
    required this.children,
    required this.languages,
    required this.familyForm,
    this.familyFormCustom,
    required this.values,
    this.valuesCustom,
    required this.lookingFor,
    this.lookingForCustom,
    this.availDays = const [],
    this.availTimes = const [],
    this.availCustom,
    this.specials = const [],
    this.specialsCustom,
    this.bio = '',
    this.hasPhoto = false,
    required this.createdAt,
  });

  // Legacy compatibility: single availability string
  String get availability {
    if (availTimes.isNotEmpty) return availTimes.first;
    return 'flexibel';
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'district': district,
        'children': children.map((c) => c.toJson()).toList(),
        'languages': languages,
        'familyForm': familyForm,
        'familyFormCustom': familyFormCustom,
        'values': values,
        'valuesCustom': valuesCustom,
        'lookingFor': lookingFor,
        'lookingForCustom': lookingForCustom,
        'availDays': availDays,
        'availTimes': availTimes,
        'availCustom': availCustom,
        'specials': specials,
        'specialsCustom': specialsCustom,
        'bio': bio,
        'hasPhoto': hasPhoto,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FamilyMatchProfile.fromJson(Map<String, dynamic> j) =>
      FamilyMatchProfile(
        displayName: j['displayName'] ?? '',
        district: j['district'] ?? '',
        children: ((j['children'] as List?) ?? [])
            .map((c) => ChildEntry.fromJson(c))
            .toList(),
        languages: List<String>.from(j['languages'] ?? []),
        familyForm: j['familyForm'] ?? '',
        familyFormCustom: j['familyFormCustom'],
        values: List<String>.from(j['values'] ?? []),
        valuesCustom: j['valuesCustom'],
        lookingFor: List<String>.from(j['lookingFor'] ?? []),
        lookingForCustom: j['lookingForCustom'],
        availDays: List<String>.from(j['availDays'] ?? []),
        availTimes: List<String>.from(j['availTimes'] ?? []),
        availCustom: j['availCustom'],
        specials: List<String>.from(j['specials'] ?? []),
        specialsCustom: j['specialsCustom'],
        bio: j['bio'] ?? '',
        hasPhoto: j['hasPhoto'] ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );

  static Future<FamilyMatchProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('spielfreunde.profile');
    if (raw == null || raw.isEmpty) return null;
    try {
      return FamilyMatchProfile.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spielfreunde.profile', jsonEncode(toJson()));
  }
}

class ChildEntry {
  final String name;
  final int
      ageMonths; // Alter in Monaten für Babys, in Jahren * 12 für Größere
  final String? gender; // maennlich, weiblich, divers, null = keine Angabe
  final List<String> interests;
  final String? interestsCustom;

  const ChildEntry({
    required this.name,
    required this.ageMonths,
    this.gender,
    this.interests = const [],
    this.interestsCustom,
  });

  /// Menschlich-lesbare Altersanzeige
  String get ageDisplay {
    if (ageMonths < 12) return '$ageMonths Mon.';
    final years = ageMonths ~/ 12;
    final months = ageMonths % 12;
    if (months == 0) return '$years J.';
    return '$years J. $months M.';
  }

  // Legacy: age in years (rounded)
  int get age => (ageMonths / 12).round().clamp(0, 18);

  Map<String, dynamic> toJson() => {
        'name': name,
        'ageMonths': ageMonths,
        'gender': gender,
        'interests': interests,
        'interestsCustom': interestsCustom,
      };

  factory ChildEntry.fromJson(Map<String, dynamic> j) => ChildEntry(
        name: j['name'] ?? '',
        ageMonths: j['ageMonths'] ?? ((j['age'] ?? 0) * 12),
        gender: j['gender'],
        interests: List<String>.from(j['interests'] ?? []),
        interestsCustom: j['interestsCustom'],
      );
}

/// Alle Optionen für das Profil-Formular.
class MatchOptions {
  // ─── FAMILIENFORMEN ───────────────────────────────────────────────────────
  static const List<String> familyForms = [
    'kernfamilie',
    'alleinerziehend',
    'patchwork',
    'regenbogen',
    'grossfamilie',
    'co_parenting',
    'pflegefamilie',
    'grosseltern',
    'wg_familie',
  ];
  static const Map<String, String> familyFormLabels = {
    'kernfamilie': '\u{1F46A} Kernfamilie',
    'alleinerziehend': '\u{1F4AA} Alleinerziehend',
    'patchwork': '\u{1F9E9} Patchwork',
    'regenbogen': '\u{1F308} Regenbogenfamilie',
    'grossfamilie': '\u{1F3E0} Grossfamilie',
    'co_parenting': '\u{1F91D} Co-Parenting',
    'pflegefamilie': '\u{2764}\u{FE0F} Pflegefamilie',
    'grosseltern': '\u{1F9D3} Grosseltern-Haushalt',
    'wg_familie': '\u{1F3E1} Familien-WG',
  };

  // ─── WERTE & ERZIEHUNGSSTIL ───────────────────────────────────────────────
  static const List<String> valueOptions = [
    'gfk',
    'bedürfnisorientiert',
    'attachment_parenting',
    'unerzogen',
    'montessori',
    'waldorf',
    'freilernend',
    'pikler',
    'respektvoll',
    'strukturiert',
    'demokratisch',
    'religioes',
    'interkulturell',
    'feministisch',
    'naturverbunden',
    'offen',
  ];
  static const Map<String, String> valueLabels = {
    'gfk': '\u{1F49A} Gewaltfreie Kommunikation (GfK)',
    'bedürfnisorientiert': '\u{1F49B} Bedürfnisorientiert',
    'attachment_parenting': '\u{1F917} Attachment Parenting',
    'unerzogen': '\u{1F331} Unerzogen',
    'montessori': '\u{1F52C} Montessori',
    'waldorf': '\u{1F33F} Waldorf',
    'freilernend': '\u{1F4DA} Freilernend',
    'pikler': '\u{1F476} Pikler',
    'respektvoll': '\u{1F64F} Respektvoll',
    'strukturiert': '\u{1F4CB} Strukturiert',
    'demokratisch': '\u{1F5F3}\u{FE0F} Demokratisch',
    'religioes': '\u{1F54C} Religioes/Spirituell',
    'interkulturell': '\u{1F30D} Interkulturell',
    'feministisch': '\u{2640}\u{FE0F} Feministisch',
    'naturverbunden': '\u{1F333} Naturverbunden',
    'offen': '\u{2728} Offen für alles',
  };

  // ─── WAS SUCHEN WIR? (AKTIVITAETEN) ──────────────────────────────────────
  static const List<String> lookingForOptions = [
    'spielplatz',
    'natur',
    'sport',
    'kreativ',
    'kochen',
    'musik',
    'vorlesen',
    'eltern_austausch',
    'babysitting_tausch',
    'kita_fahrgemeinschaft',
    'kindergeburtstage',
    'ausflug',
    'indoor_treffen',
    'regelmaessig',
    'spontan',
    'online_austausch',
  ];
  static const Map<String, String> lookingForLabels = {
    'spielplatz': '\u{1F3A0} Spielplatz-Dates',
    'natur': '\u{1F333} Wald & Natur',
    'sport': '\u{26BD} Sport & Bewegung',
    'kreativ': '\u{1F3A8} Kreativ-Treffen',
    'kochen': '\u{1F373} Gemeinsam kochen',
    'musik': '\u{1F3B5} Musik & Singen',
    'vorlesen': '\u{1F4D6} Vorlesen & Geschichten',
    'eltern_austausch': '\u{2615} Eltern-Austausch',
    'babysitting_tausch': '\u{1F91D} Babysitting-Tausch',
    'kita_fahrgemeinschaft': '\u{1F697} Kita-Fahrgemeinschaft',
    'kindergeburtstage': '\u{1F382} Kindergeburtstage',
    'ausflug': '\u{1F3DE}\u{FE0F} Ausfluege & Reisen',
    'indoor_treffen': '\u{1F3E0} Indoor-Treffen',
    'regelmaessig': '\u{1F504} Regelmaessige Gruppe',
    'spontan': '\u{26A1} Spontane Treffen',
    'online_austausch': '\u{1F4AC} Online-Austausch',
  };

  // ─── VERFUEGBARKEIT: TAGE ────────────────────────────────────────────────
  static const List<String> dayOptions = [
    'montag',
    'dienstag',
    'mittwoch',
    'donnerstag',
    'freitag',
    'samstag',
    'sonntag',
  ];
  static const Map<String, String> dayLabels = {
    'montag': 'Mo',
    'dienstag': 'Di',
    'mittwoch': 'Mi',
    'donnerstag': 'Do',
    'freitag': 'Fr',
    'samstag': 'Sa',
    'sonntag': 'So',
  };

  // ─── VERFUEGBARKEIT: ZEITEN ──────────────────────────────────────────────
  static const List<String> timeOptions = [
    'morgens',
    'vormittags',
    'nachmittags',
    'abends',
    'nach_kita',
    'flexibel',
  ];
  static const Map<String, String> timeLabels = {
    'morgens': '\u{1F305} Frueh (6\u201309)',
    'vormittags': '\u{2600}\u{FE0F} Vormittags (9\u201312)',
    'nachmittags': '\u{1F31E} Nachmittags (12\u201317)',
    'abends': '\u{1F319} Abends (17\u201321)',
    'nach_kita': '\u{1F3EB} Nach Kita/Schule',
    'flexibel': '\u{1F4AB} Flexibel',
  };

  // ─── BESONDERHEITEN ──────────────────────────────────────────────────────
  static const List<String> specialOptions = [
    'behinderung',
    'neurodivergent',
    'hochsensibel',
    'fruehchen',
    'mehrlinge',
    'chronisch_krank',
    'allergien',
    'schreibaby',
    'pflegekind',
  ];
  static const Map<String, String> specialLabels = {
    'behinderung': '\u{267F} Kind mit Behinderung',
    'neurodivergent': '\u{1F9E0} Neurodivergent (ADHS/Autismus)',
    'hochsensibel': '\u{1F33C} Hochsensibel',
    'fruehchen': '\u{1F4AA} Fruehchen-Eltern',
    'mehrlinge': '\u{1F46F} Mehrlinge',
    'chronisch_krank': '\u{1F3E5} Chronische Erkrankung',
    'allergien': '\u{26A0}\u{FE0F} Allergien/Unvertraeglichkeiten',
    'schreibaby': '\u{1F476} Schreibaby/Regulationsstoerung',
    'pflegekind': '\u{2764}\u{FE0F} Pflegekind',
  };

  // ─── KINDER-INTERESSEN ───────────────────────────────────────────────────
  static const List<String> childInterests = [
    'spielplatz',
    'basteln',
    'malen',
    'natur',
    'sport',
    'musik',
    'tanzen',
    'tiere',
    'bücher',
    'bauen',
    'rollenspiel',
    'kochen_backen',
    'wasser',
    'fahrrad',
    'theater',
    'experimente',
  ];
  static const Map<String, String> childInterestLabels = {
    'spielplatz': '\u{1F3A0} Spielplatz',
    'basteln': '\u{2702}\u{FE0F} Basteln',
    'malen': '\u{1F3A8} Malen',
    'natur': '\u{1F33F} Natur entdecken',
    'sport': '\u{26BD} Sport',
    'musik': '\u{1F3B5} Musik',
    'tanzen': '\u{1F483} Tanzen',
    'tiere': '\u{1F436} Tiere',
    'bücher': '\u{1F4DA} Bücher',
    'bauen': '\u{1F9F1} Bauen & Konstruieren',
    'rollenspiel': '\u{1F3AD} Rollenspiel',
    'kochen_backen': '\u{1F36A} Kochen & Backen',
    'wasser': '\u{1F4A6} Wasser & Plantschen',
    'fahrrad': '\u{1F6B2} Fahrrad & Roller',
    'theater': '\u{1F3AC} Theater & Verkleiden',
    'experimente': '\u{1F52C} Experimente',
  };

  // ─── KINDER-GESCHLECHT ───────────────────────────────────────────────────
  static const Map<String, String> genderLabels = {
    'maennlich': '\u{1F466} Junge',
    'weiblich': '\u{1F467} Maedchen',
    'divers': '\u{1F31F} Divers',
  };

  // ─── SPRACHEN (ALLE 27) ──────────────────────────────────────────────────
  static const Map<String, String> languageLabels = {
    'de': '\u{1F1E9}\u{1F1EA} Deutsch',
    'en': '\u{1F1EC}\u{1F1E7} English',
    'tr': '\u{1F1F9}\u{1F1F7} Tuerkce',
    'ar':
        '\u{1F1F8}\u{1F1E6} \u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}',
    'ku': 'Kurdi',
    'fr': '\u{1F1EB}\u{1F1F7} Francais',
    'es': '\u{1F1EA}\u{1F1F8} Espanol',
    'ru': '\u{1F1F7}\u{1F1FA} Russkij',
    'pl': '\u{1F1F5}\u{1F1F1} Polski',
    'it': '\u{1F1EE}\u{1F1F9} Italiano',
    'pt': '\u{1F1F5}\u{1F1F9} Portugues',
    'nl': '\u{1F1F3}\u{1F1F1} Nederlands',
    'uk': '\u{1F1FA}\u{1F1E6} Ukrainska',
    'ro': '\u{1F1F7}\u{1F1F4} Romana',
    'bg': '\u{1F1E7}\u{1F1EC} Bulgarski',
    'sr': '\u{1F1F7}\u{1F1F8} Srpski',
    'hr': '\u{1F1ED}\u{1F1F7} Hrvatski',
    'bs': '\u{1F1E7}\u{1F1E6} Bosanski',
    'sq': '\u{1F1E6}\u{1F1F1} Shqip',
    'el': '\u{1F1EC}\u{1F1F7} Ellinika',
    'fa': '\u{1F1EE}\u{1F1F7} Farsi',
    'hi': '\u{1F1EE}\u{1F1F3} Hindi',
    'zh': '\u{1F1E8}\u{1F1F3} Zhongwen',
    'ja': '\u{1F1EF}\u{1F1F5} Nihongo',
    'ko': '\u{1F1F0}\u{1F1F7} Hangugeo',
    'vi': '\u{1F1FB}\u{1F1F3} Tieng Viet',
    'sw': '\u{1F1F0}\u{1F1EA} Kiswahili',
  };
}
