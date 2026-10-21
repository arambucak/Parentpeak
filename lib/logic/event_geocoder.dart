import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

bool validCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    !(latitude == 0 && longitude == 0);

bool reliableEventCoordinates(double? latitude, double? longitude) =>
    validCoordinates(latitude, longitude);

/// Datensparsamkeit: Rundet eine Koordinate auf [fractionDigits] Nachkommastellen.
///
/// Für die Umkreissuche nach Events reicht eine grobe Verortung völlig aus. Mit
/// dem Standard von 2 Nachkommastellen liegt die Genauigkeit bei rund 1 km, statt
/// den metergenauen Aufenthaltsort einer Familie an Backend oder KI-Dienst zu
/// übertragen. Die Rundung ist bewusst zentral und testbar, damit alle Pfade
/// (Backend-Query und KI-Prompt) dieselbe Datensparsamkeit nutzen.
double roundCoordinate(double value, {int fractionDigits = 2}) {
  if (!value.isFinite) return value;
  final factor = math.pow(10, fractionDigits).toDouble();
  return (value * factor).roundToDouble() / factor;
}

class EventGeocoder {
  EventGeocoder({
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
    this.minimumInterval = const Duration(seconds: 1),
    this.cacheTtl = const Duration(minutes: 15),
  }) : _client = client ?? http.Client();

  static final instance = EventGeocoder();
  final http.Client _client;
  final Duration timeout;
  final Duration minimumInterval;
  final Duration cacheTtl;
  final _cache = <String, (DateTime, (double, double)?)>{};
  final _inflight = <String, Future<(double, double)?>>{};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;

  Future<(double, double)?> resolve(String address) {
    return _resolve(address, requireVenue: false);
  }

  /// A city, district or road centroid is not a confirmed event venue.
  Future<(double, double)?> resolveVenue(String address) {
    return _resolve(address, requireVenue: true);
  }

  Future<(double, double)?> _resolve(String address, {required bool requireVenue}) {
    final query = address.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.length < 2) return Future.value(null);
    final key = '${requireVenue ? 'venue:' : 'area:'}${query.toLowerCase()}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < cacheTtl) {
      return Future.value(cached.$2);
    }
    return _inflight[key] ??= _resolveQueued(key, query, requireVenue: requireVenue);
  }

  Future<(double, double)?> _resolveQueued(String key, String query,
      {required bool requireVenue}) async {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    try {
      await previous;
      final last = _lastRequest;
      if (last != null) {
        final remaining = minimumInterval - DateTime.now().difference(last);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      _lastRequest = DateTime.now();
      final response = await _client
          .get(
            Uri.https('nominatim.openstreetmap.org', '/search', {
              'q': query,
              'format': requireVenue ? 'jsonv2' : 'json',
              'limit': '1',
            }),
            headers: kIsWeb ? const {} : {'User-Agent': 'ParentPeak-App/1.0'},
          )
          .timeout(timeout);
      (double, double)? result;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data.first is Map) {
          final match = data.first as Map;
          final latitude = double.tryParse(match['lat'].toString());
          final longitude = double.tryParse(match['lon'].toString());
          if (reliableEventCoordinates(latitude, longitude) &&
              (!requireVenue || _isVenue(match))) {
            result = (latitude!, longitude!);
          }
        }
      }
      _remember(key, result);
      return result;
    } catch (_) {
      _remember(key, null);
      return null;
    } finally {
      _inflight.remove(key);
      done.complete();
    }
  }

  bool _isVenue(Map match) {
    final category = match['category'] ?? match['class'];
    if (const {
      'country', 'state', 'region', 'county', 'municipality', 'city', 'town',
      'village', 'hamlet', 'suburb', 'quarter', 'neighbourhood', 'road',
    }.contains(match['addresstype']) || category == 'boundary') {
      return false;
    }
    final rawRank = match['place_rank'];
    if (rawRank != null) {
      final rank = num.tryParse('$rawRank');
      return rank != null && rank.isFinite && rank >= 28 && rank <= 30;
    }
    return const {
      'amenity', 'tourism', 'leisure', 'shop', 'building', 'historic',
    }.contains(category);
  }

  void _remember(String key, (double, double)? result) {
    _cache.removeWhere(
      (_, entry) => DateTime.now().difference(entry.$1) >= cacheTtl,
    );
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    _cache[key] = (DateTime.now(), result);
  }
}
