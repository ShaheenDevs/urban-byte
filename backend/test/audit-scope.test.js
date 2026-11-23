'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { scope } = require('../src/services/audit-service');

test('audit filters restrict employees to assigned branches', () => {
  assert.deepEqual(scope({ roles: ['waiter'], branchIds: [2, 4] }), { branchId: { [require('sequelize').Op.in]: [2, 4] } });
  assert.deepEqual(scope({ roles: ['waiter'], branchIds: [2, 4] }, { branchId: '4', action: 'purchase' }), {
    branchId: 4, action: { [require('sequelize').Op.like]: '%purchase%' },
  });
  assert.throws(() => scope({ roles: ['waiter'], branchIds: [2] }, { branchId: 3 }), (error) => error.statusCode === 403 && error.code === 'BRANCH_FORBIDDEN');
});

test('audit filters allow owner all-branch view and validate dates', () => {
  assert.deepEqual(scope({ roles: ['admin'], branchIds: [] }, { entityType: 'purchase', actorUserId: '8' }), { actorUserId: 8, entityType: 'purchase' });
  assert.throws(() => scope({ roles: ['admin'] }, { from: '2026-02-30' }));
  assert.throws(() => scope({ roles: ['admin'] }, { from: '2026-11-24', to: '2026-11-23' }));
});
