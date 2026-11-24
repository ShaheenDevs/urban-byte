'use strict';
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('delivery_assignments', 'tracking_token_hash', { type: Sequelize.STRING(64), allowNull: true });
    await queryInterface.addColumn('delivery_assignments', 'tracking_token_expires_at', { type: Sequelize.DATE, allowNull: true });
    await queryInterface.addIndex('delivery_assignments', ['tracking_token_hash'], { unique: true, name: 'delivery_tracking_token_hash_uq' });
  },
  async down(queryInterface) {
    await queryInterface.removeIndex('delivery_assignments', 'delivery_tracking_token_hash_uq');
    await queryInterface.removeColumn('delivery_assignments', 'tracking_token_expires_at');
    await queryInterface.removeColumn('delivery_assignments', 'tracking_token_hash');
  },
};
