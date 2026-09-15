import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/models/family_place.dart';

class FamilyPlaceService {
  static const String _cacheKey = 'family_places.cache.v1';
  static const Duration _cacheTtl = Duration(hours: 24);

  static List<FamilyPlace> sortPlaces(
    List<FamilyPlace> places,
    double userLat,
    double userLng,
  ) {
    final copy = List<FamilyPlace>.from(places);
    copy.sort((a, b) {
      final aDistance = _haversineKm(userLat, userLng, a.lat, a.lng);
      final bDistance = _haversineKm(userLat, userLng, b.lat, b.lng);
      final distanceCompare = aDistance.compareTo(bDistance);
      if (distanceCompare != 0) return distanceCompare;
      return a.name.compareTo(b.name);
    });
    return copy;
  }

  static bool isOpenNow(FamilyPlace place, DateTime? referenceTime) {
    final openingHours = place.openingHours;
    if (openingHours == null || openingHours.trim().isEmpty) {
      return true;
    }
    final time = referenceTime ?? DateTime.now();
    final dayMap = {
      1: 'Mo',
      2: 'Di',
      3: 'Mi',
      4: 'Do',
      5: 'Fr',
      6: 'Sa',
      7: 'So',
    };

    final dayCode = dayMap[time.weekday] ?? 'Mo';
    final normalized = openingHours.replaceAll('\n', ' ');
    final segments = normalized.split(';');

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      final dayPart = trimmed.split(' ').firstWhere(
        (part) => part.length >= 2,
        orElse: () => '',
      );
      if (dayPart.isEmpty) continue;
      final matchesDay = trimmed.toLowerCase().contains(dayCode.toLowerCase()) ||
          trimmed.toLowerCase().contains('mo-fr') ||
          trimmed.toLowerCase().contains('werktags');
      if (!matchesDay) continue;

      final timeRange = trimmed.replaceFirst(RegExp(r'^[A-Za-z-]+\s*'), '').trim();
      if (timeRange.isEmpty) continue;
      if (!timeRange.contains('-')) continue;

      final parts = timeRange.split('-');
      if (parts.length != 2) continue;
      final start = _parseTime(parts[0].trim());
      final end = _parseTime(parts[1].trim());
      if (start == null || end == null) continue;

      final currentMinutes = time.hour * 60 + time.minute;
      final startMinutes = start;
      final endMinutes = end;
      if (startMinutes <= endMinutes) {
        if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
          return true;
        }
      } else if (currentMinutes >= startMinutes || currentMinutes <= endMinutes) {
        return true;
      }
    }

    return false;
  }

  static Future<List<FamilyPlace>> loadNearbyPlaces({
    required double lat,
    required double lng,
    required int radiusKm,
    bool includeIndoorOnly = false,
    bool includeOpenOnly = false,
    required int? childAgeMonths,
  }) async {
    final cacheKey = '$_cacheKey.$lat.$lng.$radiusKm.$includeIndoorOnly.$includeOpenOnly.$childAgeMonths';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final timestamp = decoded['timestamp'] as int? ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < _cacheTtl.inMilliseconds) {
          final list = (decoded['places'] as List? ?? const [])
              .map((item) => FamilyPlace.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
          return _filterPlaces(
            list,
            lat: lat,
            lng: lng,
            radiusKm: radiusKm,
            includeIndoorOnly: includeIndoorOnly,
            includeOpenOnly: includeOpenOnly,
            childAgeMonths: childAgeMonths,
          );
        }
      } catch (_) {}
    }

    try {
      final places = await _fetchOverpassPlaces(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      final filtered = _filterPlaces(
        places,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        includeIndoorOnly: includeIndoorOnly,
        includeOpenOnly: includeOpenOnly,
        childAgeMonths: childAgeMonths,
      );
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'places': filtered.map((place) => place.toJson()).toList(),
        }),
      );
      return filtered;
    } catch (_) {
      return _filterPlaces(
        const <FamilyPlace>[],
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        includeIndoorOnly: includeIndoorOnly,
        includeOpenOnly: includeOpenOnly,
        childAgeMonths: childAgeMonths,
      );
    }
  }

  static List<FamilyPlace> _filterPlaces(
    List<FamilyPlace> places, {
    required double lat,
    required double lng,
    required int radiusKm,
    required bool includeIndoorOnly,
    required bool includeOpenOnly,
    required int? childAgeMonths,
  }) {
    final normalized = places.where((place) {
      final distance = _haversineKm(lat, lng, place.lat, place.lng);
      if (distance > radiusKm) return false;
      if (includeIndoorOnly && !(place.isIndoor ?? false)) return false;
      if (includeOpenOnly && !isOpenNow(place, DateTime.now())) return false;
      if (childAgeMonths != null && childAgeMonths < 24 && place.category == FamilyPlaceCategory.swimmingPool) {
        return false;
      }
      return true;
    }).toList();
    return sortPlaces(normalized, lat, lng);
  }

  static Future<List<FamilyPlace>> _fetchOverpassPlaces({
    required double lat,
    required double lng,
    required int radiusKm,
  }) async {
    final radiusMeters = (radiusKm * 1000).round();
    final query = '''
      [out:json][timeout:25];
      (
        node[leisure=playground](around:$radiusMeters,$lat,$lng);
        node[amenity=community_centre](around:$radiusMeters,$lat,$lng);
        node[leisure=water_park](around:$radiusMeters,$lat,$lng);
        node[leisure=swimming_pool](around:$radiusMeters,$lat,$lng);
        node[leisure=indoor_play](around:$radiusMeters,$lat,$lng);
        way[leisure=playground](around:$radiusMeters,$lat,$lng);
        way[amenity=community_centre](around:$radiusMeters,$lat,$lng);
        way[leisure=water_park](around:$radiusMeters,$lat,$lng);
        way[leisure=swimming_pool](around:$radiusMeters,$lat,$lng);
        way[leisure=indoor_play](around:$radiusMeters,$lat,$lng);
      );
      out center;''';

    final uri = Uri.parse('https://overpass-api.de/api/interpreter');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {'data': query},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Overpass status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (decoded['elements'] as List? ?? const <dynamic>[]);
    final places = <FamilyPlace>[];

    for (final element in elements) {
      final map = Map<String, dynamic>.from(element as Map);
      final tags = map['tags'] as Map<String, dynamic>? ?? const {};
      final latValue = map['lat'] ?? map['center']?['lat'];
      final lonValue = map['lon'] ?? map['center']?['lon'];
      if (latValue == null || lonValue == null) continue;

      final category = _categoryFromTags(tags);
      if (category == null) continue;

      final name = (tags['name'] ?? tags['official_name'] ?? 'Familienort').toString();
      final place = FamilyPlace(
        id: '${category.name}_${name}_${latValue.toString()}_${lonValue.toString()}',
        name: name,
        category: category,
        lat: double.tryParse(latValue.toString()) ?? 0,
        lng: double.tryParse(lonValue.toString()) ?? 0,
        openingHours: tags['opening_hours']?.toString(),
        isIndoor: _isIndoorFromTags(tags),
        ageHint: tags['min_age'] != null || tags['max_age'] != null
            ? '${tags['min_age'] ?? ''}-${tags['max_age'] ?? ''}'.replaceAll(RegExp(r'[^0-9-]'), '')
            : null,
      );
      places.add(place);
    }

    return places;
  }

  static FamilyPlaceCategory? _categoryFromTags(Map<String, dynamic> tags) {
    final leisure = tags['leisure']?.toString();
    final amenity = tags['amenity']?.toString();

    if (leisure == 'playground' || leisure == 'children_playground') {
      return FamilyPlaceCategory.playground;
    }
    if (amenity == 'community_centre') {
      return FamilyPlaceCategory.familyCenter;
    }
    if (leisure == 'indoor_play' || leisure == 'indoor_playground') {
      return FamilyPlaceCategory.indoorPlayground;
    }
    if (leisure == 'swimming_pool' || leisure == 'water_park') {
      return FamilyPlaceCategory.swimmingPool;
    }
    if (tags['sport'] == 'swimming' || tags['swimming'] == 'pool') {
      return FamilyPlaceCategory.swimCourse;
    }
    return null;
  }

  static bool? _isIndoorFromTags(Map<String, dynamic> tags) {
    final leisure = tags['leisure']?.toString();
    final amenity = tags['amenity']?.toString();

    if (leisure == 'indoor_play' || leisure == 'indoor_playground') return true;
    if (amenity == 'community_centre') return false;
    if (leisure == 'playground') return false;
    if (leisure == 'swimming_pool' || leisure == 'water_park') return false;
    return null;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  static int? _parseTime(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[^0-9:]'), '');
    if (clean.isEmpty) return null;
    final parts = clean.split(':');
    if (parts.isEmpty || parts.length > 2) return null;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return hours * 60 + minutes;
  }
}
