'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { validDate, validTime } = require('../src/services/employee-shift-validation');
const employeeShiftService = require('../src/services/employee-shift-service');

test('validDate accepts real ISO calendar dates only', () => {
  assert.equal(validDate('2026-11-23'), true);
  assert.equal(validDate('2026-02-29'), false);
  assert.equal(validDate('2026-13-01'), false);
  assert.equal(validDate('23-11-2026'), false);
});

test('validTime accepts 24-hour times with optional seconds', () => {
  assert.equal(validTime('09:30'), true);
  assert.equal(validTime('23:59:59'), true);
  assert.equal(validTime('24:00'), false);
  assert.equal(validTime('9:30'), false);
  assert.equal(validTime('12:60'), false);
});

test('employee shift service loads and exposes its public operations', () => {
  assert.equal(typeof employeeShiftService.create, 'function');
  assert.equal(typeof employeeShiftService.list, 'function');
  assert.equal(typeof employeeShiftService.cancel, 'function');
});
