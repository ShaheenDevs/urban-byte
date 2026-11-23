'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('restaurant_settings', 'kitchen_print_groups', {
      type: Sequelize.JSON, allowNull: true,
    });
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('restaurant_settings', 'kitchen_print_groups');
  },
};
