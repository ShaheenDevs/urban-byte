'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { estimateDeliveryEtaMinutes } = require('../src/services/delivery-eta');

test('estimates ETA from recorded delivery distance and elapsed dispatch time', () => {
  const started = new Date('2026-11-24T12:00:00.000Z');
  assert.equal(estimateDeliveryEtaMinutes(5, started, new Date('2026-11-24T12:00:00.000Z')), 20);
  assert.equal(estimateDeliveryEtaMinutes(5, started, new Date('2026-11-24T12:10:00.000Z')), 10);
});

test('keeps a minimum one-minute ETA until delivery is completed', () => {
  assert.equal(estimateDeliveryEtaMinutes(1, '2026-11-24T12:00:00.000Z', '2026-11-24T13:00:00.000Z'), 1);
});

test('returns null when distance or dispatch timestamp is unavailable', () => {
  assert.equal(estimateDeliveryEtaMinutes(null, new Date()), null);
  assert.equal(estimateDeliveryEtaMinutes(4, null), null);
  assert.equal(estimateDeliveryEtaMinutes(0, new Date()), null);
  assert.equal(estimateDeliveryEtaMinutes(251, new Date()), null);
});
