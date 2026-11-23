'use strict';

module.exports = {
  async up(q, S) {
    const D = S.DataTypes;
    await q.createTable('stock_transfers', {
      id: { type: D.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      restaurant_id: { type: D.BIGINT.UNSIGNED, allowNull: false, references: { model: 'restaurants', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      reference: { type: D.STRING(50), allowNull: false },
      source_branch_id: { type: D.BIGINT.UNSIGNED, allowNull: false, references: { model: 'branches', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      destination_branch_id: { type: D.BIGINT.UNSIGNED, allowNull: false, references: { model: 'branches', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      status: { type: D.ENUM('requested', 'approved', 'rejected', 'in_transit', 'partially_received', 'received', 'cancelled'), allowNull: false, defaultValue: 'requested' },
      note: { type: D.STRING(500), allowNull: true },
      requested_by_user_id: { type: D.BIGINT.UNSIGNED, allowNull: false, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      reviewed_by_user_id: { type: D.BIGINT.UNSIGNED, allowNull: true, references: { model: 'users', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'SET NULL' },
      reviewed_at: { type: D.DATE, allowNull: true },
      received_at: { type: D.DATE, allowNull: true },
      created_at: { type: D.DATE, allowNull: false, defaultValue: S.literal('CURRENT_TIMESTAMP') },
      updated_at: { type: D.DATE, allowNull: false, defaultValue: S.literal('CURRENT_TIMESTAMP') },
    });
    await q.addConstraint('stock_transfers', { fields: ['restaurant_id', 'reference'], type: 'unique', name: 'uq_stock_transfer_reference' });
    await q.addIndex('stock_transfers', ['restaurant_id', 'source_branch_id', 'status'], { name: 'idx_stock_transfer_source_status' });
    await q.addIndex('stock_transfers', ['restaurant_id', 'destination_branch_id', 'status'], { name: 'idx_stock_transfer_destination_status' });
    await q.createTable('stock_transfer_items', {
      id: { type: D.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      transfer_id: { type: D.BIGINT.UNSIGNED, allowNull: false, references: { model: 'stock_transfers', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'CASCADE' },
      inventory_item_id: { type: D.BIGINT.UNSIGNED, allowNull: false, references: { model: 'inventory_items', key: 'id' }, onUpdate: 'CASCADE', onDelete: 'RESTRICT' },
      requested_quantity: { type: D.DECIMAL(14, 3), allowNull: false },
      received_quantity: { type: D.DECIMAL(14, 3), allowNull: false, defaultValue: 0 },
    });
    await q.addConstraint('stock_transfer_items', { fields: ['transfer_id', 'inventory_item_id'], type: 'unique', name: 'uq_stock_transfer_item' });
  },
  async down(q) {
    await q.dropTable('stock_transfer_items');
    await q.dropTable('stock_transfers');
  },
};
