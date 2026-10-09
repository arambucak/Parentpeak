import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:parentpeak/logic/event_geocoder.dart';
import 'package:parentpeak/logic/profile_account_store.dart';

/// Central location service — single source of truth for user location.
/// Used by: Events, Verschenkmarkt, Spielfreunde, and any future feature.
///
/// Supports: GPS (automatic) or PLZ/City (manual fallback).
/// Coordinates are stored and reverse-geocoded at two-decimal precision.
class LocationService extends ChangeNotifier {
  static final LocationService instance = LocationService();
  LocationService({ProfileAccountStore? store, http.Client? httpClient,
    Future<(double, double)> Function()? gpsProvider})
      : _store = store ?? ProfileAccountStore.instance,
        _httpClient = httpClient,
        _gpsProvider = gpsProvider {
    _store.addListener(_reload);
  }
  final ProfileAccountStore _store;
  final http.Client? _httpClient;
  final Future<(double, double)> Function()? _gpsProvider;
  ProfileAccountTicket? _loaded;
  int _loadRequest = 0;
  int _operation = 0;
  bool loadFailed = false;

  static const String _latKey = 'location.latitude';
  static const String _lngKey = 'location.longitude';
  static const String _cityKey = 'location.city';
  static const String _methodKey = 'location.method'; // 'gps' or 'manual'

  double? _latitude;
  double? _longitude;
  String? _city;
  String? _method;

  /// Current latitude (null if not set)
  double? get latitude { _guardCache(); return _latitude; }

  /// Current longitude (null if not set)
  double? get longitude { _guardCache(); return _longitude; }

  /// City name or PLZ (for display)
  String? get city { _guardCache(); return _city; }

  /// Whether location is available
  bool get hasLocation => latitude != null && longitude != null;

  /// How location was determined
  String? get method { _guardCache(); return _method; }

  void _guardCache() {
    if (_loaded == null || !_store.isCurrent(_loaded!)) {
      _latitude = null; _longitude = null; _city = null; _method = null;
    }
  }

  void _reload() {
    _guardCache();
    initialize();
  }

  /// Initialize from SharedPreferences (call at app start)
  Future<void> initialize() async {
    final ticket = _store.ticket;
    final request = ++_loadRequest;
    _guardCache();
    try {
      final data = await _store.read(ticket);
      if (request != _loadRequest || !_store.isCurrent(ticket)) return;
      _latitude = (data[_latKey] as num?)?.toDouble();
      _longitude = (data[_lngKey] as num?)?.toDouble();
      _city = data[_cityKey] as String?;
      _method = data[_methodKey] as String?;
      _loaded = ticket;
      loadFailed = false;
      notifyListeners();
    } on ProfileAccountChanged {
      // A new session reloads its own location.
    } catch (error) {
      debugPrint('Account location load failed: $error');
      if (request == _loadRequest && _store.isCurrent(ticket)) {
        _loaded = null; _guardCache(); loadFailed = true; notifyListeners();
      }
    }
  }

  /// Try to get GPS location. Returns true if successful.
  /// Shows system permission dialog if needed.
  Future<bool> requestGPSLocation() async {
    final ticket = _store.ticket;
    final operation = ++_operation;
    try {
      final provider = _gpsProvider;
      if (provider != null) {
        final coords = await provider();
        _requireOperation(ticket, operation);
        final city = await _reverseGeocodeAndSetCity(coords.$1, coords.$2);
        _requireOperation(ticket, operation);
        await _save(ticket, operation, coords.$1, coords.$2, city, 'gps');
        return true;
      }
      // On web, isLocationServiceEnabled() is unreliable — browsers don't expose
      // a system-level GPS toggle. Skip this check on web.
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return false;
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      // Get position — web uses WiFi/IP geolocation which is slower
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // City-level, not exact (privacy)
          timeLimit: kIsWeb ? Duration(seconds: 20) : Duration(seconds: 10),
        ),
      );

      _requireOperation(ticket, operation);
      final city = await _reverseGeocodeAndSetCity(position.latitude, position.longitude);
      _requireOperation(ticket, operation);
      await _save(ticket, operation, position.latitude, position.longitude, city, 'gps');
      return true;
    } catch (e) {
      debugPrint('LocationService.requestGPSLocation failed: $e');
      return false;
    }
  }

  /// Set location manually from PLZ/City input.
  /// Uses a simple geocoding lookup for German/Austrian/Swiss PLZ.
  Future<void> setManualLocation(String input) async {
    final ticket = _store.ticket;
    final operation = ++_operation;
    final coords =
        _geocodePLZ(input.trim()) ?? await _forwardGeocode(input.trim());
    _requireOperation(ticket, operation);
    await _save(ticket, operation, coords?.$1, coords?.$2, input.trim(), 'manual');
  }

  /// Set location from known coordinates (e.g. from onboarding city picker)
  Future<void> setCoordinates(double lat, double lng, {String? city}) async {
    final ticket = _store.ticket;
    final operation = ++_operation;
    await _save(ticket, operation, lat, lng, city, city != null ? 'manual' : 'gps');
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
    final ticket = _store.ticket;
    final operation = ++_operation;
    await _save(ticket, operation, null, null, null, null);
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  /// Reverse geocode coordinates to get a city name via Nominatim
  Future<String?> _reverseGeocodeAndSetCity(double lat, double lng) async {
    try {
      final latitude = roundCoordinate(lat);
      final longitude = roundCoordinate(lng);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json&addressdetails=1',
      );
      // User-Agent is forbidden in browser Fetch API — skip on web
      final headers = kIsWeb
          ? <String, String>{}
          : {'User-Agent': 'ParentPeak/1.0 (family app)'};
      final resp = await (_httpClient?.get(uri, headers: headers) ??
          http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final cityName = address?['city'] as String? ??
            address?['town'] as String? ??
            address?['village'] as String?;
        final suburb =
            address?['suburb'] as String? ?? address?['quarter'] as String?;
        if (suburb != null && cityName != null) {
          return '$suburb, $cityName';
        } else if (cityName != null) {
          return cityName;
        }
        return null;
      }
    } catch (e) {
      debugPrint('LocationService._reverseGeocodeAndSetCity failed: $e');
      // Non-fatal: location still works without city name
    }
    return null;
  }

  Future<(double, double)?> _forwardGeocode(String query) async {
    if (query.isEmpty) return null;
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {'q': query, 'format': 'json', 'limit': '1'},
      );
      final headers = kIsWeb
          ? <String, String>{}
          : {'User-Agent': 'ParentPeak/1.0 (family app)'};
      final response = await (_httpClient?.get(uri, headers: headers) ??
          http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body);
      if (results is! List || results.isEmpty || results.first is! Map) {
        return null;
      }
      final result = Map<String, dynamic>.from(results.first as Map);
      final latitude = double.tryParse(result['lat']?.toString() ?? '');
      final longitude = double.tryParse(result['lon']?.toString() ?? '');
      return latitude != null && longitude != null
          ? (latitude, longitude)
          : null;
    } catch (e) {
      debugPrint('LocationService._forwardGeocode failed: $e');
      return null;
    }
  }

  void _requireOperation(ProfileAccountTicket ticket, int operation) {
    _store.require(ticket);
    if (operation != _operation) throw const ProfileAccountChanged();
  }

  Future<void> _save(ProfileAccountTicket ticket, int operation,
      double? lat, double? lng, String? city, String? method) async {
    _requireOperation(ticket, operation);
    await _store.update(ticket, (data) {
      _requireOperation(ticket, operation);
      for (final key in [_latKey, _lngKey, _cityKey, _methodKey]) {
        data.remove(key);
      }
      if (lat != null) data[_latKey] = roundCoordinate(lat);
      if (lng != null) data[_lngKey] = roundCoordinate(lng);
      if (city != null) data[_cityKey] = city;
      if (method != null) data[_methodKey] = method;
    });
    _requireOperation(ticket, operation);
    await initialize();
  }

  @override
  void dispose() {
    _store.removeListener(_reload);
    super.dispose();
  }

  /// Haversine formula for distance between two GPS points
  double _haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
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
