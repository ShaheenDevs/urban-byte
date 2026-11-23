'use strict';

module.exports = (sequelize, DataTypes) => {
  const EmployeeShift = sequelize.define('EmployeeShift', {
    id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    restaurantId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'restaurant_id' },
    branchId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'branch_id' },
    userId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'user_id' },
    shiftDate: { type: DataTypes.DATEONLY, allowNull: false, field: 'shift_date' },
    startTime: { type: DataTypes.TIME, allowNull: false, field: 'start_time' },
    endTime: { type: DataTypes.TIME, allowNull: false, field: 'end_time' },
    status: { type: DataTypes.ENUM('scheduled', 'cancelled'), allowNull: false, defaultValue: 'scheduled' },
    notes: { type: DataTypes.STRING(500), allowNull: true },
    createdBy: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'created_by' },
  }, { tableName: 'employee_shifts', underscored: true });
  EmployeeShift.associate = (models) => {
    EmployeeShift.belongsTo(models.User, { foreignKey: 'userId', as: 'staff' });
    EmployeeShift.belongsTo(models.Branch, { foreignKey: 'branchId', as: 'branch' });
    EmployeeShift.belongsTo(models.User, { foreignKey: 'createdBy', as: 'creator' });
  };
  return EmployeeShift;
};
