'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { resolvePermissions } = require('../src/services/permission-resolver');
test('combines permissions from multiple roles without duplicates', () => {
  assert.deepEqual(resolvePermissions(['orders.view', 'menu.view'], []), ['menu.view', 'orders.view']);
});
test('explicit user deny overrides role grants', () => {
  assert.deepEqual(resolvePermissions(['orders.cancel', 'orders.view'], [{ permissionKey: 'orders.cancel', effect: 'deny' }]), ['orders.view']);
});
test('explicit user allow grants an additional permission', () => {
  assert.deepEqual(resolvePermissions(['orders.view'], [{ permissionKey: 'reports.view', effect: 'allow' }]), ['orders.view', 'reports.view']);
});
