import 'dart:async';
import 'dart:convert';

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
    final query = address.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.length < 2) return Future.value(null);
    final key = query.toLowerCase();
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < cacheTtl) {
      return Future.value(cached.$2);
    }
    return _inflight[key] ??= _resolveQueued(key, query);
  }

  Future<(double, double)?> _resolveQueued(String key, String query) async {
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
              'format': 'json',
              'limit': '1',
            }),
            headers: kIsWeb ? const {} : {'User-Agent': 'ParentPeak-App/1.0'},
          )
          .timeout(timeout);
      (double, double)? result;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data.first is Map) {
          final latitude = double.tryParse(data.first['lat'].toString());
          final longitude = double.tryParse(data.first['lon'].toString());
          if (reliableEventCoordinates(latitude, longitude)) {
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

  void _remember(String key, (double, double)? result) {
    _cache.removeWhere(
      (_, entry) => DateTime.now().difference(entry.$1) >= cacheTtl,
    );
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    _cache[key] = (DateTime.now(), result);
  }
}
