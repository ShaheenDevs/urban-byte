'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('employee_shifts', {
      id: { type: Sequelize.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      restaurant_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'restaurants', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      branch_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'branches', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      user_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      shift_date: { type: Sequelize.DATEONLY, allowNull: false },
      start_time: { type: Sequelize.TIME, allowNull: false },
      end_time: { type: Sequelize.TIME, allowNull: false },
      status: { type: Sequelize.ENUM('scheduled', 'cancelled'), allowNull: false, defaultValue: 'scheduled' },
      notes: { type: Sequelize.STRING(500), allowNull: true },
      created_by: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    await queryInterface.addIndex('employee_shifts', ['restaurant_id', 'branch_id', 'shift_date'], { name: 'idx_employee_shifts_branch_date' });
    await queryInterface.addIndex('employee_shifts', ['restaurant_id', 'user_id', 'shift_date'], { name: 'idx_employee_shifts_user_date' });
  },
  async down(queryInterface) {
    await queryInterface.dropTable('employee_shifts');
  },
};
