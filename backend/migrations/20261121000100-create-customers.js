'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('customers', {
      id: { type: Sequelize.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true, allowNull: false },
      restaurant_id: { type: Sequelize.BIGINT.UNSIGNED, allowNull: false },
      name: { type: Sequelize.STRING(150), allowNull: false },
      phone: { type: Sequelize.STRING(30), allowNull: false },
      email: { type: Sequelize.STRING(190), allowNull: true },
      notes: { type: Sequelize.TEXT, allowNull: true },
      is_active: { type: Sequelize.BOOLEAN, allowNull: false, defaultValue: true },
      created_at: { type: Sequelize.DATE, allowNull: false },
      updated_at: { type: Sequelize.DATE, allowNull: false }
    });
    await queryInterface.addIndex('customers', ['restaurant_id', 'phone'], { unique: true, name: 'customers_restaurant_phone_uq' });
    await queryInterface.addIndex('customers', ['restaurant_id', 'name'], { name: 'customers_restaurant_name_idx' });
  },
  async down(queryInterface) {
    await queryInterface.dropTable('customers');
  }
};
