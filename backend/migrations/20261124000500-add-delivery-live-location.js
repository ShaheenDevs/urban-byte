'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('delivery_assignments', 'rider_latitude', { type: Sequelize.DECIMAL(10, 7), allowNull: true });
    await queryInterface.addColumn('delivery_assignments', 'rider_longitude', { type: Sequelize.DECIMAL(10, 7), allowNull: true });
    await queryInterface.addColumn('delivery_assignments', 'rider_location_accuracy', { type: Sequelize.DECIMAL(8, 2), allowNull: true });
    await queryInterface.addColumn('delivery_assignments', 'rider_location_updated_at', { type: Sequelize.DATE, allowNull: true });
    await queryInterface.addIndex('delivery_assignments', ['restaurant_id', 'branch_id', 'status', 'rider_location_updated_at'], { name: 'delivery_assignment_live_location_idx' });
  },
  async down(queryInterface) {
    await queryInterface.removeIndex('delivery_assignments', 'delivery_assignment_live_location_idx');
    await queryInterface.removeColumn('delivery_assignments', 'rider_location_updated_at');
    await queryInterface.removeColumn('delivery_assignments', 'rider_location_accuracy');
    await queryInterface.removeColumn('delivery_assignments', 'rider_longitude');
    await queryInterface.removeColumn('delivery_assignments', 'rider_latitude');
  },
};
