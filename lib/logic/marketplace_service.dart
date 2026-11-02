import 'package:flutter/foundation.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

class Provider {
  final String id;
  final String name;
  final String category; // Fach/Kategorie
  final String subcategory; // Detailliert
  final double price;
  final String priceUnit;
  final double rating;
  final int reviews;
  final String photo;
  final String description;
  final String location;
  final int age;
  final bool verified;
  final List<String> languages;
  final String availability;
  final String categoryGroup; // "Bildungsangebote", "Betreuung", "Kaufen & Verkaufen"
  final String? educationType; // "Nachhilfe" oder "Außerschulisch" (nur für Bildung)

  Provider({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.price,
    required this.priceUnit,
    required this.rating,
    required this.reviews,
    required this.photo,
    required this.description,
    required this.location,
    required this.age,
    required this.verified,
    required this.languages,
    required this.availability,
    required this.categoryGroup,
    this.educationType,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      price: (json['price'] as num).toDouble(),
      priceUnit: json['priceUnit'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviews: json['reviews'] as int,
      photo: json['photo'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      age: json['age'] as int,
      verified: json['verified'] as bool,
      languages: List<String>.from(json['languages'] as List),
      availability: json['availability'] as String,
      categoryGroup: json['categoryGroup'] as String,
      educationType: json['educationType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'subcategory': subcategory,
    'price': price,
    'priceUnit': priceUnit,
    'rating': rating,
    'reviews': reviews,
    'photo': photo,
    'description': description,
    'location': location,
    'age': age,
    'verified': verified,
    'languages': languages,
    'availability': availability,
    'categoryGroup': categoryGroup,
    'educationType': educationType,
  };
}

class MarketplaceService {
  static dynamic get _apiClient => BackendServiceFactory.createApiClient();

  static bool get _isBackendEnabled => _apiClient != null;

  static Never _throwReleaseUnavailable(String context, [Object? error]) {
    final details = error == null ? '' : ' ($error)';
    throw StateError('$context derzeit nicht verfügbar$details');
  }

  static String _inferCategoryGroup(Map<String, dynamic> json) {
    final explicit = json['categoryGroup']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final category = (json['category'] ?? '').toString().toLowerCase();
    final subcategory = (json['subcategory'] ?? '').toString().toLowerCase();

    const educationHints = [
      'nachhilfe',
      'mathe',
      'mathematik',
      'englisch',
      'deutsch',
      'physik',
      'chemie',
      'biologie',
      'französisch',
      'franzoesisch',
      'spanisch',
      'latein',
      'musik',
      'kunst',
      'bildung',
      'lern',
      'prüfung',
      'pruefung',
    ];

    const careHints = [
      'betreuung',
      'kleinkinder',
      'schulkinder',
      'vorschul',
      'fahrdienst',
      'notfallbetreuung',
      'babysitting',
    ];

    if (educationHints.any((hint) => category.contains(hint) || subcategory.contains(hint))) {
      return 'Bildungsangebote';
    }
    if (careHints.any((hint) => category.contains(hint) || subcategory.contains(hint))) {
      return 'Betreuung';
    }
    return 'Kaufen & Verkaufen';
  }

  static String? _inferEducationType(Map<String, dynamic> json) {
    final explicit = json['educationType']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final subcategory = (json['subcategory'] ?? '').toString().toLowerCase();
    final categoryGroup = _inferCategoryGroup(json);
    if (categoryGroup != 'Bildungsangebote') return null;
    if (subcategory.contains('nachhilfe')) return 'Nachhilfe';
    return 'Außerschulisch';
  }

  static Provider _normalizeProvider(Map<String, dynamic> json) {
    return Provider(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unbekannt').toString(),
      category: (json['category'] ?? '').toString(),
      subcategory: (json['subcategory'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ??
          double.tryParse('${json['price']}') ??
          0,
      priceUnit: (json['priceUnit'] ?? '€/Stunde').toString(),
      rating: (json['rating'] as num?)?.toDouble() ??
          double.tryParse('${json['rating']}') ??
          0,
      reviews: (json['reviews'] as num?)?.toInt() ??
          int.tryParse('${json['reviews']}') ??
          0,
      photo: (json['photo'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      age: (json['age'] as num?)?.toInt() ?? int.tryParse('${json['age']}') ?? 0,
      verified: json['verified'] as bool? ?? false,
      languages: (json['languages'] is List)
          ? List<String>.from((json['languages'] as List).map((e) => e.toString()))
          : const [],
      availability: (json['availability'] ?? '').toString(),
      categoryGroup: _inferCategoryGroup(json),
      educationType: _inferEducationType(json),
    );
  }

  /// Mock-Anbieter Daten (professionelle Kategorien)
  static final List<Provider> _mockProviders = [
    // ============ A) BILDUNGSANGEBOTE ============
    Provider(
      id: '1',
      name: 'Maria Schmidt',
      category: 'Mathematik',
      subcategory: 'Kernfächer',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 25,
      priceUnit: '€/Stunde',
      rating: 4.8,
      reviews: 24,
      photo: 'https://via.placeholder.com/150?text=Maria',
      description: 'Erfahrene Mathematiklehrerin mit 8 Jahren Unterrichtserfahrung. Spezialisiert auf alle Klassenstufen von Grundschule bis Gymnasium.',
      location: 'München',
      age: 32,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-Fr 15:00-20:00, Sa 10:00-13:00',
    ),
    Provider(
      id: '2',
      name: 'Thomas Weber',
      category: 'Englisch',
      subcategory: 'Sprachen',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 28,
      priceUnit: '€/Stunde',
      rating: 4.9,
      reviews: 31,
      photo: 'https://via.placeholder.com/150?text=Thomas',
      description: 'Native English Speaker mit Cambridge Certificate. Interaktiver Unterricht für alle Altersgruppen und Niveaus.',
      location: 'München',
      age: 29,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-So 16:00-21:00',
    ),
    Provider(
      id: '3',
      name: 'Sophie Wagner',
      category: 'Deutsch',
      subcategory: 'Kernfächer',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 22,
      priceUnit: '€/Stunde',
      rating: 4.8,
      reviews: 19,
      photo: 'https://via.placeholder.com/150?text=Sophie',
      description: 'Deutschlehrerin mit Fokus auf Aufsätze, Rechtschreibung und Literaturverständnis. Geduldig und einfühlsam.',
      location: 'München',
      age: 31,
      verified: true,
      languages: ['Deutsch', 'Englisch', 'Französisch'],
      availability: 'Mo-Fr 14:00-20:00, Sa 11:00-14:00',
    ),
    Provider(
      id: '4',
      name: 'Klaus Bauer',
      category: 'Physik',
      subcategory: 'Naturwissenschaften',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 30,
      priceUnit: '€/Stunde',
      rating: 4.6,
      reviews: 15,
      photo: 'https://via.placeholder.com/150?text=Klaus',
      description: 'Gymnasiallehrer mit Spezialausbildung in Physik. Besonders gut für Abitur-Vorbereitung mit experimentellen Methoden.',
      location: 'München',
      age: 38,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-Do 16:00-20:00, Sa 10:00-13:00',
    ),
    Provider(
      id: '5',
      name: 'Marco Rossi',
      category: 'Französisch',
      subcategory: 'Sprachen',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 26,
      priceUnit: '€/Stunde',
      rating: 4.8,
      reviews: 17,
      photo: 'https://via.placeholder.com/150?text=Marco',
      description: 'Native French Speaker mit Unterrichtserfahrung. Unterricht Französisch mit authentischen Methoden und Kultur.',
      location: 'München',
      age: 30,
      verified: true,
      languages: ['Deutsch', 'Französisch', 'Spanisch', 'Englisch', 'Italienisch'],
      availability: 'Mo-Fr 15:00-21:00, Sa-So 11:00-18:00',
    ),
    Provider(
      id: '6',
      name: 'Dr. Anna Hoffmann',
      category: 'Biologie',
      subcategory: 'Naturwissenschaften',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 28,
      priceUnit: '€/Stunde',
      rating: 4.9,
      reviews: 28,
      photo: 'https://via.placeholder.com/150?text=Anna',
      description: 'Diplom-Biologin mit Lehrerfahrung. Verständnisvoller Unterricht für Schüler aller Klassenstufen.',
      location: 'München',
      age: 45,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-So 10:00-20:00 (flexible Zeiten)',
    ),
    Provider(
      id: '7',
      name: 'Lisa Hoffmann',
      category: 'Chemie',
      subcategory: 'Naturwissenschaften',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 29,
      priceUnit: '€/Stunde',
      rating: 4.7,
      reviews: 20,
      photo: 'https://via.placeholder.com/150?text=Lisa',
      description: 'Chemielehrer mit praktischen Experimenten. Macht Chemie verständlich und spannend für Schüler.',
      location: 'München',
      age: 26,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Mo-Fr 15:00-20:00, Sa 10:00-14:00',
    ),
    Provider(
      id: '8',
      name: 'Anna Müller',
      category: 'Geschichte / Sozialkunde',
      subcategory: 'Gesellschaftswissenschaften',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 23,
      priceUnit: '€/Stunde',
      rating: 4.7,
      reviews: 18,
      photo: 'https://via.placeholder.com/150?text=Anna',
      description: 'Engagierte Geschichtslehrerin. Macht Geschichte lebendig und verknüpft mit aktuellen Ereignissen.',
      location: 'München',
      age: 24,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-Fr 14:00-20:00, Sa 10:00-13:00',
    ),
    Provider(
      id: '9',
      name: 'Elena Karpova',
      category: 'Lernhilfe bei Dyskalkulie/Legasthenie',
      subcategory: 'Spezialförderung',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 35,
      priceUnit: '€/Stunde',
      rating: 4.9,
      reviews: 32,
      photo: 'https://via.placeholder.com/150?text=Elena',
      description: 'Spezialistin für Lernstörungen. Individuelle Förderung mit wissenschaftlich bewährten Methoden.',
      location: 'München',
      age: 28,
      verified: true,
      languages: ['Deutsch', 'Russisch', 'Englisch'],
      availability: 'Mo-So 10:00-20:00',
    ),
    Provider(
      id: '10',
      name: 'Michael Schmidt',
      category: 'Latein',
      subcategory: 'Sprachen',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 27,
      priceUnit: '€/Stunde',
      rating: 4.8,
      reviews: 16,
      photo: 'https://via.placeholder.com/150?text=Michael',
      description: 'Lateinlehrer mit Klassische Philologie Hintergrund. Macht Latein verständlich und interessant.',
      location: 'München',
      age: 35,
      verified: true,
      languages: ['Deutsch', 'Englisch', 'Latein'],
      availability: 'Mo-Fr 16:00-20:00, Sa 10:00-14:00',
    ),
    Provider(
      id: '11',
      name: 'Patricia Martinez',
      category: 'Spanisch',
      subcategory: 'Sprachen',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 26,
      priceUnit: '€/Stunde',
      rating: 4.9,
      reviews: 25,
      photo: 'https://via.placeholder.com/150?text=Patricia',
      description: 'Native Spanish Speaker. Unterricht mit kulturellem Schwerpunkt und praktischen Anwendungen.',
      location: 'München',
      age: 29,
      verified: true,
      languages: ['Deutsch', 'Spanisch', 'Englisch'],
      availability: 'Mo-Fr 15:00-21:00, Sa 11:00-17:00',
    ),
    Provider(
      id: '12',
      name: 'David Hoffmann',
      category: 'Musik',
      subcategory: 'Künstlerische Fächer',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Außerschulisch',
      price: 25,
      priceUnit: '€/Stunde',
      rating: 4.7,
      reviews: 14,
      photo: 'https://via.placeholder.com/150?text=David',
      description: 'Musiklehrer mit Profierfahrung. Unterricht für Anfänger und Fortgeschrittene, alle Instrumente willkommen.',
      location: 'München',
      age: 31,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-Fr 16:00-20:00, Sa 10:00-18:00',
    ),
    Provider(
      id: '13',
      name: 'Catherine Laurent',
      category: 'Kunst',
      subcategory: 'Künstlerische Fächer',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Außerschulisch',
      price: 24,
      priceUnit: '€/Stunde',
      rating: 4.8,
      reviews: 19,
      photo: 'https://via.placeholder.com/150?text=Catherine',
      description: 'Kunstlehrerin mit praktischem Schwerpunkt. Verschiedene Techniken und Malstile für alle Altersgruppen.',
      location: 'München',
      age: 27,
      verified: true,
      languages: ['Deutsch', 'Englisch', 'Französisch'],
      availability: 'Mo-Fr 15:00-20:00, Sa 10:00-16:00',
    ),
    Provider(
      id: '14',
      name: 'Frank Wagner',
      category: 'Sport',
      subcategory: 'Künstlerische Fächer',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Außerschulisch',
      price: 22,
      priceUnit: '€/Stunde',
      rating: 4.6,
      reviews: 13,
      photo: 'https://via.placeholder.com/150?text=Frank',
      description: 'Sporttrainer mit Trainer-Lizenz. Unterricht in verschiedenen Sportarten für alle Altersgruppen.',
      location: 'München',
      age: 40,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Mo-Fr 15:00-19:00, Sa 09:00-15:00',
    ),
    Provider(
      id: '15',
      name: 'Julia Bergmann',
      category: 'Hausaufgabenbetreuung (Allgemein)',
      subcategory: 'Allgemeine Unterstützung',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 18,
      priceUnit: '€/Stunde',
      rating: 4.7,
      reviews: 27,
      photo: 'https://via.placeholder.com/150?text=Julia',
      description: 'Zuverlässige Hausaufgabenbetreuung für alle Fächer und Klassenstufen. Unterstützt das eigenverantwortliche Lernen.',
      location: 'München',
      age: 25,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-Fr 13:00-19:00, Sa 10:00-14:00',
    ),
    Provider(
      id: '16',
      name: 'Prof. Dr. Hans Mueller',
      category: 'Prüfungsvorbereitung (Abitur/Abschluss)',
      subcategory: 'Intensive Prüfungsvorbereitung',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 40,
      priceUnit: '€/Stunde',
      rating: 4.9,
      reviews: 45,
      photo: 'https://via.placeholder.com/150?text=Hans',
      description: 'Spezialist für Abitur- und Abschlussvorbereitungen. Intensive Kurse mit hoher Erfolgsquote.',
      location: 'München',
      age: 52,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-So 10:00-21:00 (sehr flexible Zeiten)',
    ),
    Provider(
      id: '17',
      name: 'Sachunterricht Expert',
      category: 'Sachunterricht / Naturwissenschaften',
      subcategory: 'Naturwissenschaften',
      categoryGroup: 'Bildungsangebote',
      educationType: 'Nachhilfe',
      price: 22,
      priceUnit: '€/Stunde',
      rating: 4.6,
      reviews: 13,
      photo: 'https://via.placeholder.com/150?text=Sachunterricht',
      description: 'Spezialisiert auf Sachunterricht für Grundschule. Macht Naturwissenschaften spannend und verständlich.',
      location: 'München',
      age: 40,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Mo-Fr 14:00-18:00, Sa 09:00-12:00',
    ),

    // ============ B) BETREUUNG ============
    Provider(
      id: '7',
      name: 'Julia Fischer',
      category: 'Kleinkindbetreuung',
      subcategory: 'Für Kinder von 0 bis 3 Jahren',
      categoryGroup: 'Betreuung',
      price: 18,
      priceUnit: '€/Stunde',
      rating: 4.9,
      reviews: 22,
      photo: 'https://via.placeholder.com/150?text=Julia',
      description: 'Fachkraft für Kindertagesstätten. Spiel, Bewegung und frühe Förderung. Mit Erste-Hilfe-Zertifikat und Erfahrung mit Neugeborenen.',
      location: 'München',
      age: 27,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Mo-Fr 08:00-18:00, Sa 09:00-14:00',
    ),
    Provider(
      id: '8',
      name: 'Lisa Hoffmann',
      category: 'Vorschulbetreuung',
      subcategory: 'Für Kinder von 3 bis 6 Jahren',
      categoryGroup: 'Betreuung',
      price: 16,
      priceUnit: '€/Stunde',
      rating: 4.7,
      reviews: 20,
      photo: 'https://via.placeholder.com/150?text=Lisa',
      description: 'Erzieherin mit Spezialausbildung. Spielerisches Lernen, Kreativität, Musik und Bewegung für Vorschulkinder.',
      location: 'München',
      age: 26,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Mo-Fr 07:00-19:00, Sa 10:00-17:00',
    ),
    Provider(
      id: '9',
      name: 'Anna Müller',
      category: 'Schulkindbetreuung',
      subcategory: 'Unterstützung am Nachmittag',
      categoryGroup: 'Betreuung',
      price: 15,
      priceUnit: '€/Stunde',
      rating: 4.7,
      reviews: 18,
      photo: 'https://via.placeholder.com/150?text=Anna',
      description: 'Geduldig, zuverlässig und kinderfreundlich. Hausaufgabenbetreuung, Freizeitgestaltung und sichere Beaufsichtigung.',
      location: 'München',
      age: 24,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Mo-Fr 13:00-18:00',
    ),
    Provider(
      id: '10',
      name: 'Elena Karpova',
      category: 'Notfallbetreuung',
      subcategory: 'Flexible Hilfe & Babysitting',
      categoryGroup: 'Betreuung',
      price: 20,
      priceUnit: '€/Stunde',
      rating: 4.6,
      reviews: 12,
      photo: 'https://via.placeholder.com/150?text=Elena',
      description: 'Flexible Nanny für Notfall-Situationen. Zuverlässig und ruhig unter Druck. Auch kurzfristig verfügbar.',
      location: 'München',
      age: 28,
      verified: true,
      languages: ['Deutsch', 'Russisch'],
      availability: 'Mo-So 07:00-22:00 (auch kurzfristig)',
    ),
    Provider(
      id: '11',
      name: 'Michael Schmidt',
      category: 'Fahrdienste',
      subcategory: 'Flexible Hilfe',
      categoryGroup: 'Betreuung',
      price: 12,
      priceUnit: '€/Fahrt',
      rating: 4.9,
      reviews: 26,
      photo: 'https://via.placeholder.com/150?text=Michael',
      description: 'Zuverlässiger Fahrdienst für Kinder zu Schule, Kurs und Aktivitäten. Kindersicherung und Erste-Hilfe-Kurs.',
      location: 'München',
      age: 35,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Mo-Fr 07:00-19:00',
    ),

    // ============ C) KAUFEN & VERKAUFEN (BASAR) ============
    Provider(
      id: '12',
      name: 'Mode Markt München',
      category: 'Kinderkleidung & Schuhe',
      subcategory: 'Mode',
      categoryGroup: 'Kaufen & Verkaufen',
      price: 0,
      priceUnit: 'Marktplatz',
      rating: 4.5,
      reviews: 42,
      photo: 'https://via.placeholder.com/150?text=Mode',
      description: 'Großes Angebot an neuer und gebrauchter Kinderkleidung. Alle Größen und Marken. Faire Preise für Käufer und Verkäufer.',
      location: 'München',
      age: 0,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Online 24/7, regelmäßige Märkte',
    ),
    Provider(
      id: '13',
      name: 'Spielzeug & Buch Basar',
      category: 'Spielzeug & Lernmaterial',
      subcategory: 'Freizeit & Medien',
      categoryGroup: 'Kaufen & Verkaufen',
      price: 0,
      priceUnit: 'Marktplatz',
      rating: 4.7,
      reviews: 38,
      photo: 'https://via.placeholder.com/150?text=Spielzeug',
      description: 'Gebrauchtes und neues Spielzeug, Bücher, Schulhefte und Lernmaterial. Alles zu günstigen Preisen für die ganze Familie.',
      location: 'München',
      age: 0,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Online täglich, offline jeden 2. Samstag',
    ),
    Provider(
      id: '14',
      name: 'Kinderwagen & Ausstattung',
      category: 'Möbel & Kleingeräte',
      subcategory: 'Ausstattung',
      categoryGroup: 'Kaufen & Verkaufen',
      price: 0,
      priceUnit: 'Marktplatz',
      rating: 4.6,
      reviews: 25,
      photo: 'https://via.placeholder.com/150?text=Ausstattung',
      description: 'Kinderwagen, Hochstühle, Wickeltische und Babymöbel. Top-Marken zu reduzierten Preisen. Sichere Abholung möglich.',
      location: 'München',
      age: 0,
      verified: true,
      languages: ['Deutsch'],
      availability: 'Online 24/7, lokale Abholung nach Vereinbarung',
    ),
    Provider(
      id: '15',
      name: 'Familien Flohmarkt',
      category: 'Alles rund ums Familienleben',
      subcategory: 'Sonstiges',
      categoryGroup: 'Kaufen & Verkaufen',
      price: 0,
      priceUnit: 'Marktplatz',
      rating: 4.4,
      reviews: 31,
      photo: 'https://via.placeholder.com/150?text=Flohmarkt',
      description: 'Der größte Family-Basar in München! Alles rund um Baby, Kinder und Familie. Neue und gebrauchte Artikel.',
      location: 'München',
      age: 0,
      verified: true,
      languages: ['Deutsch', 'Englisch'],
      availability: 'Jeden Sonntag 09:00-15:00, online täglich',
    ),
  ];

  /// Alle Anbieter abrufen (Release: backend-only, Debug: Mock-Fallback)
  static Future<List<Provider>> getAllProviders() async {
    if (!_isBackendEnabled) {
      if (kReleaseMode) {
        _throwReleaseUnavailable('Marktplatz');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockProviders;
    }

    if (_isBackendEnabled) {
      try {
        final payload = await _apiClient.getJson(APIConfig.getBackendProvidersPath());
        if (payload is List) {
          return payload
              .whereType<Map>()
              .map((item) => _normalizeProvider(Map<String, dynamic>.from(item)))
              .toList();
        }
        if (kReleaseMode) {
          _throwReleaseUnavailable('Marktplatz', 'ungültige Backend-Antwort');
        }
      } catch (e) {
        debugPrint('MarketplaceService.getAllProviders fallback: $e');
        if (kReleaseMode) {
          _throwReleaseUnavailable('Marktplatz', e);
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return _mockProviders;
  }

  /// Anbieter nach Kategorie-Gruppe filtern (A, B, C)
  static Future<List<Provider>> getProvidersByGroup(String group) async {
    final providers = await getAllProviders();
    return providers.where((p) => p.categoryGroup == group).toList();
  }

  /// Anbieter nach detaillierter Kategorie filtern
  static Future<List<Provider>> getProvidersByCategory(String category) async {
    final providers = await getAllProviders();
    if (_isBackendEnabled) {
      try {
        final payload = await _apiClient.getJson(
          '${APIConfig.getBackendProvidersPath()}/category/${Uri.encodeComponent(category)}',
        );
        if (payload is List) {
          return payload
              .whereType<Map>()
              .map((item) => _normalizeProvider(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (e) {
        debugPrint('MarketplaceService.getProvidersByCategory fallback: $e');
        if (kReleaseMode) {
          _throwReleaseUnavailable('Marktplatz Kategorie', e);
        }
      }
    }

    return providers
        .where((p) => p.category == category || p.subcategory == category)
        .toList();
  }

  /// Alle Kategorien-Gruppen abrufen
  static Future<List<String>> getAllCategoryGroups() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final groups = <String>{};
    for (final provider in await getAllProviders()) {
      groups.add(provider.categoryGroup);
    }
    return groups.toList();
  }

  /// Alle Kategorien in einer Gruppe
  static Future<List<String>> getCategoriesByGroup(String group) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final categories = <String>{};
    for (final provider in (await getAllProviders()).where((p) => p.categoryGroup == group)) {
      categories.add(provider.category);
    }
    return categories.toList()..sort();
  }

  /// Suche nach Text (Release: backend-only, Debug: Mock-Fallback)
  static Future<List<Provider>> search(String query) async {
    if (!_isBackendEnabled) {
      if (kReleaseMode) {
        _throwReleaseUnavailable('Marktplatz Suche');
      }
      await Future.delayed(const Duration(milliseconds: 300));
      final q = query.toLowerCase();
      return _mockProviders
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
    }

    if (_isBackendEnabled) {
      try {
        final payload = await _apiClient.getJson(
          '${APIConfig.getBackendProviderSearchPath()}?q=${Uri.encodeQueryComponent(query)}',
        );
        if (payload is List) {
          return payload
              .whereType<Map>()
              .map((item) => _normalizeProvider(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (e) {
        debugPrint('MarketplaceService.search fallback: $e');
        if (kReleaseMode) {
          _throwReleaseUnavailable('Marktplatz Suche', e);
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final q = query.toLowerCase();
    return _mockProviders
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q))
        .toList();
  }

  /// Bewertung hinzufügen (Release: backend-only)
  static Future<void> addReview({
    required String providerId,
    required double rating,
    required String comment,
    required String parentName,
  }) async {
    if (!_isBackendEnabled) {
      if (kReleaseMode) {
        _throwReleaseUnavailable('Bewertungen');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    if (_isBackendEnabled) {
      try {
        await _apiClient.postJsonAny(
          '${APIConfig.getBackendProvidersPath()}/$providerId/review',
          {
            'rating': rating,
            'comment': comment,
            'parentName': parentName,
          },
        );
        return;
      } catch (e) {
        debugPrint('MarketplaceService.addReview fallback: $e');
        if (kReleaseMode) {
          _throwReleaseUnavailable('Bewertungen', e);
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Erweiterte Filter (Release: backend-only, Debug: Mock-Fallback)
  static Future<List<Provider>> filterProviders({
    List<String>? categories,
    double? maxPrice,
    double? minRating,
    String? categoryGroup,
  }) async {
    if (!_isBackendEnabled) {
      if (kReleaseMode) {
        _throwReleaseUnavailable('Marktplatz Filter');
      }

      await Future.delayed(const Duration(milliseconds: 300));
      var filtered = _mockProviders;

      if (categoryGroup != null) {
        filtered = filtered
            .where((p) => p.categoryGroup == categoryGroup)
            .toList();
      }

      if (categories != null && categories.isNotEmpty) {
        filtered = filtered
            .where((p) => categories.contains(p.category))
            .toList();
      }

      if (maxPrice != null && maxPrice > 0) {
        filtered = filtered.where((p) => p.price <= maxPrice).toList();
      }

      if (minRating != null) {
        filtered = filtered.where((p) => p.rating >= minRating).toList();
      }

      return filtered;
    }

    if (_isBackendEnabled) {
      try {
        final payload = await _apiClient.postJsonAny(
          APIConfig.getBackendProviderFilterPath(),
          {
            'categories': categories,
            'maxPrice': maxPrice,
            'minRating': minRating,
          },
        );
        if (payload is List) {
          var remote = payload
              .whereType<Map>()
              .map((item) => _normalizeProvider(Map<String, dynamic>.from(item)))
              .toList();
          if (categoryGroup != null) {
            remote = remote.where((p) => p.categoryGroup == categoryGroup).toList();
          }
          return remote;
        }
      } catch (e) {
        debugPrint('MarketplaceService.filterProviders fallback: $e');
        if (kReleaseMode) {
          _throwReleaseUnavailable('Marktplatz Filter', e);
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));
    var filtered = _mockProviders;

    if (categoryGroup != null) {
      filtered = filtered
          .where((p) => p.categoryGroup == categoryGroup)
          .toList();
    }

    if (categories != null && categories.isNotEmpty) {
      filtered = filtered
          .where((p) => categories.contains(p.category))
          .toList();
    }

    if (maxPrice != null && maxPrice > 0) {
      filtered = filtered.where((p) => p.price <= maxPrice).toList();
    }

    if (minRating != null) {
      filtered = filtered.where((p) => p.rating >= minRating).toList();
    }

    return filtered;
  }
}
