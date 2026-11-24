'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('orders', 'delivery_latitude', { type: Sequelize.DECIMAL(10, 7), allowNull: true });
    await queryInterface.addColumn('orders', 'delivery_longitude', { type: Sequelize.DECIMAL(10, 7), allowNull: true });
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('orders', 'delivery_longitude');
    await queryInterface.removeColumn('orders', 'delivery_latitude');
  },
};
