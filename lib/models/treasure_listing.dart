class TreasureListing {
  const TreasureListing({
    required this.id,
    required this.title,
    required this.category,
    required this.sizeAge,
    required this.conditionKey,
    required this.distanceMeters,
    required this.colorLabel,
    required this.note,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.rating = 0,
    this.ratingCount = 0,
    this.views = 0,
    this.imagePath,
    this.imagePaths = const [],
    this.ownerUserId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String sizeAge;
  final String conditionKey;
  final int distanceMeters;
  final String colorLabel;
  final String note;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int ratingCount;
  final int views;
  final String? imagePath;
  final List<String> imagePaths;
  final String? ownerUserId;
  final DateTime createdAt;

  List<String> get resolvedImagePaths {
    final paths = <String>[];

    void addIfValid(String? value) {
      if (value == null) {
        return;
      }
      final trimmed = value.trim();
      if (trimmed.isEmpty || paths.contains(trimmed)) {
        return;
      }
      paths.add(trimmed);
    }

    addIfValid(imagePath);
    for (final path in imagePaths) {
      addIfValid(path);
    }
    return paths;
  }

  String? get primaryImagePath =>
      resolvedImagePaths.isEmpty ? null : resolvedImagePaths.first;
  int get photoCount => resolvedImagePaths.length;
  bool get hasImages => photoCount > 0;

  TreasureListing copyWith({
    String? id,
    String? title,
    String? category,
    String? sizeAge,
    String? conditionKey,
    int? distanceMeters,
    String? colorLabel,
    String? note,
    String? locationLabel,
    double? latitude,
    double? longitude,
    double? rating,
    int? ratingCount,
    int? views,
    String? imagePath,
    List<String>? imagePaths,
    String? ownerUserId,
    DateTime? createdAt,
  }) {
    return TreasureListing(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      sizeAge: sizeAge ?? this.sizeAge,
      conditionKey: conditionKey ?? this.conditionKey,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      colorLabel: colorLabel ?? this.colorLabel,
      note: note ?? this.note,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      views: views ?? this.views,
      imagePath: imagePath ?? this.imagePath,
      imagePaths: imagePaths ?? this.imagePaths,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TreasureListing.fromMap(Map<String, dynamic> map) {
    final rawImagePaths = map['imagePaths'];
    final imagePaths = rawImagePaths is List
        ? rawImagePaths.map((item) => item.toString()).toList()
        : <String>[];
    return TreasureListing(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      sizeAge: map['sizeAge']?.toString() ?? '',
      conditionKey: map['conditionKey']?.toString() ?? 'round2',
      distanceMeters:
          int.tryParse(map['distanceMeters']?.toString() ?? '') ?? 200,
      colorLabel: map['colorLabel']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      locationLabel: map['locationLabel']?.toString(),
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
      rating: double.tryParse(map['rating']?.toString() ?? '') ?? 0,
      ratingCount: int.tryParse(map['ratingCount']?.toString() ?? '') ?? 0,
      views: int.tryParse(map['views']?.toString() ?? '') ?? 0,
      imagePath: map['imagePath']?.toString(),
      imagePaths: imagePaths,
      ownerUserId: map['ownerUserId']?.toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedPaths = resolvedImagePaths;
    return {
      'id': id,
      'title': title,
      'category': category,
      'sizeAge': sizeAge,
      'conditionKey': conditionKey,
      'distanceMeters': distanceMeters,
      'colorLabel': colorLabel,
      'note': note,
      'locationLabel': locationLabel,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'ratingCount': ratingCount,
      'views': views,
      'imagePath': primaryImagePath,
      'imagePaths': resolvedPaths,
      'ownerUserId': ownerUserId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
