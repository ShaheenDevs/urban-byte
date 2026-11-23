'use strict';

module.exports = (sequelize, DataTypes) => {
  const AttendanceRecord = sequelize.define('AttendanceRecord', {
    id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    restaurantId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'restaurant_id' },
    branchId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'branch_id' },
    userId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'user_id' },
    checkInAt: { type: DataTypes.DATE, allowNull: false, field: 'check_in_at' },
    checkOutAt: { type: DataTypes.DATE, allowNull: true, field: 'check_out_at' },
    checkInNote: { type: DataTypes.STRING(250), allowNull: true, field: 'check_in_note' },
    checkOutNote: { type: DataTypes.STRING(250), allowNull: true, field: 'check_out_note' },
  }, { tableName: 'attendance_records', underscored: true });
  AttendanceRecord.associate = (models) => {
    AttendanceRecord.belongsTo(models.User, { foreignKey: 'userId', as: 'staff' });
    AttendanceRecord.belongsTo(models.Branch, { foreignKey: 'branchId', as: 'branch' });
  };
  return AttendanceRecord;
};
