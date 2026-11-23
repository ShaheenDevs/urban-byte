'use strict';

module.exports = (sequelize, D) => {
  const M = sequelize.define('StockTransfer', {
    id: { type: D.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    restaurantId: { type: D.BIGINT.UNSIGNED, allowNull: false, field: 'restaurant_id' },
    reference: { type: D.STRING(50), allowNull: false },
    sourceBranchId: { type: D.BIGINT.UNSIGNED, allowNull: false, field: 'source_branch_id' },
    destinationBranchId: { type: D.BIGINT.UNSIGNED, allowNull: false, field: 'destination_branch_id' },
    status: { type: D.ENUM('requested', 'approved', 'rejected', 'in_transit', 'partially_received', 'received', 'cancelled'), allowNull: false, defaultValue: 'requested' },
    note: { type: D.STRING(500), allowNull: true },
    requestedByUserId: { type: D.BIGINT.UNSIGNED, allowNull: false, field: 'requested_by_user_id' },
    reviewedByUserId: { type: D.BIGINT.UNSIGNED, allowNull: true, field: 'reviewed_by_user_id' },
    reviewedAt: { type: D.DATE, allowNull: true, field: 'reviewed_at' },
    receivedAt: { type: D.DATE, allowNull: true, field: 'received_at' },
  }, { tableName: 'stock_transfers', underscored: true });
  M.associate = (models) => {
    M.belongsTo(models.Branch, { foreignKey: 'sourceBranchId', as: 'sourceBranch' });
    M.belongsTo(models.Branch, { foreignKey: 'destinationBranchId', as: 'destinationBranch' });
    M.belongsTo(models.User, { foreignKey: 'requestedByUserId', as: 'requester' });
    M.belongsTo(models.User, { foreignKey: 'reviewedByUserId', as: 'reviewer' });
    M.hasMany(models.StockTransferItem, { foreignKey: 'transferId', as: 'items' });
  };
  return M;
};
