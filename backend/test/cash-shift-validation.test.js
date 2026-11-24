'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { amount, dateRange } = require('../src/services/cash-shift-validation');

test('cash amount validation accepts zero only when permitted', () => {
  assert.equal(amount(0), '0.00');
  assert.equal(amount('125.5'), '125.50');
  assert.throws(() => amount(-1));
  assert.throws(() => amount('NaN'));
  assert.throws(() => amount(0, false));
});

test('cash report date range validates real calendar dates and Pakistan day bounds', () => {
  const range = dateRange({ from: '2026-11-23', to: '2026-11-23' });
  assert.equal(range.from.toISOString(), '2026-11-22T19:00:00.000Z');
  assert.equal(range.to.toISOString(), '2026-11-23T19:00:00.000Z');
  assert.throws(() => dateRange({ from: '2026-02-30' }));
  assert.throws(() => dateRange({ from: '2026-11-24', to: '2026-11-23' }));
});
