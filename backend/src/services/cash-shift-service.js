'use strict';

const { Op } = require('sequelize');
const { CashShift, CashShiftEntry, Payment, Expense, Branch, AuditLog, sequelize } = require('../models');

function fail(message, status = 400, code = 'CASH_SHIFT_ERROR') {
  return Object.assign(new Error(message), { statusCode: status, code });
}
function assertBranch(user, branchId) {
  if ((user.roles || []).includes('admin')) return;
  if (!(user.branchIds || []).map(Number).includes(Number(branchId))) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
}
function amount(value, allowZero = true) {
  const n = Number(value);
  if (!Number.isFinite(n) || (allowZero ? n < 0 : n <= 0) || n > 9999999999.99) throw fail('Amount must be a valid ' + (allowZero ? 'non-negative' : 'positive') + ' value.');
  return n.toFixed(2);
}
function dateRange(query = {}) {
  const from = query.from || new Date().toISOString().slice(0, 10);
  const to = query.to || from;
  const valid = (v) => /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0, 10) === v;
  if (!valid(from) || !valid(to) || from > to) throw fail('Use valid from/to dates in YYYY-MM-DD format.');
  return { from: new Date(from + 'T00:00:00+05:00'), to: new Date(new Date(to + 'T00:00:00+05:00').getTime() + 86400000) };
}
async function audit(transaction, restaurantId, userId, shift, action, metadata = {}) {
  await AuditLog.create({
    restaurantId, actorUserId: userId, entityType: 'cash_shift', entityId: String(shift.id),
    action, metadata: { branchId: shift.branchId, status: shift.status, reconciliationStatus: shift.reconciliationStatus, ...metadata },
  }, { transaction });
}
async function open(restaurantId, user, input = {}) {
  const branchId = Number(input.branchId);
  if (!Number.isSafeInteger(branchId) || branchId < 1) throw fail('A valid branchId is required.');
  assertBranch(user, branchId);
  const openingCash = amount(input.openingCash);
  return sequelize.transaction(async (transaction) => {
    const branch = await Branch.findOne({ where: { id: branchId, restaurantId, isActive: true }, transaction, lock: transaction.LOCK.UPDATE });
    if (!branch) throw fail('Branch not found.', 404, 'BRANCH_NOT_FOUND');
    const existing = await CashShift.findOne({ where: { restaurantId, branchId, status: 'open' }, transaction, lock: transaction.LOCK.UPDATE });
    if (existing) throw fail('This branch already has an open cash shift.', 409, 'SHIFT_ALREADY_OPEN');
    const shift = await CashShift.create({ restaurantId, branchId, openedByUserId: user.id, openingCash, status: 'open', openedAt: new Date(), reconciliationStatus: 'not_submitted' }, { transaction });
    await audit(transaction, restaurantId, user.id, shift, 'cash_shift.opened', { openingCash });
    return shift;
  });
}
async function addEntry(restaurantId, user, shiftId, input = {}) {
  const value = amount(input.amount, false);
  const type = input.entryType;
  if (!['cash_in', 'cash_out', 'expense'].includes(type)) throw fail('Unsupported cash entry type.');
  return sequelize.transaction(async (transaction) => {
    const shift = await CashShift.findOne({ where: { id: Number(shiftId), restaurantId, status: 'open' }, transaction, lock: transaction.LOCK.UPDATE });
    if (!shift) throw fail('Open cash shift not found.', 404, 'SHIFT_NOT_FOUND');
    assertBranch(user, shift.branchId);
    const entry = await CashShiftEntry.create({
      shiftId: shift.id, entryType: type, amount: value,
      description: String(input.description || '').trim().slice(0, 250) || 'Cash movement',
      reference: input.reference ? String(input.reference).trim().slice(0, 100) : null,
      recordedByUserId: user.id,
    }, { transaction });
    await audit(transaction, restaurantId, user.id, shift, 'cash_shift.entry_recorded', { entryId: entry.id, entryType: type, amount: value });
    return entry;
  });
}
async function totals(shift, transaction) {
  const cashPayments = await Payment.sum('amount', {
    where: { restaurantId: shift.restaurantId, branchId: shift.branchId, method: 'cash', status: 'verified', verifiedAt: { [Op.gte]: shift.openedAt, [Op.lte]: shift.closedAt || new Date() } }, transaction,
  }) || 0;
  const entries = await CashShiftEntry.findAll({ where: { shiftId: shift.id }, transaction });
  let cashIn = 0, cashOut = 0, expenses = 0;
  for (const entry of entries) {
    const n = Number(entry.amount);
    if (entry.entryType === 'cash_in') cashIn += n;
    else if (entry.entryType === 'cash_out') cashOut += n;
    else expenses += n;
  }
  const expected = Number(shift.openingCash) + Number(cashPayments) + cashIn - cashOut - expenses;
  return {
    openingCash: Number(shift.openingCash), verifiedCashPayments: Number(Number(cashPayments).toFixed(2)),
    cashIn: Number(cashIn.toFixed(2)), cashOut: Number(cashOut.toFixed(2)),
    expenses: Number(expenses.toFixed(2)), expectedCash: Number(expected.toFixed(2)),
  };
}
async function close(restaurantId, user, shiftId, input = {}) {
  const actual = amount(input.actualCash);
  return sequelize.transaction(async (transaction) => {
    const shift = await CashShift.findOne({ where: { id: Number(shiftId), restaurantId, status: 'open' }, transaction, lock: transaction.LOCK.UPDATE });
    if (!shift) throw fail('Open cash shift not found.', 404, 'SHIFT_NOT_FOUND');
    assertBranch(user, shift.branchId);
    shift.closedAt = new Date();
    const summary = await totals(shift, transaction);
    shift.expectedCash = summary.expectedCash.toFixed(2);
    shift.actualCash = actual;
    shift.cashVariance = (Number(actual) - summary.expectedCash).toFixed(2);
    shift.closedByUserId = user.id;
    shift.status = 'closed';
    shift.reconciliationStatus = 'pending_approval';
    shift.closingNotes = input.notes ? String(input.notes).trim().slice(0, 500) : null;
    await shift.save({ transaction });
    await audit(transaction, restaurantId, user.id, shift, 'cash_shift.closed_pending_reconciliation', {
      expectedCash: shift.expectedCash, actualCash: shift.actualCash, cashVariance: shift.cashVariance,
    });
    return { shift, summary, actualCash: Number(actual), cashVariance: Number(shift.cashVariance) };
  });
}
async function reviewReconciliation(restaurantId, user, shiftId, approve, input = {}) {
  return sequelize.transaction(async (transaction) => {
    const shift = await CashShift.findOne({ where: { id: Number(shiftId), restaurantId, status: 'closed' }, transaction, lock: transaction.LOCK.UPDATE });
    if (!shift) throw fail('Closed cash shift not found.', 404, 'SHIFT_NOT_FOUND');
    assertBranch(user, shift.branchId);
    if (!['admin', 'supervisor'].some((role) => (user.roles || []).includes(role))) throw fail('Only an admin or supervisor can review reconciliation.', 403, 'REVIEW_FORBIDDEN');
    if (Number(shift.closedByUserId) === Number(user.id) || Number(shift.openedByUserId) === Number(user.id)) {
      throw fail('The employee who opened or closed this shift cannot approve its reconciliation.', 403, 'SELF_APPROVAL_FORBIDDEN');
    }
    if (shift.reconciliationStatus !== 'pending_approval') throw fail('Only pending reconciliations can be reviewed.', 409, 'RECONCILIATION_ALREADY_REVIEWED');
    if (!approve && !String(input.note || '').trim()) throw fail('A rejection reason is required.');
    shift.reconciliationStatus = approve ? 'approved' : 'rejected';
    shift.reconciliationReviewedByUserId = user.id;
    shift.reconciliationReviewedAt = new Date();
    shift.reconciliationNote = String(input.note || '').trim().slice(0, 500) || null;
    await shift.save({ transaction });
    await audit(transaction, restaurantId, user.id, shift, approve ? 'cash_shift.reconciliation_approved' : 'cash_shift.reconciliation_rejected', {
      cashVariance: shift.cashVariance, note: shift.reconciliationNote,
    });
    return shift;
  });
}
async function current(restaurantId, user, query = {}) {
  const where = { restaurantId, status: 'open' };
  if ((user.roles || []).includes('admin')) {
    if (query.branchId) { const id = Number(query.branchId); if (!Number.isSafeInteger(id) || id < 1) throw fail('Invalid branchId.'); where.branchId = id; }
  } else {
    const allowed = (user.branchIds || []).map(Number);
    if (query.branchId && !allowed.includes(Number(query.branchId))) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
    where.branchId = query.branchId ? Number(query.branchId) : { [Op.in]: allowed.length ? allowed : [-1] };
  }
  return CashShift.findAll({ where, order: [['openedAt', 'DESC']], limit: 100 });
}
async function history(restaurantId, user, query = {}) {
  const { from, to } = dateRange(query);
  const where = { restaurantId, status: 'closed', closedAt: { [Op.gte]: from, [Op.lt]: to } };
  if ((user.roles || []).includes('admin')) {
    if (query.branchId) { const id = Number(query.branchId); if (!Number.isSafeInteger(id) || id < 1) throw fail('Invalid branchId.'); where.branchId = id; }
  } else {
    const allowed = (user.branchIds || []).map(Number);
    if (query.branchId && !allowed.includes(Number(query.branchId))) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
    where.branchId = query.branchId ? Number(query.branchId) : { [Op.in]: allowed.length ? allowed : [-1] };
  }
  if (query.reconciliationStatus) where.reconciliationStatus = query.reconciliationStatus;
  return CashShift.findAll({ where, order: [['closedAt', 'DESC']], limit: Math.min(Math.max(Number(query.limit) || 100, 1), 500) });
}
async function report(restaurantId, user, shiftId) {
  const shift = await CashShift.findOne({ where: { id: Number(shiftId), restaurantId } });
  if (!shift) throw fail('Cash shift not found.', 404);
  assertBranch(user, shift.branchId);
  const summary = await totals(shift);
  const entries = await CashShiftEntry.findAll({ where: { shiftId: shift.id }, order: [['createdAt', 'ASC']] });
  return { shift, summary, entries };
}
async function consolidated(restaurantId, user, query = {}) {
  if (!(user.roles || []).includes('admin')) throw fail('Only restaurant administrators can view consolidated cash reports.', 403, 'OWNER_ACCESS_REQUIRED');
  const { from, to } = dateRange(query);
  const branches = await Branch.findAll({ where: { restaurantId, isActive: true }, attributes: ['id', 'name', 'code'], order: [['name', 'ASC']], raw: true });
  const rows = await Promise.all(branches.map(async (branch) => {
    const shifts = await CashShift.findAll({ where: { restaurantId, branchId: branch.id, status: 'closed', closedAt: { [Op.gte]: from, [Op.lt]: to } }, raw: true });
    const sum = (key) => shifts.reduce((total, shift) => total + Number(shift[key] || 0), 0);
    return {
      branchId: branch.id, branchName: branch.name, branchCode: branch.code, shiftCount: shifts.length,
      expectedCash: Number(sum('expectedCash').toFixed(2)), actualCash: Number(sum('actualCash').toFixed(2)),
      cashVariance: Number(sum('cashVariance').toFixed(2)),
      pendingApprovals: shifts.filter((s) => s.reconciliationStatus === 'pending_approval').length,
      approved: shifts.filter((s) => s.reconciliationStatus === 'approved').length,
      rejected: shifts.filter((s) => s.reconciliationStatus === 'rejected').length,
    };
  }));
  const total = (key) => rows.reduce((n, row) => n + row[key], 0);
  return {
    period: { from: query.from || new Date().toISOString().slice(0, 10), to: query.to || query.from || new Date().toISOString().slice(0, 10) },
    currency: 'PKR', branchCount: rows.length,
    totals: {
      shiftCount: rows.reduce((n, row) => n + row.shiftCount, 0),
      expectedCash: Number(total('expectedCash').toFixed(2)), actualCash: Number(total('actualCash').toFixed(2)),
      cashVariance: Number(total('cashVariance').toFixed(2)),
      pendingApprovals: total('pendingApprovals'), approved: total('approved'), rejected: total('rejected'),
    }, branches: rows,
  };
}
module.exports = { open, addEntry, close, current, history, report, reviewReconciliation, consolidated };
