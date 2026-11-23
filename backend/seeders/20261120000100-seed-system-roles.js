'use strict';
const roles = [
  ['Admin', 'admin', 'Full restaurant and system administration'],
  ['Supervisor', 'supervisor', 'Operational management and authorized exception approvals'],
  ['Waiter', 'waiter', 'Tables and customer order handling'],
  ['Kitchen', 'kitchen', 'Kitchen preparation workflow'],
  ['Delivery', 'delivery', 'Assigned delivery workflow'],
];
const permissionKeys = [
  'dashboard.view', 'branches.view', 'orders.view_all', 'orders.view_own', 'orders.create', 'orders.edit', 'orders.cancel', 'orders.status.update',
  'menu.view', 'menu.manage', 'deals.manage', 'customers.view', 'customers.manage', 'customers.history.view', 'payments.record', 'cash_shifts.view', 'cash_shifts.open', 'cash_shifts.manage', 'cash_shifts.close',
  'inventory.view', 'inventory.manage', 'inventory.adjust', 'expenses.view', 'expenses.create', 'expenses.approve', 'payments.view', 'payments.verify', 'payments.refund', 'payments.cod.collect',
  'ai.view', 'ai.conversations.view', 'ai.orders.approve', 'ai.settings.manage',
  'kitchen.orders.view', 'kitchen.orders.prepare', 'kitchen.orders.ready',
  'delivery.view_assigned', 'delivery.status.update', 'delivery.assign', 'delivery.assignments.view_all', 'staff.manage', 'roles.manage', 'reports.view', 'settings.manage', 'printers.manage', 'printers.view', 'printing.receipt', 'printing.kitchen', 'printing.view', 'printing.bridge', 'printing.retry',
];
module.exports = {
  async up(queryInterface) {
    const now = new Date();
    await queryInterface.bulkInsert('roles', roles.map(([name, slug, description]) => ({ name, slug, description, is_system: true, created_at: now, updated_at: now })), { ignoreDuplicates: true });
    await queryInterface.bulkInsert('permissions', permissionKeys.map((permission_key) => ({
      name: permission_key.split('.').map((part) => part.replace(/_/g, ' ')).join(' ').replace(/\b\w/g, (c) => c.toUpperCase()),
      permission_key, module: permission_key.split('.')[0], created_at: now, updated_at: now,
    })), { ignoreDuplicates: true });
    const [roleRows] = await queryInterface.sequelize.query('SELECT id, slug FROM roles');
    const [permissionRows] = await queryInterface.sequelize.query('SELECT id, permission_key FROM permissions');
    const roleIdBySlug = Object.fromEntries(roleRows.map((row) => [row.slug, row.id]));
    const permissionIdByKey = Object.fromEntries(permissionRows.map((row) => [row.permission_key, row.id]));
    const grants = {
      admin: permissionKeys,
      supervisor: ['staff.manage','delivery.assignments.view_all','delivery.assign','dashboard.view','branches.view','orders.view_all','orders.create','orders.edit','orders.cancel','orders.status.update','menu.view','customers.view','customers.manage','customers.history.view','inventory.view','inventory.adjust','payments.view','payments.record','payments.verify','cash_shifts.view','cash_shifts.open','cash_shifts.manage','cash_shifts.close','payments.cod.collect','expenses.view','expenses.create','expenses.approve','ai.view','ai.conversations.view','ai.orders.approve','kitchen.orders.view','delivery.view_assigned','delivery.status.update','reports.view','printers.manage','printers.view','printing.receipt','printing.kitchen','printing.view','printing.bridge','printing.retry'],
      waiter: ['delivery.assign','dashboard.view','branches.view','orders.view_own','orders.create','orders.edit','orders.status.update','menu.view','customers.view','customers.manage','customers.history.view','payments.record','printing.receipt','cash_shifts.view','cash_shifts.open','cash_shifts.manage','cash_shifts.close'],
      kitchen: ['dashboard.view','kitchen.orders.view','kitchen.orders.prepare','kitchen.orders.ready','printing.kitchen'],
      delivery: ['dashboard.view','delivery.view_assigned','delivery.status.update','payments.cod.collect'],
    };
    const rows = Object.entries(grants).flatMap(([slug, keys]) => keys.map((key) => ({ role_id: roleIdBySlug[slug], permission_id: permissionIdByKey[key], created_at: now, updated_at: now })));
    await queryInterface.bulkInsert('role_permissions', rows, { ignoreDuplicates: true });
  },
  async down(queryInterface) {
    await queryInterface.bulkDelete('role_permissions', null, {});
    await queryInterface.bulkDelete('permissions', null, {});
    await queryInterface.bulkDelete('roles', null, {});
  },
};
