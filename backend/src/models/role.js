'use strict';
module.exports = (sequelize, DataTypes) => {
  const Role = sequelize.define('Role', {
    id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    name: { type: DataTypes.STRING(80), allowNull: false },
    slug: { type: DataTypes.STRING(80), allowNull: false, unique: true },
    description: { type: DataTypes.STRING(255), allowNull: true },
    isSystem: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true, field: 'is_system' },
  }, { tableName: 'roles', underscored: true, timestamps: true });
  Role.associate = (models) => {
    Role.belongsToMany(models.User, { through: models.UserRole, as: 'users', foreignKey: 'roleId', otherKey: 'userId' });
    Role.belongsToMany(models.Permission, { through: models.RolePermission, as: 'permissions', foreignKey: 'roleId', otherKey: 'permissionId' });
  };
  return Role;
};
