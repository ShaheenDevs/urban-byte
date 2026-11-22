'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('restaurant_settings', {
      id: { type: Sequelize.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true, allowNull: false },
      restaurant_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false, unique: true },
      tax_enabled: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      tax_rate: { type: Sequelize.DECIMAL(7, 4), allowNull: false, defaultValue: 0 },
      tax_inclusive: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      service_charge_enabled: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false },
      service_charge_rate: { type: Sequelize.DECIMAL(7, 4), allowNull: false, defaultValue: 0 },
      discount_enabled: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: true },
      max_discount_percent: { type: Sequelize.DECIMAL(7, 4), allowNull: false, defaultValue: 20 },
      receipt_header: { type: Sequelize.STRING(250), allowNull: true },
      receipt_footer: { type: Sequelize.STRING(500), allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false },
    });
  },
  async down(queryInterface) {
    await queryInterface.dropTable('restaurant_settings');
  },
};
