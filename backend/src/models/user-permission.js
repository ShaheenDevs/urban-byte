'use strict';
module.exports = (sequelize, DataTypes) => sequelize.define('UserPermission', {
  id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  userId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'user_id' },
  permissionId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'permission_id' },
  effect: { type: DataTypes.ENUM('allow', 'deny'), allowNull: false },
}, { tableName: 'user_permissions', underscored: true });
