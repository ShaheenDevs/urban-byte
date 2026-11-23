'use strict';

const crypto = require('node:crypto');
const { Op } = require('sequelize');
const { StockTransfer, StockTransferItem, InventoryItem, BranchStock, StockMovement, Branch, AuditLog, sequelize } = require('../models');

function fail(message, status = 400, code = 'STOCK_TRANSFER_ERROR') {
  return Object.assign(new Error(message), { statusCode: status, code });
}
function positiveId(value, label) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 1) throw fail(label + ' must be a positive ID.');
  return number;
}
function positiveQuantity(value) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0 || number > 999999999 || Math.round(number * 1000) !== number * 1000) {
    throw fail('Transfer quantity must be positive with at most 3 decimal places.');
  }
  return number;
}
function assertBranch(actor, branchId) {
  if ((actor.roles || []).includes('admin')) return;
  if (!(actor.branchIds || []).map(Number).includes(Number(branchId))) {
    throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
  }
}
async function activeBranch(restaurantId, branchId, transaction) {
  const branch = await Branch.findOne({ where: { id: branchId, restaurantId, isActive: true }, transaction, lock: transaction.LOCK.UPDATE });
  if (!branch) throw fail('Branch not found or inactive.', 404, 'BRANCH_NOT_FOUND');
  return branch;
}
async function audit(transaction, restaurantId, actorId, transfer, action, extra = {}) {
  await AuditLog.create({
    restaurantId, branchId: transfer.sourceBranchId, actorUserId: actorId, entityType: 'stock_transfer', entityId: String(transfer.id),
    action, metadata: { reference: transfer.reference, sourceBranchId: transfer.sourceBranchId, destinationBranchId: transfer.destinationBranchId, status: transfer.status, ...extra }, afterData: { reference: transfer.reference, sourceBranchId: transfer.sourceBranchId, destinationBranchId: transfer.destinationBranchId, status: transfer.status, ...extra }, 
  }, { transaction });
}
const include = [
  { model: StockTransferItem, as: 'items', include: [{ model: InventoryItem, as: 'inventoryItem', attributes: ['id', 'name', 'baseUnit'] }] },
  { model: Branch, as: 'sourceBranch', attributes: ['id', 'name', 'code'] },
  { model: Branch, as: 'destinationBranch', attributes: ['id', 'name', 'code'] },
];
async function create(restaurantId, actor, input = {}) {
  const sourceBranchId = positiveId(input.sourceBranchId, 'sourceBranchId');
  const destinationBranchId = positiveId(input.destinationBranchId, 'destinationBranchId');
  if (sourceBranchId === destinationBranchId) throw fail('Source and destination branches must be different.');
  if (!Array.isArray(input.items) || !input.items.length || input.items.length > 100) throw fail('A transfer requires 1 to 100 item lines.');
  assertBranch(actor, sourceBranchId);
  const lines = new Map();
  for (const line of input.items) {
    const inventoryItemId = positiveId(line.inventoryItemId, 'inventoryItemId');
    if (lines.has(inventoryItemId)) throw fail('Duplicate inventory item in transfer request.');
    lines.set(inventoryItemId, positiveQuantity(line.quantity));
  }
  return sequelize.transaction(async (transaction) => {
    await activeBranch(restaurantId, sourceBranchId, transaction);
    await activeBranch(restaurantId, destinationBranchId, transaction);
    const items = await InventoryItem.findAll({ where: { restaurantId, isActive: true, id: { [Op.in]: [...lines.keys()] } }, transaction });
    if (items.length !== lines.size) throw fail('One or more inventory items do not belong to this restaurant.', 404, 'ITEM_NOT_FOUND');
    const transfer = await StockTransfer.create({
      restaurantId, reference: 'TRF-' + Date.now() + '-' + crypto.randomBytes(2).toString('hex').toUpperCase(),
      sourceBranchId, destinationBranchId, status: 'requested',
      note: input.note ? String(input.note).trim().slice(0, 500) : null, requestedByUserId: actor.id,
    }, { transaction });
    await StockTransferItem.bulkCreate([...lines].map(([inventoryItemId, requestedQuantity]) => ({ transferId: transfer.id, inventoryItemId, requestedQuantity, receivedQuantity: 0 })), { transaction });
    await audit(transaction, restaurantId, actor.id, transfer, 'stock_transfer.requested', { itemCount: lines.size });
    return StockTransfer.findByPk(transfer.id, { include, transaction });
  });
}
async function list(restaurantId, actor, filters = {}) {
  const where = { restaurantId };
  const admin = (actor.roles || []).includes('admin');
  const allowed = (actor.branchIds || []).map(Number);
  if (!admin) {
    where[Op.or] = [
      { sourceBranchId: { [Op.in]: allowed.length ? allowed : [-1] } },
      { destinationBranchId: { [Op.in]: allowed.length ? allowed : [-1] } },
    ];
  }
  if (filters.branchId) {
    const branchId = positiveId(filters.branchId, 'branchId');
    assertBranch(actor, branchId);
    where[Op.or] = [{ sourceBranchId: branchId }, { destinationBranchId: branchId }];
  }
  if (filters.status) {
    const statuses = ['requested', 'approved', 'rejected', 'in_transit', 'partially_received', 'received', 'cancelled'];
    if (!statuses.includes(filters.status)) throw fail('Invalid transfer status.');
    where.status = filters.status;
  }
  return StockTransfer.findAll({ where, include, order: [['createdAt', 'DESC']], limit: Math.min(Math.max(Number(filters.limit) || 100, 1), 500) });
}
async function review(restaurantId, actor, transferId, decision, input = {}) {
  const id = positiveId(transferId, 'transferId');
  if (!['approve', 'reject'].includes(decision)) throw fail('Invalid review decision.');
  return sequelize.transaction(async (transaction) => {
    const transfer = await StockTransfer.findOne({ where: { id, restaurantId }, include: [{ model: StockTransferItem, as: 'items' }], transaction, lock: transaction.LOCK.UPDATE });
    if (!transfer) throw fail('Stock transfer not found.', 404, 'TRANSFER_NOT_FOUND');
    assertBranch(actor, transfer.destinationBranchId);
    if (transfer.status !== 'requested') throw fail('Only requested transfers can be approved or rejected.', 409, 'TRANSFER_NOT_REVIEWABLE');
    if (decision === 'reject') {
      transfer.status = 'rejected';
      transfer.reviewedByUserId = actor.id;
      transfer.reviewedAt = new Date();
      if (input.note) transfer.note = (transfer.note ? transfer.note + ' | ' : '') + String(input.note).trim().slice(0, 300);
      await transfer.save({ transaction });
      await audit(transaction, restaurantId, actor.id, transfer, 'stock_transfer.rejected');
      return StockTransfer.findByPk(id, { include, transaction });
    }
    await activeBranch(restaurantId, transfer.sourceBranchId, transaction);
    for (const line of [...transfer.items].sort((a, b) => Number(a.inventoryItemId) - Number(b.inventoryItemId))) {
      const stock = await BranchStock.findOne({ where: { branchId: transfer.sourceBranchId, inventoryItemId: line.inventoryItemId }, transaction, lock: transaction.LOCK.UPDATE });
      const qty = Number(line.requestedQuantity);
      if (!stock || Number(stock.quantity) < qty) throw fail('Insufficient source stock for inventory item ' + line.inventoryItemId + '.', 409, 'INSUFFICIENT_STOCK');
      const after = Number((Number(stock.quantity) - qty).toFixed(3));
      await stock.update({ quantity: after }, { transaction });
      await StockMovement.create({ restaurantId, branchId: transfer.sourceBranchId, inventoryItemId: line.inventoryItemId, movementType: 'adjustment', quantityChange: -qty, quantityAfter: after, referenceType: 'stock_transfer', referenceId: transfer.id, note: 'Approved inter-branch transfer dispatch', createdByUserId: actor.id }, { transaction });
    }
    transfer.status = 'in_transit';
    transfer.reviewedByUserId = actor.id;
    transfer.reviewedAt = new Date();
    await transfer.save({ transaction });
    await audit(transaction, restaurantId, actor.id, transfer, 'stock_transfer.approved_and_dispatched');
    return StockTransfer.findByPk(id, { include, transaction });
  });
}
async function receive(restaurantId, actor, transferId, input = {}) {
  const id = positiveId(transferId, 'transferId');
  if (!Array.isArray(input.items) || !input.items.length || input.items.length > 100) throw fail('Provide one or more received item quantities.');
  const received = new Map();
  for (const line of input.items) {
    const itemId = positiveId(line.inventoryItemId, 'inventoryItemId');
    if (received.has(itemId)) throw fail('Duplicate received inventory item.');
    received.set(itemId, positiveQuantity(line.quantity));
  }
  return sequelize.transaction(async (transaction) => {
    const transfer = await StockTransfer.findOne({ where: { id, restaurantId }, include: [{ model: StockTransferItem, as: 'items' }], transaction, lock: transaction.LOCK.UPDATE });
    if (!transfer) throw fail('Stock transfer not found.', 404, 'TRANSFER_NOT_FOUND');
    assertBranch(actor, transfer.destinationBranchId);
    if (!['in_transit', 'partially_received'].includes(transfer.status)) throw fail('Only dispatched transfers can be received.', 409, 'TRANSFER_NOT_RECEIVABLE');
    for (const [inventoryItemId, qty] of received) {
      const line = transfer.items.find((item) => Number(item.inventoryItemId) === inventoryItemId);
      if (!line) throw fail('Received item is not part of this transfer.', 404, 'TRANSFER_ITEM_NOT_FOUND');
      const remaining = Number(line.requestedQuantity) - Number(line.receivedQuantity);
      if (qty > remaining + 0.0001) throw fail('Received quantity exceeds the remaining dispatched quantity.', 409, 'RECEIVE_EXCEEDS_REMAINING');
      let stock = await BranchStock.findOne({ where: { branchId: transfer.destinationBranchId, inventoryItemId }, transaction, lock: transaction.LOCK.UPDATE });
      if (!stock) stock = await BranchStock.create({ branchId: transfer.destinationBranchId, inventoryItemId, quantity: 0, reorderLevel: 0 }, { transaction });
      const after = Number((Number(stock.quantity) + qty).toFixed(3));
      await stock.update({ quantity: after }, { transaction });
      await line.update({ receivedQuantity: Number((Number(line.receivedQuantity) + qty).toFixed(3)) }, { transaction });
      await StockMovement.create({ restaurantId, branchId: transfer.destinationBranchId, inventoryItemId, movementType: 'adjustment', quantityChange: qty, quantityAfter: after, referenceType: 'stock_transfer', referenceId: transfer.id, note: 'Inter-branch transfer received', createdByUserId: actor.id }, { transaction });
    }
    const complete = transfer.items.every((line) => Number(line.receivedQuantity) >= Number(line.requestedQuantity) - 0.0001);
    const anyReceived = transfer.items.some((line) => Number(line.receivedQuantity) > 0);
    transfer.status = complete ? 'received' : (anyReceived ? 'partially_received' : 'in_transit');
    if (complete) transfer.receivedAt = new Date();
    await transfer.save({ transaction });
    await audit(transaction, restaurantId, actor.id, transfer, complete ? 'stock_transfer.received' : 'stock_transfer.partially_received', { receivedLines: received.size });
    return StockTransfer.findByPk(id, { include, transaction });
  });
}
module.exports = { create, list, review, receive };
