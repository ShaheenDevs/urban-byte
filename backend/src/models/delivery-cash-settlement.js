'use strict';
module.exports = (sequelize, DataTypes) => {
  const Model = sequelize.define('DeliveryCashSettlement', {
    id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    restaurantId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'restaurant_id' },
    branchId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'branch_id' },
    riderUserId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'rider_user_id' },
    submittedByUserId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, field: 'submitted_by_user_id' },
    reviewedByUserId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true, field: 'reviewed_by_user_id' },
    settlementDate: { type: DataTypes.DATEONLY, allowNull: false, field: 'settlement_date' },
    expectedAmount: { type: DataTypes.DECIMAL(12, 2), allowNull: false, field: 'expected_amount' },
    handedAmount: { type: DataTypes.DECIMAL(12, 2), allowNull: false, field: 'handed_amount' },
    variance: { type: DataTypes.DECIMAL(12, 2), allowNull: false },
    status: { type: DataTypes.ENUM('pending_approval', 'approved', 'rejected'), allowNull: false, defaultValue: 'pending_approval' },
    riderNote: { type: DataTypes.STRING(500), allowNull: true, field: 'rider_note' },
    reviewNote: { type: DataTypes.STRING(500), allowNull: true, field: 'review_note' },
    submittedAt: { type: DataTypes.DATE, allowNull: false, field: 'submitted_at' },
    reviewedAt: { type: DataTypes.DATE, allowNull: true, field: 'reviewed_at' },
  }, { tableName: 'delivery_cash_settlements', underscored: true });
  Model.associate = (models) => {
    Model.belongsTo(models.Branch, { foreignKey: 'branchId', as: 'branch' });
    Model.belongsTo(models.User, { foreignKey: 'riderUserId', as: 'rider' });
    Model.belongsTo(models.User, { foreignKey: 'reviewedByUserId', as: 'reviewedBy' });
    Model.hasMany(models.DeliveryAssignment, { foreignKey: 'codSettlementId', as: 'assignments' });
  };
  return Model;
};
