import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central location service — single source of truth for user location.
/// Used by: Events, Verschenkmarkt, Spielfreunde, and any future feature.
///
/// Supports: GPS (automatic) or PLZ/City (manual fallback).
/// DSGVO: Only city-level precision shared. Exact GPS stays local.
class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  static const String _latKey = 'location.latitude';
  static const String _lngKey = 'location.longitude';
  static const String _cityKey = 'location.city';
  static const String _methodKey = 'location.method'; // 'gps' or 'manual'

  double? _latitude;
  double? _longitude;
  String? _city;
  String? _method;

  /// Current latitude (null if not set)
  double? get latitude => _latitude;

  /// Current longitude (null if not set)
  double? get longitude => _longitude;

  /// City name or PLZ (for display)
  String? get city => _city;

  /// Whether location is available
  bool get hasLocation => _latitude != null && _longitude != null;

  /// How location was determined
  String? get method => _method;

  /// Initialize from SharedPreferences (call at app start)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _latitude = prefs.getDouble(_latKey);
    _longitude = prefs.getDouble(_lngKey);
    _city = prefs.getString(_cityKey);
    _method = prefs.getString(_methodKey);
  }

  /// Try to get GPS location. Returns true if successful.
  /// Shows system permission dialog if needed.
  Future<bool> requestGPSLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // City-level, not exact (privacy)
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _method = 'gps';
      await _save();
      return true;
    } catch (e) {
      debugPrint('LocationService.requestGPSLocation failed: $e');
      return false;
    }
  }

  /// Set location manually from PLZ/City input.
  /// Uses a simple geocoding lookup for German/Austrian/Swiss PLZ.
  Future<void> setManualLocation(String input) async {
    _city = input.trim();
    _method = 'manual';

    // Simple PLZ → coordinates mapping for major areas
    final coords = _geocodePLZ(input.trim());
    if (coords != null) {
      _latitude = coords.$1;
      _longitude = coords.$2;
    } else {
      // Fallback: center of Germany if we can't geocode
      _latitude = 51.1657;
      _longitude = 10.4515;
    }
    await _save();
  }

  /// Set location from known coordinates (e.g. from onboarding city picker)
  Future<void> setCoordinates(double lat, double lng, {String? city}) async {
    _latitude = lat;
    _longitude = lng;
    _city = city;
    _method = city != null ? 'manual' : 'gps';
    await _save();
  }

  /// Calculate distance in km from user to a point
  double? distanceTo(double lat, double lng) {
    if (!hasLocation) return null;
    return _haversineDistance(_latitude!, _longitude!, lat, lng);
  }

  /// Format distance for display: "2,3 km" or "800 m"
  String? distanceText(double lat, double lng) {
    final d = distanceTo(lat, lng);
    if (d == null) return null;
    if (d < 1.0) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  /// Clear stored location
  Future<void> clear() async {
    _latitude = null;
    _longitude = null;
    _city = null;
    _method = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
    await prefs.remove(_cityKey);
    await prefs.remove(_methodKey);
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_latitude != null) await prefs.setDouble(_latKey, _latitude!);
    if (_longitude != null) await prefs.setDouble(_lngKey, _longitude!);
    if (_city != null) await prefs.setString(_cityKey, _city!);
    if (_method != null) await prefs.setString(_methodKey, _method!);
  }

  /// Haversine formula for distance between two GPS points
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  /// Simple PLZ geocoding for DACH region (most common cities)
  (double, double)? _geocodePLZ(String input) {
    final clean = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß ]'), '');

    // German PLZ ranges (approximate centers)
    if (RegExp(r'^\d{5}$').hasMatch(clean)) {
      final plz = int.parse(clean);
      if (plz >= 10000 && plz <= 14999) return (52.52, 13.405); // Berlin
      if (plz >= 20000 && plz <= 22999) return (53.55, 9.99); // Hamburg
      if (plz >= 80000 && plz <= 81999) return (48.14, 11.58); // München
      if (plz >= 50000 && plz <= 51999) return (50.94, 6.96); // Köln
      if (plz >= 60000 && plz <= 60999) return (50.11, 8.68); // Frankfurt
      if (plz >= 70000 && plz <= 70999) return (48.78, 9.18); // Stuttgart
      if (plz >= 40000 && plz <= 40999) return (51.23, 6.78); // Düsseldorf
      if (plz >= 44000 && plz <= 44999) return (51.51, 7.47); // Dortmund
      if (plz >= 45000 && plz <= 45999) return (51.46, 7.01); // Essen
      if (plz >= 30000 && plz <= 30999) return (52.37, 9.74); // Hannover
      if (plz >= 28000 && plz <= 28999) return (53.08, 8.80); // Bremen
      if (plz >= 01000 && plz <= 01999) return (51.05, 13.74); // Dresden
      if (plz >= 04000 && plz <= 04999) return (51.34, 12.37); // Leipzig
      if (plz >= 90000 && plz <= 90999) return (49.45, 11.08); // Nürnberg
      // Generic: map PLZ to rough lat/lng
      final lat = 47.3 + (plz / 100000.0) * 7.0;
      final lng = 6.0 + (plz % 10000 / 10000.0) * 9.0;
      return (lat, lng);
    }

    // City name mapping
    const cities = {
      'berlin': (52.52, 13.405),
      'hamburg': (53.55, 9.99),
      'münchen': (48.14, 11.58),
      'munich': (48.14, 11.58),
      'köln': (50.94, 6.96),
      'frankfurt': (50.11, 8.68),
      'stuttgart': (48.78, 9.18),
      'düsseldorf': (51.23, 6.78),
      'dortmund': (51.51, 7.47),
      'essen': (51.46, 7.01),
      'hannover': (52.37, 9.74),
      'bremen': (53.08, 8.80),
      'dresden': (51.05, 13.74),
      'leipzig': (51.34, 12.37),
      'nürnberg': (49.45, 11.08),
      'wien': (48.21, 16.37),
      'zürich': (47.38, 8.54),
      'istanbul': (41.01, 28.98),
      'ankara': (39.93, 32.85),
      'london': (51.51, -0.13),
    };

    for (final entry in cities.entries) {
      if (clean.contains(entry.key)) return entry.value;
    }

    return null;
  }
}
