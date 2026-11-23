'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('audit_logs', 'branch_id', {
      type: Sequelize.BIGINT.UNSIGNED, allowNull: true,
      references: { model: 'branches', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'SET NULL',
    });
    await queryInterface.addColumn('audit_logs', 'before_data', { type: Sequelize.JSON, allowNull: true });
    await queryInterface.addColumn('audit_logs', 'after_data', { type: Sequelize.JSON, allowNull: true });
    await queryInterface.addIndex('audit_logs', ['restaurant_id', 'branch_id', 'created_at'], { name: 'idx_audit_branch_timeline' });
    const now = new Date();
    const keys = ['audit.view', 'inventory.analytics.view'];
    await queryInterface.bulkInsert('permissions', keys.map((permission_key) => ({
      name: permission_key.split('.').map((part) => part.replace(/_/g, ' ')).join(' ').replace(/\b\w/g, (c) => c.toUpperCase()),
      permission_key, module: permission_key.split('.')[0], created_at: now, updated_at: now,
    })), { ignoreDuplicates: true });
    const [roles] = await queryInterface.sequelize.query("SELECT id FROM roles WHERE slug IN ('admin','supervisor')");
    const [permissions] = await queryInterface.sequelize.query("SELECT id FROM permissions WHERE permission_key IN ('audit.view','inventory.analytics.view')");
    const grants = roles.flatMap((role) => permissions.map((permission) => ({
      role_id: role.id, permission_id: permission.id, created_at: now, updated_at: now,
    })));
    if (grants.length) await queryInterface.bulkInsert('role_permissions', grants, { ignoreDuplicates: true });
  },
  async down(queryInterface) {
    const [permissions] = await queryInterface.sequelize.query("SELECT id FROM permissions WHERE permission_key IN ('audit.view','inventory.analytics.view')");
    if (permissions.length) await queryInterface.bulkDelete('role_permissions', { permission_id: permissions.map((row) => row.id) });
    await queryInterface.bulkDelete('permissions', { permission_key: ['audit.view', 'inventory.analytics.view'] });
    await queryInterface.removeIndex('audit_logs', 'idx_audit_branch_timeline');
    await queryInterface.removeColumn('audit_logs', 'after_data');
    await queryInterface.removeColumn('audit_logs', 'before_data');
    await queryInterface.removeColumn('audit_logs', 'branch_id');
  },
};
