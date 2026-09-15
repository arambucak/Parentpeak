class FamilyPlace {
  const FamilyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.openingHours,
    this.isIndoor,
    this.ageHint,
    this.tags = const [],
    this.website,
    this.phone,
  });

  final String id;
  final String name;
  final FamilyPlaceCategory category;
  final double lat;
  final double lng;
  final String? openingHours;
  final bool? isIndoor;
  final String? ageHint;
  final List<String> tags;
  final String? website;
  final String? phone;

  String get categoryLabel => category.label;
  bool get isOpenNow => _isOpenNow(DateTime.now());

  bool _isOpenNow(DateTime referenceTime) {
    if (openingHours == null || openingHours!.trim().isEmpty) return true;
    final normalized = openingHours!.replaceAll('\n', ' ');
    final segments = normalized.split(';');
    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      final dayPart = trimmed.split(' ').firstWhere(
        (part) => part.length >= 2,
        orElse: () => '',
      );
      if (dayPart.isEmpty) continue;

      final dayCode = {
        1: 'Mo', 2: 'Di', 3: 'Mi', 4: 'Do', 5: 'Fr', 6: 'Sa', 7: 'So'
      }[referenceTime.weekday] ?? 'Mo';
      final matchesDay = trimmed.toLowerCase().contains(dayCode.toLowerCase()) ||
          trimmed.toLowerCase().contains('mo-fr') ||
          trimmed.toLowerCase().contains('werktags');
      if (!matchesDay) continue;

      final timeRange = trimmed.replaceFirst(RegExp(r'^[A-Za-z-]+\s*'), '').trim();
      if (timeRange.isEmpty || !timeRange.contains('-')) continue;

      final parts = timeRange.split('-');
      if (parts.length != 2) continue;
      final start = _parseTime(parts[0].trim());
      final end = _parseTime(parts[1].trim());
      if (start == null || end == null) continue;

      final currentMinutes = referenceTime.hour * 60 + referenceTime.minute;
      if (start <= end) {
        if (currentMinutes >= start && currentMinutes <= end) return true;
      } else if (currentMinutes >= start || currentMinutes <= end) {
        return true;
      }
    }
    return false;
  }

  int? _parseTime(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[^0-9:]'), '');
    if (clean.isEmpty) return null;
    final parts = clean.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return hours * 60 + minutes;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'lat': lat,
        'lng': lng,
        if (openingHours != null) 'openingHours': openingHours,
        if (isIndoor != null) 'isIndoor': isIndoor,
        if (ageHint != null) 'ageHint': ageHint,
        if (tags.isNotEmpty) 'tags': tags,
        if (website != null) 'website': website,
        if (phone != null) 'phone': phone,
      };

  factory FamilyPlace.fromJson(Map<String, dynamic> json) => FamilyPlace(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Ort',
        category: FamilyPlaceCategory.values.firstWhere(
          (value) => value.name == json['category']?.toString(),
          orElse: () => FamilyPlaceCategory.playground,
        ),
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        openingHours: json['openingHours']?.toString(),
        isIndoor: json['isIndoor'] == true ? true : (json['isIndoor'] == false ? false : null),
        ageHint: json['ageHint']?.toString(),
        tags: List<String>.from(json['tags'] ?? const []),
        website: json['website']?.toString(),
        phone: json['phone']?.toString(),
      );
}

enum FamilyPlaceCategory {
  playground,
  familyCenter,
  indoorPlayground,
  swimmingPool,
  swimCourse,
}

extension FamilyPlaceCategoryLabel on FamilyPlaceCategory {
  String get label {
    switch (this) {
      case FamilyPlaceCategory.playground:
        return 'Spielplatz';
      case FamilyPlaceCategory.familyCenter:
        return 'Familienzentrum';
      case FamilyPlaceCategory.indoorPlayground:
        return 'Indoor-Spielplatz';
      case FamilyPlaceCategory.swimmingPool:
        return 'Schwimmbad';
      case FamilyPlaceCategory.swimCourse:
        return 'Schwimmkurs';
    }
  }
}
