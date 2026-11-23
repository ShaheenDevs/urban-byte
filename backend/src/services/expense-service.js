'use strict';

const { Op } = require('sequelize');
const { Expense, Branch, CashShift, CashShiftEntry, AuditLog, sequelize } = require('../models');
function fail(message, status = 400, code = 'EXPENSE_ERROR') { return Object.assign(new Error(message), { statusCode: status, code }); }
function assertBranch(user, branchId) {
  if ((user.roles || []).includes('admin')) return;
  if (!(user.branchIds || []).map(Number).includes(Number(branchId))) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
}
async function validBranch(restaurantId, branchId, transaction) {
  const branch = await Branch.findOne({ where: { id: branchId, restaurantId, isActive: true }, attributes: ['id'], transaction });
  if (!branch) throw fail('Branch not found.', 404, 'BRANCH_NOT_FOUND');
}
function validate(input) {
  const amount = Number(input.amount), branchId = Number(input.branchId);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 9999999999.99) throw fail('Amount must be greater than zero.');
  if (!Number.isSafeInteger(branchId) || branchId < 1) throw fail('Valid branchId required.');
  const category = String(input.category || '').trim().slice(0, 80);
  const description = String(input.description || '').trim().slice(0, 500);
  if (!category || !description) throw fail('Category and description are required.');
  const paymentMethod = input.paymentMethod;
  if (!['cash', 'card', 'bank_transfer', 'easypaisa', 'jazzcash'].includes(paymentMethod)) throw fail('Invalid payment method.');
  const expenseDate = input.expenseDate || new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(expenseDate) || Number.isNaN(Date.parse(expenseDate)) || new Date(expenseDate).toISOString().slice(0, 10) !== expenseDate) throw fail('Expense date must use a real YYYY-MM-DD date.');
  return { branchId, category, description, amount: amount.toFixed(2), paymentMethod, expenseDate, reference: input.reference ? String(input.reference).trim().slice(0, 120) : null };
}
function scopedWhere(restaurantId, user, query = {}, status) {
  const where = { restaurantId };
  if (status) where.status = status;
  const admin = (user.roles || []).includes('admin');
  const allowed = (user.branchIds || []).map(Number);
  if (query.branchId) {
    const branchId = Number(query.branchId);
    if (!Number.isSafeInteger(branchId) || branchId < 1) throw fail('Invalid branchId.');
    assertBranch(user, branchId);
    where.branchId = branchId;
  } else if (!admin) where.branchId = { [Op.in]: allowed.length ? allowed : [-1] };
  if (query.from || query.to) {
    const from = query.from || query.to, to = query.to || query.from;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || from > to) throw fail('Use valid from/to dates.');
    where.expenseDate = { [Op.between]: [from, to] };
  }
  return where;
}
async function audit(transaction, restaurantId, userId, expense, action, metadata = {}) {
  await AuditLog.create({
    restaurantId, branchId: expense.branchId, actorUserId: userId, entityType: 'expense', entityId: String(expense.id),
    action, metadata: { branchId: expense.branchId, amount: expense.amount, paymentMethod: expense.paymentMethod, status: expense.status, ...metadata }, afterData: { branchId: expense.branchId, amount: expense.amount, category: expense.category, paymentMethod: expense.paymentMethod, status: expense.status, approvedByUserId: expense.approvedByUserId, rejectionReason: expense.rejectionReason, ...metadata }, 
  }, { transaction });
}
async function list(restaurantId, user, query = {}) {
  const where = scopedWhere(restaurantId, user, query);
  if (query.status) {
    if (!['pending', 'approved', 'rejected'].includes(query.status)) throw fail('Invalid expense status.');
    where.status = query.status;
  }
  return Expense.findAll({ where, order: [['expenseDate', 'DESC'], ['createdAt', 'DESC']], limit: Math.min(Math.max(Number(query.limit) || 50, 1), 200) });
}
async function create(restaurantId, user, input) {
  const data = validate(input);
  assertBranch(user, data.branchId);
  await validBranch(restaurantId, data.branchId);
  return sequelize.transaction(async (transaction) => {
    const expense = await Expense.create({ ...data, restaurantId, createdByUserId: user.id, status: 'pending' }, { transaction });
    await audit(transaction, restaurantId, user.id, expense, 'expense.submitted');
    return expense;
  });
}
async function decide(restaurantId, user, id, approve, input = {}) {
  return sequelize.transaction(async (transaction) => {
    const expense = await Expense.findOne({ where: { id: Number(id), restaurantId }, transaction, lock: transaction.LOCK.UPDATE });
    if (!expense) throw fail('Expense not found.', 404, 'EXPENSE_NOT_FOUND');
    assertBranch(user, expense.branchId);
    if (expense.status !== 'pending') throw fail('Only pending expenses can be reviewed.', 409, 'EXPENSE_ALREADY_REVIEWED');
    if (approve) {
      if (expense.paymentMethod === 'cash') {
        const shift = await CashShift.findOne({ where: { restaurantId, branchId: expense.branchId, status: 'open' }, transaction, lock: transaction.LOCK.UPDATE });
        if (!shift) throw fail('Open cash shift required to approve a cash expense. Open the branch cash shift first.', 409, 'OPEN_CASH_SHIFT_REQUIRED');
        const entry = await CashShiftEntry.create({
          shiftId: shift.id, entryType: 'expense', amount: expense.amount,
          description: ('Expense: ' + expense.category + ' - ' + expense.description).slice(0, 250),
          reference: expense.reference || ('EXP-' + expense.id), recordedByUserId: user.id,
        }, { transaction });
        await AuditLog.create({
          restaurantId, branchId: shift.branchId, actorUserId: user.id, entityType: 'cash_shift', entityId: String(shift.id),
          action: 'cash_shift.expense_linked', metadata: { expenseId: expense.id, entryId: entry.id, amount: expense.amount },
        }, { transaction });
      }
      expense.status = 'approved';
      expense.approvedByUserId = user.id;
      expense.approvedAt = new Date();
      expense.rejectionReason = null;
    } else {
      const reason = String(input.reason || '').trim();
      if (!reason) throw fail('A rejection reason is required.');
      expense.status = 'rejected';
      expense.rejectionReason = reason.slice(0, 500);
      expense.approvedByUserId = user.id;
    }
    await expense.save({ transaction });
    await audit(transaction, restaurantId, user.id, expense, approve ? 'expense.approved' : 'expense.rejected', { rejectionReason: expense.rejectionReason });
    return expense;
  });
}
async function summary(restaurantId, user, query = {}) {
  const where = scopedWhere(restaurantId, user, query, 'approved');
  const rows = await Expense.findAll({
    where, attributes: ['paymentMethod', [sequelize.fn('SUM', sequelize.col('amount')), 'total']],
    group: ['paymentMethod'], raw: true,
  });
  return { byPaymentMethod: rows.map((row) => ({ paymentMethod: row.paymentMethod, total: Number(row.total) })), total: Number(rows.reduce((n, row) => n + Number(row.total), 0).toFixed(2)) };
}
module.exports = { list, create, approve: (r, u, id) => decide(r, u, id, true), reject: (r, u, id, body) => decide(r, u, id, false, body), summary };
