'use strict';

// The public OSRM demo is suitable for development/testing only. Production deployments
// should set DELIVERY_ROUTING_BASE_URL to a compliant hosted or self-hosted OSRM service.
const CACHE_TTL_MS = 60 * 1000;
const ROUTE_CACHE = new Map();

async function getDrivingRoute({ assignmentId, origin, destination, fetchImpl = globalThis.fetch, now = Date.now() }) {
  const values = [origin?.latitude, origin?.longitude, destination?.latitude, destination?.longitude].map(Number);
  if (!values.every(Number.isFinite) || values[0] < -90 || values[0] > 90 ||
      values[2] < -90 || values[2] > 90 || values[1] < -180 || values[1] > 180 ||
      values[3] < -180 || values[3] > 180 || !fetchImpl) return null;

  const [originLat, originLon, destinationLat, destinationLon] = values;
  const cacheKey = String(assignmentId || '') + ':' + values.join(',');
  const cached = ROUTE_CACHE.get(cacheKey);
  if (cached && cached.expiresAt > now) return cached.value;
  const baseUrl = (process.env.DELIVERY_ROUTING_BASE_URL || 'https://router.project-osrm.org').replace(/\/$/, '');
  const url = baseUrl + '/route/v1/driving/' +
    originLon + ',' + originLat + ';' + destinationLon + ',' + destinationLat +
    '?overview=simplified&geometries=geojson&steps=false';
  try {
    const response = await fetchImpl(url, { signal: AbortSignal.timeout(5000) });
    if (!response.ok) return null;
    const payload = await response.json();
    const route = payload?.code === 'Ok' ? payload.routes?.[0] : null;
    const distanceMeters = Number(route?.distance);
    const durationSeconds = Number(route?.duration);
    const coordinates = route?.geometry?.coordinates;
    if (!Number.isFinite(distanceMeters) || distanceMeters <= 0 ||
        !Number.isFinite(durationSeconds) || durationSeconds <= 0 ||
        !Array.isArray(coordinates) || coordinates.length < 2) return null;
    const value = {
      distanceKm: Number((distanceMeters / 1000).toFixed(2)),
      etaMinutes: Math.max(1, Math.ceil(durationSeconds / 60)),
      geometry: coordinates.filter(point => Array.isArray(point) && point.length >= 2 &&
        Number.isFinite(Number(point[0])) && Number.isFinite(Number(point[1])))
        .map(point => [Number(point[1]), Number(point[0])])
    };
    if (value.geometry.length < 2) return null;
    ROUTE_CACHE.set(cacheKey, { value, expiresAt: now + CACHE_TTL_MS });
    return value;
  } catch (_) {
    return null;
  }
}

function clearRouteCache() {
  ROUTE_CACHE.clear();
}

module.exports = { getDrivingRoute, clearRouteCache, CACHE_TTL_MS };
