'use strict';
module.exports = (sequelize, DataTypes) => sequelize.define('AuditLog', {
  id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  restaurantId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'restaurant_id' },
  actorUserId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true, field: 'actor_user_id' },
  entityType: { type: DataTypes.STRING(80), allowNull: false, field: 'entity_type' },
  entityId: { type: DataTypes.STRING(80), allowNull: false, field: 'entity_id' },
  action: { type: DataTypes.STRING(100), allowNull: false },
  metadata: { type: DataTypes.JSON, allowNull: false, defaultValue: {} },
  ipAddress: { type: DataTypes.STRING(45), allowNull: true, field: 'ip_address' },
}, { tableName: 'audit_logs', underscored: true, updatedAt: false });
const define = module.exports;
module.exports = (sequelize, DataTypes) => {
  const AuditLog = define(sequelize, DataTypes);
  AuditLog.associate = (models) => AuditLog.belongsTo(models.User, { foreignKey: 'actorUserId', as: 'actor' });
  return AuditLog;
};
