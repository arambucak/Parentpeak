const { coarseCoordinate } = require('./treasure_public_view');

function position(latitude, longitude) {
  if ([latitude, longitude].some(value => value === null || value === undefined ||
    !['number', 'string'].includes(typeof value) ||
    String(value).trim() === '' || !Number.isFinite(Number(value))) ||
    Math.abs(Number(latitude)) > 90 || Math.abs(Number(longitude)) > 180) return null;
  const lat = coarseCoordinate(latitude);
  const lon = coarseCoordinate(longitude);
  return lat !== null && lon !== null && Math.abs(lat) <= 90 && Math.abs(lon) <= 180
    ? { latitude: lat, longitude: lon } : null;
}

function distanceKm(a, b) {
  const first = position(a.latitude, a.longitude);
  const second = position(b.latitude, b.longitude);
  if (!first || !second) return null;
  const radians = value => value * Math.PI / 180;
  const dLat = radians(second.latitude - first.latitude);
  const dLon = radians(second.longitude - first.longitude);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(first.latitude)) * Math.cos(radians(second.latitude)) * Math.sin(dLon / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, h))));
}

function radiusKm(value, fallback = 10) {
  if (value !== undefined && value !== null && !['number', 'string'].includes(typeof value)) return null;
  const number = value === undefined || value === null ? fallback : Number(value);
  return Number.isFinite(number) && number > 0 ? Math.min(Math.max(number, 1), 25) : null;
}

function discover(treasures, viewer, requestedRadius) {
  return treasures.map(treasure => {
    const km = distanceKm(viewer, treasure);
    return { treasure, distance: km === null ? null : Math.round(km * 1000) / 1000 };
  })
    .filter(({ treasure, distance }) => distance !== null &&
      distance <= Math.min(requestedRadius, radiusKm(treasure.shareRadiusKm) ?? 0))
    .sort((a, b) => a.distance - b.distance);
}

module.exports = { position, distanceKm, radiusKm, discover };
