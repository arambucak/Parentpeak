import 'dart:math' as math;

class TreasureGeometry {
  // Match the existing public backend projection, including negative half ties.
  static double coarse(double value) => (value * 100 + 0.5).floor() / 100;

  static double? distanceKm(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (!validPosition(lat1, lon1) || !validPosition(lat2, lon2)) return null;
    final aLat = coarse(lat1!);
    final bLat = coarse(lat2!);
    final dLat = (bLat - aLat) * math.pi / 180;
    final dLon = (coarse(lon2!) - coarse(lon1!)) * math.pi / 180;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(aLat * math.pi / 180) *
            math.cos(bLat * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    return 12742 * math.asin(math.sqrt(h.clamp(0, 1)));
  }

  static bool validPosition(double? lat, double? lon) =>
      lat != null &&
      lon != null &&
      lat.isFinite &&
      lon.isFinite &&
      lat.abs() <= 90 &&
      lon.abs() <= 180;

  static int? distanceMeters(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    final km = distanceKm(lat1, lon1, lat2, lon2);
    return km == null ? null : (km * 1000).round();
  }

  static double radius(double value) {
    if (!value.isFinite || value < 1 || value > 25) {
      throw const FormatException(
        'Treasure radius must be between 1 and 25 km',
      );
    }
    return value;
  }

  static bool withinRadius(int distanceMeters, double shareRadiusKm) =>
      distanceMeters >= 0 && distanceMeters <= radius(shareRadiusKm) * 1000;

  static double readRadius(Object? value, {double fallback = 1}) {
    if (value == null) return radius(fallback);
    final number = double.tryParse(value.toString());
    if (number == null) throw const FormatException('Invalid treasure radius');
    return radius(number);
  }
}
