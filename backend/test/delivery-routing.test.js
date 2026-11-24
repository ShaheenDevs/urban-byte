'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { getDrivingRoute, clearRouteCache, CACHE_TTL_MS } = require('../src/services/delivery-routing');

test('parses a road route into ETA, distance and Leaflet coordinates', async () => {
  clearRouteCache();
  const result = await getDrivingRoute({
    assignmentId: 'route-test-1',
    origin: { latitude: 31.5, longitude: 73.5 },
    destination: { latitude: 31.51, longitude: 73.51 },
    fetchImpl: async url => {
      assert.match(url, /route\/v1\/driving\/73\.5,31\.5;73\.51,31\.51/);
      return { ok: true, json: async () => ({ code: 'Ok', routes: [{
        distance: 4250, duration: 720,
        geometry: { coordinates: [[73.5, 31.5], [73.505, 31.505], [73.51, 31.51]] }
      }] }) };
    }
  });
  assert.deepEqual(result, {
    distanceKm: 4.25,
    etaMinutes: 12,
    geometry: [[31.5, 73.5], [31.505, 73.505], [31.51, 73.51]]
  });
});

test('caches route results for one minute to avoid routing on every tracking poll', async () => {
  clearRouteCache();
  let calls = 0;
  const args = {
    assignmentId: 'route-cache-test',
    origin: { latitude: 31.5, longitude: 73.5 },
    destination: { latitude: 31.51, longitude: 73.51 },
    now: 1000,
    fetchImpl: async () => {
      calls++;
      return { ok: true, json: async () => ({ code: 'Ok', routes: [{
        distance: 1000, duration: 300, geometry: { coordinates: [[73.5,31.5],[73.51,31.51]] }
      }] }) };
    }
  };
  await getDrivingRoute(args);
  await getDrivingRoute({ ...args, now: 1000 + CACHE_TTL_MS - 1 });
  assert.equal(calls, 1);
});

test('returns null for invalid coordinates or unavailable routing service', async () => {
  assert.equal(await getDrivingRoute({ origin: { latitude: 999, longitude: 0 }, destination: { latitude: 0, longitude: 0 } }), null);
  assert.equal(await getDrivingRoute({
    assignmentId: 'route-fallback-test',
    origin: { latitude: 31.5, longitude: 73.5 },
    destination: { latitude: 31.51, longitude: 73.51 },
    fetchImpl: async () => ({ ok: false, json: async () => ({}) })
  }), null);
});
