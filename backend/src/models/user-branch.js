'use strict';
module.exports = (sequelize, DataTypes) => sequelize.define('UserBranch', {
  id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  userId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'user_id' },
  branchId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'branch_id' },
  isPrimary: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false, field: 'is_primary' },
}, { tableName: 'user_branches', underscored: true });
