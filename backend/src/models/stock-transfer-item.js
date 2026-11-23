'use strict';

module.exports = (sequelize, D) => {
  const M = sequelize.define('StockTransferItem', {
    id: { type: D.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
    transferId: { type: D.BIGINT.UNSIGNED, allowNull: false, field: 'transfer_id' },
    inventoryItemId: { type: D.BIGINT.UNSIGNED, allowNull: false, field: 'inventory_item_id' },
    requestedQuantity: { type: D.DECIMAL(14, 3), allowNull: false, field: 'requested_quantity' },
    receivedQuantity: { type: D.DECIMAL(14, 3), allowNull: false, defaultValue: 0, field: 'received_quantity' },
  }, { tableName: 'stock_transfer_items', underscored: true });
  M.associate = (models) => M.belongsTo(models.InventoryItem, { foreignKey: 'inventoryItemId', as: 'inventoryItem' });
  return M;
};
