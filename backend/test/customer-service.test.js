'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizePhone } = require('../src/services/customer-service');

test('normalizes Pakistan phone formatting without changing digits', () => {
  assert.equal(normalizePhone('+92 300-1234567'), '+923001234567');
});
test('rejects phone numbers containing letters', () => {
  assert.throws(() => normalizePhone('0300ABC4567'), /7 to 15 digits/);
});
test('rejects phone numbers that are too short', () => {
  assert.throws(() => normalizePhone('12345'), /7 to 15 digits/);
});
