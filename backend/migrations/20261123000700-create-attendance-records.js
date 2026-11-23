'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('attendance_records', {
      id: { type: Sequelize.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      restaurant_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'restaurants', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      branch_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'branches', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      user_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      check_in_at: { type: Sequelize.DATE, allowNull: false },
      check_out_at: { type: Sequelize.DATE, allowNull: true },
      check_in_note: { type: Sequelize.STRING(250), allowNull: true },
      check_out_note: { type: Sequelize.STRING(250), allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    await queryInterface.addIndex('attendance_records', ['restaurant_id', 'branch_id', 'check_in_at'], { name: 'idx_attendance_branch_date' });
    await queryInterface.addIndex('attendance_records', ['restaurant_id', 'user_id', 'check_in_at'], { name: 'idx_attendance_user_date' });
    await queryInterface.addIndex('attendance_records', ['user_id', 'check_out_at'], { name: 'idx_attendance_open_shift' });
  },
  async down(queryInterface) {
    await queryInterface.dropTable('attendance_records');
  },
};
