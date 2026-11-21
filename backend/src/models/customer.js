'use strict';
module.exports = (sequelize, DataTypes) => sequelize.define('Customer', {
  id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  restaurantId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'restaurant_id' },
  name: { type: DataTypes.STRING(150), allowNull: false },
  phone: { type: DataTypes.STRING(30), allowNull: false },
  email: { type: DataTypes.STRING(190), allowNull: true },
  notes: { type: DataTypes.TEXT, allowNull: true },
  isActive: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true, field: 'is_active' }
}, { tableName: 'customers', underscored: true });
