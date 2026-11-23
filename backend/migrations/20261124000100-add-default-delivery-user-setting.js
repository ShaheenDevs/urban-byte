'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('restaurant_settings', 'default_delivery_user_id', {
      type: Sequelize.BIGINT.UNSIGNED,
      allowNull: true,
      after: 'restaurant_id',
    });
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('restaurant_settings', 'default_delivery_user_id');
  },
};
