'use strict';

module.exports = {
  async up(queryInterface) {
    const now = new Date();
    await queryInterface.sequelize.query(
      "INSERT IGNORE INTO role_permissions (role_id, permission_id, created_at, updated_at) " +
      "SELECT r.id, p.id, :now, :now FROM roles r " +
      "JOIN permissions p ON p.permission_key = 'staff.manage' " +
      "WHERE r.slug = 'supervisor'",
      { replacements: { now } }
    );
    await queryInterface.sequelize.query(
      "INSERT IGNORE INTO role_permissions (role_id, permission_id, created_at, updated_at) " +
      "SELECT r.id, p.id, :now, :now FROM roles r " +
      "JOIN permissions p ON p.permission_key = 'delivery.assign' " +
      "WHERE r.slug = 'waiter'",
      { replacements: { now } }
    );
  },

  async down(queryInterface) {
    await queryInterface.sequelize.query(
      "DELETE rp FROM role_permissions rp " +
      "JOIN roles r ON r.id = rp.role_id " +
      "JOIN permissions p ON p.id = rp.permission_id " +
      "WHERE (r.slug = 'supervisor' AND p.permission_key = 'staff.manage') " +
      "OR (r.slug = 'waiter' AND p.permission_key = 'delivery.assign')"
    );
  },
};
