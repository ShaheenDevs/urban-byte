'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('restaurant_settings', 'delivery_base_fee', { type: Sequelize.DECIMAL(12, 2), allowNull: false, defaultValue: 0 });
    await queryInterface.addColumn('restaurant_settings', 'delivery_per_km_fee', { type: Sequelize.DECIMAL(12, 2), allowNull: false, defaultValue: 0 });
    await queryInterface.addColumn('restaurant_settings', 'delivery_free_radius_km', { type: Sequelize.DECIMAL(7, 2), allowNull: false, defaultValue: 0 });
    await queryInterface.addColumn('orders', 'delivery_distance_km', { type: Sequelize.DECIMAL(7, 2), allowNull: true });
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('orders', 'delivery_distance_km');
    await queryInterface.removeColumn('restaurant_settings', 'delivery_free_radius_km');
    await queryInterface.removeColumn('restaurant_settings', 'delivery_per_km_fee');
    await queryInterface.removeColumn('restaurant_settings', 'delivery_base_fee');
  },
};
