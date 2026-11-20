'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const { DataTypes } = Sequelize;
    await queryInterface.createTable('restaurants', {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      name: { type: DataTypes.STRING(150), allowNull: false },
      slug: { type: DataTypes.STRING(160), allowNull: false, unique: true },
      currency: { type: DataTypes.STRING(3), allowNull: false, defaultValue: 'PKR' },
      timezone: { type: DataTypes.STRING(64), allowNull: false, defaultValue: 'Asia/Karachi' },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    await queryInterface.createTable('branches', {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      restaurant_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, references: { model: 'restaurants', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      name: { type: DataTypes.STRING(150), allowNull: false }, code: { type: DataTypes.STRING(40), allowNull: false },
      address: { type: DataTypes.TEXT, allowNull: true }, phone: { type: DataTypes.STRING(30), allowNull: true },
      is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    await queryInterface.addConstraint('branches', { fields: ['restaurant_id', 'code'], type: 'unique', name: 'uq_branches_restaurant_code' });
    await queryInterface.createTable('users', {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      name: { type: DataTypes.STRING(150), allowNull: false }, email: { type: DataTypes.STRING(190), allowNull: true, unique: true },
      phone: { type: DataTypes.STRING(30), allowNull: true, unique: true }, password_hash: { type: DataTypes.STRING(255), allowNull: false },
      is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true }, last_login_at: { type: DataTypes.DATE, allowNull: true },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    await queryInterface.createTable('roles', {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true }, name: { type: DataTypes.STRING(80), allowNull: false },
      slug: { type: DataTypes.STRING(80), allowNull: false, unique: true }, description: { type: DataTypes.STRING(255), allowNull: true },
      is_system: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    await queryInterface.createTable('permissions', {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true }, name: { type: DataTypes.STRING(120), allowNull: false },
      permission_key: { type: DataTypes.STRING(150), allowNull: false, unique: true }, module: { type: DataTypes.STRING(80), allowNull: false },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
    });
    for (const [table, left, right, target] of [
      ['user_roles', 'user_id', 'role_id', 'roles'], ['role_permissions', 'role_id', 'permission_id', 'permissions'],
      ['user_permissions', 'user_id', 'permission_id', 'permissions'],
    ]) {
      const parent = left === 'user_id' ? 'users' : 'roles';
      await queryInterface.createTable(table, {
        id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
        [left]: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, references: { model: parent, key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
        [right]: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, references: { model: target, key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
        ...(table === 'user_permissions' ? { effect: { type: DataTypes.ENUM('allow', 'deny'), allowNull: false } } : {}),
        created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
        updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: Sequelize.literal('CURRENT_TIMESTAMP') },
      });
      await queryInterface.addConstraint(table, { fields: [left, right], type: 'unique', name: `uq_${table}_pair` });
    }
  },
  async down(queryInterface) {
    for (const table of ['user_permissions', 'role_permissions', 'user_roles', 'permissions', 'roles', 'users', 'branches', 'restaurants']) await queryInterface.dropTable(table);
  },
};
