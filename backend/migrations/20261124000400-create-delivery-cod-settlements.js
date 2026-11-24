'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('delivery_cash_settlements', {
      id: { type: Sequelize.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true, allowNull: false },
      restaurant_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false },
      branch_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false },
      rider_user_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false },
      submitted_by_user_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false },
      reviewed_by_user_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: true },
      settlement_date: { type: Sequelize.DATEONLY, allowNull: false },
      expected_amount: { type: Sequelize.DECIMAL(12, 2), allowNull: false },
      handed_amount: { type: Sequelize.DECIMAL(12, 2), allowNull: false },
      variance: { type: Sequelize.DECIMAL(12, 2), allowNull: false },
      status: { type: Sequelize.ENUM('pending_approval', 'approved', 'rejected'), allowNull: false, defaultValue: 'pending_approval' },
      rider_note: { type: Sequelize.STRING(500), allowNull: true },
      review_note: { type: Sequelize.STRING(500), allowNull: true },
      submitted_at: { type: Sequelize.DATE, allowNull: false },
      reviewed_at: { type: Sequelize.DATE, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });
    await queryInterface.addIndex('delivery_cash_settlements', ['restaurant_id', 'branch_id', 'settlement_date'], { name: 'delivery_cash_settlement_branch_date_idx' });
    await queryInterface.addIndex('delivery_cash_settlements', ['restaurant_id', 'rider_user_id', 'settlement_date'], { name: 'delivery_cash_settlement_rider_date_idx' });
    await queryInterface.addColumn('delivery_assignments', 'cod_settlement_id', {
      type: Sequelize.BIGINT.UNSIGNED, allowNull: true,
    });
    await queryInterface.addIndex('delivery_assignments', ['cod_settlement_id'], { name: 'delivery_assignment_cod_settlement_idx' });
    await queryInterface.addConstraint('delivery_assignments', { fields: ['cod_settlement_id'], type: 'foreign key', name: 'delivery_assignments_cod_settlement_fk', references: { table: 'delivery_cash_settlements', field: 'id' }, onUpdate: 'CASCADE', onDelete: 'SET NULL' });
  },
  async down(queryInterface) {
    await queryInterface.removeConstraint('delivery_assignments', 'delivery_assignments_cod_settlement_fk');
    await queryInterface.removeIndex('delivery_assignments', 'delivery_assignment_cod_settlement_idx');
    await queryInterface.removeColumn('delivery_assignments', 'cod_settlement_id');
    await queryInterface.dropTable('delivery_cash_settlements');
  },
};
