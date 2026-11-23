'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('cash_shifts', 'reconciliation_status', {
      type: Sequelize.ENUM('not_submitted', 'pending_approval', 'approved', 'rejected'),
      allowNull: false, defaultValue: 'not_submitted',
    });
    await queryInterface.addColumn('cash_shifts', 'reconciliation_reviewed_by_user_id', {
      type: Sequelize.BIGINT.UNSIGNED, allowNull: true,
      references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'SET NULL',
    });
    await queryInterface.addColumn('cash_shifts', 'reconciliation_reviewed_at', { type: Sequelize.DATE, allowNull: true });
    await queryInterface.addColumn('cash_shifts', 'reconciliation_note', { type: Sequelize.STRING(500), allowNull: true });
    await queryInterface.addColumn('expenses', 'audit_reference', { type: Sequelize.STRING(80), allowNull: true });
    const now = new Date();
    await queryInterface.bulkInsert('permissions', [{
      name: 'Cash Shifts Reconciliation Approve', permission_key: 'cash_shifts.reconcile.approve',
      module: 'cash_shifts', created_at: now, updated_at: now,
    }], { ignoreDuplicates: true });
    const [roles] = await queryInterface.sequelize.query("SELECT id FROM roles WHERE slug IN ('admin','supervisor')");
    const [permissions] = await queryInterface.sequelize.query("SELECT id FROM permissions WHERE permission_key = 'cash_shifts.reconcile.approve'");
    if (permissions[0]) {
      await queryInterface.bulkInsert('role_permissions', roles.map((role) => ({
        role_id: role.id, permission_id: permissions[0].id, created_at: now, updated_at: now,
      })), { ignoreDuplicates: true });
    }
  },
  async down(queryInterface) {
    const [permissions] = await queryInterface.sequelize.query("SELECT id FROM permissions WHERE permission_key = 'cash_shifts.reconcile.approve'");
    if (permissions.length) await queryInterface.bulkDelete('role_permissions', { permission_id: permissions.map((row) => row.id) });
    await queryInterface.bulkDelete('permissions', { permission_key: 'cash_shifts.reconcile.approve' });
    await queryInterface.removeColumn('expenses', 'audit_reference');
    await queryInterface.removeColumn('cash_shifts', 'reconciliation_note');
    await queryInterface.removeColumn('cash_shifts', 'reconciliation_reviewed_at');
    await queryInterface.removeColumn('cash_shifts', 'reconciliation_reviewed_by_user_id');
    await queryInterface.removeColumn('cash_shifts', 'reconciliation_status');
  },
};
