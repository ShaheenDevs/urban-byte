'use strict';
module.exports = (sequelize, DataTypes) => {
  const Permission = sequelize.define('Permission', {
    id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    name: { type: DataTypes.STRING(120), allowNull: false },
    permissionKey: { type: DataTypes.STRING(150), allowNull: false, unique: true, field: 'permission_key' },
    module: { type: DataTypes.STRING(80), allowNull: false },
  }, { tableName: 'permissions', underscored: true });
  Permission.associate = (models) => {
    Permission.belongsToMany(models.Role, { through: models.RolePermission, as: 'roles', foreignKey: 'permissionId', otherKey: 'roleId' });
    Permission.belongsToMany(models.User, { through: models.UserPermission, as: 'users', foreignKey: 'permissionId', otherKey: 'userId' });
  };
  return Permission;
};
