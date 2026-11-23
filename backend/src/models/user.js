'use strict';
module.exports = (sequelize, DataTypes) => {
 const User = sequelize.define('User', {
  id:{type:DataTypes.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
  restaurantId:{type:DataTypes.BIGINT.UNSIGNED,allowNull:true,field:'restaurant_id'},
  name:{type:DataTypes.STRING(150),allowNull:false},email:{type:DataTypes.STRING(190),allowNull:true,unique:true,validate:{isEmail:true}},
  phone:{type:DataTypes.STRING(30),allowNull:true,unique:true},passwordHash:{type:DataTypes.STRING(255),allowNull:false,field:'password_hash'},
  isActive:{type:DataTypes.BOOLEAN,allowNull:false,defaultValue:true,field:'is_active'},lastLoginAt:{type:DataTypes.DATE,allowNull:true,field:'last_login_at'}
 },{tableName:'users',underscored:true});
 User.associate=(models)=>{
  User.belongsTo(models.Restaurant,{foreignKey:'restaurantId',as:'restaurant'});
  User.belongsToMany(models.Branch, { through: models.UserBranch, as: 'assignedBranches', foreignKey: 'userId', otherKey: 'branchId' });
  User.belongsToMany(models.Role,{through:models.UserRole,as:'roles',foreignKey:'userId',otherKey:'roleId'});
  User.belongsToMany(models.Permission,{through:models.UserPermission,as:'permissionOverrides',foreignKey:'userId',otherKey:'permissionId'});
  User.hasMany(models.RefreshToken,{foreignKey:'userId',as:'refreshTokens'});
  User.hasMany(models.Notification,{foreignKey:'userId',as:'notifications'});
 };
 return User;
};