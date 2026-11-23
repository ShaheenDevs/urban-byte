'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { range } = require('../src/services/report-service');

test('report date ranges use Pakistan local midnight boundaries', () => {
  const result = range({ from: '2026-11-24', to: '2026-11-25' });
  assert.equal(result.from, '2026-11-24');
  assert.equal(result.to, '2026-11-25');
  assert.equal(result.start.toISOString(), '2026-11-23T19:00:00.000Z');
  assert.equal(result.end.toISOString(), '2026-11-25T19:00:00.000Z');
});

test('report date ranges reject impossible calendar dates', () => {
  assert.throws(() => range({ from: '2026-02-31', to: '2026-03-01' }), {
    code: 'INVALID_REPORT_FILTER',
    message: 'Use a valid YYYY-MM-DD date range.',
  });
  assert.throws(() => range({ from: '2025-02-29' }), {
    code: 'INVALID_REPORT_FILTER',
  });
});

test('report date ranges accept leap days and reject reversed ranges', () => {
  assert.equal(range({ from: '2024-02-29' }).from, '2024-02-29');
  assert.throws(() => range({ from: '2026-11-25', to: '2026-11-24' }), {
    code: 'INVALID_REPORT_FILTER',
  });
});
