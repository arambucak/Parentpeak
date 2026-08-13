import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Autocomplete für Orte via OpenStreetMap Nominatim (kostenlos, kein API-Key).
class LocationAutocompleteService {
  static final LocationAutocompleteService instance =
      LocationAutocompleteService._();
  LocationAutocompleteService._();

  Timer? _debounce;
  String _lastQuery = '';

  /// Sucht Orte basierend auf Eingabe. Gibt maximal 5 Vorschlaege zurück.
  /// Debounced: wartet 400ms nach letzter Eingabe bevor Request gesendet wird.
  Future<List<LocationSuggestion>> search(String query) async {
    if (query.trim().length < 2) return [];
    if (query.trim() == _lastQuery) return [];
    _lastQuery = query.trim();

    final completer = Completer<List<LocationSuggestion>>();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _fetchSuggestions(query.trim());
        if (!completer.isCompleted) completer.complete(results);
      } catch (_) {
        if (!completer.isCompleted) completer.complete([]);
      }
    });

    return completer.future;
  }

  /// Direkter Aufruf ohne Debounce (für programmatische Nutzung).
  Future<List<LocationSuggestion>> searchImmediate(String query) async {
    if (query.trim().length < 2) return [];
    return _fetchSuggestions(query.trim());
  }

  Future<List<LocationSuggestion>> _fetchSuggestions(String query) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&format=json'
      '&addressdetails=1'
      '&limit=5'
      '&accept-language=de',
    );

    final response = await http.get(uri, headers: {
      'User-Agent': 'ParentPeak-App/1.0',
    });

    if (response.statusCode != 200) return [];

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) {
      final address = item['address'] as Map<String, dynamic>? ?? {};
      return LocationSuggestion(
        displayName: _buildDisplayName(item, address),
        district: address['suburb'] ??
            address['neighbourhood'] ??
            address['city_district'] ??
            address['quarter'] ??
            '',
        city: address['city'] ??
            address['town'] ??
            address['village'] ??
            address['municipality'] ??
            '',
        postcode: address['postcode'] ?? '',
        lat: double.tryParse(item['lat']?.toString() ?? '') ?? 0,
        lon: double.tryParse(item['lon']?.toString() ?? '') ?? 0,
      );
    }).toList();
  }

  String _buildDisplayName(
      Map<String, dynamic> item, Map<String, dynamic> address) {
    final parts = <String>[];
    final suburb = address['suburb'] ??
        address['neighbourhood'] ??
        address['city_district'] ??
        address['quarter'];
    final city = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'];
    final postcode = address['postcode'];

    if (suburb != null) parts.add(suburb);
    if (city != null && city != suburb) parts.add(city);
    if (postcode != null) parts.add(postcode);

    if (parts.isEmpty) {
      // Fallback: Nutze den vollen display_name, gekuerzt
      final full = item['display_name']?.toString() ?? '';
      final segments = full.split(',');
      return segments.take(3).join(',').trim();
    }
    return parts.join(', ');
  }

  void dispose() {
    _debounce?.cancel();
  }
}

class LocationSuggestion {
  final String displayName;
  final String district;
  final String city;
  final String postcode;
  final double lat;
  final double lon;

  const LocationSuggestion({
    required this.displayName,
    required this.district,
    required this.city,
    required this.postcode,
    required this.lat,
    required this.lon,
  });

  /// Kurzform für Anzeige im Profil
  String get shortLabel {
    if (district.isNotEmpty && city.isNotEmpty) {
      return '$district, $city';
    }
    if (city.isNotEmpty && postcode.isNotEmpty) {
      return '$postcode $city';
    }
    return displayName;
  }
}
