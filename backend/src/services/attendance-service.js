'use strict';

const { Op } = require('sequelize');
const { AttendanceRecord, User, UserBranch, Role, Branch, AuditLog, sequelize } = require('../models');

function fail(message, status = 400, code = 'ATTENDANCE_ERROR') {
  const error = new Error(message); error.statusCode = status; error.code = code; return error;
}
async function assertBranchAccess(restaurantId, userId, branchId, transaction) {
  const branch = await Branch.findOne({ where: { id: branchId, restaurantId, isActive: true }, transaction });
  if (!branch) throw fail('Branch not found or inactive.', 404, 'BRANCH_NOT_FOUND');
  const account = await User.findByPk(userId, { include: [{ model: Role, as: 'roles', through: { attributes: [] } }], transaction });
  if ((account?.roles || []).some((role) => role.slug === 'admin')) return branch;
  const assignment = await UserBranch.findOne({ where: { userId, branchId }, transaction });
  if (!assignment) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
  return branch;
}
async function audit(transaction, restaurantId, userId, record, action, ipAddress) {
  await AuditLog.create({
    restaurantId, branchId: record.branchId, actorUserId: userId, entityType: 'attendance', entityId: String(record.id),
    action, metadata: { branchId: record.branchId, checkInAt: record.checkInAt, checkOutAt: record.checkOutAt }, ipAddress: ipAddress || null,
  }, { transaction });
}
async function checkIn(restaurantId, userId, input = {}, ipAddress) {
  const branchId = Number(input.branchId);
  if (!Number.isSafeInteger(branchId) || branchId < 1) throw fail('A valid branchId is required.');
  return sequelize.transaction(async (transaction) => {
    const user = await User.findOne({ where: { id: userId, restaurantId, isActive: true }, transaction, lock: transaction.LOCK.UPDATE });
    if (!user) throw fail('Active staff account not found.', 404, 'STAFF_NOT_FOUND');
    await assertBranchAccess(restaurantId, userId, branchId, transaction);
    const open = await AttendanceRecord.findOne({ where: { restaurantId, userId, checkOutAt: null }, transaction, lock: transaction.LOCK.UPDATE });
    if (open) throw fail('You already have an open attendance shift. Check out before starting another.', 409, 'ATTENDANCE_ALREADY_OPEN');
    const record = await AttendanceRecord.create({
      restaurantId, branchId, userId, checkInAt: new Date(),
      checkInNote: input.note ? String(input.note).trim().slice(0, 250) : null,
    }, { transaction });
    await audit(transaction, restaurantId, userId, record, 'attendance.checked_in', ipAddress);
    return record;
  });
}
async function checkOut(restaurantId, userId, input = {}, ipAddress) {
  return sequelize.transaction(async (transaction) => {
    const user = await User.findOne({ where: { id: userId, restaurantId, isActive: true }, transaction, lock: transaction.LOCK.UPDATE });
    if (!user) throw fail('Active staff account not found.', 404, 'STAFF_NOT_FOUND');
    const record = await AttendanceRecord.findOne({
      where: { restaurantId, userId, checkOutAt: null }, transaction, lock: transaction.LOCK.UPDATE,
    });
    if (!record) throw fail('No open attendance shift found.', 409, 'ATTENDANCE_NOT_OPEN');
    record.checkOutAt = new Date();
    record.checkOutNote = input.note ? String(input.note).trim().slice(0, 250) : null;
    await record.save({ transaction });
    await audit(transaction, restaurantId, userId, record, 'attendance.checked_out', ipAddress);
    return record;
  });
}
async function current(restaurantId, userId) {
  return AttendanceRecord.findOne({
    where: { restaurantId, userId, checkOutAt: null },
    include: [{ model: Branch, as: 'branch', attributes: ['id', 'name', 'code'] }],
    order: [['checkInAt', 'DESC']],
  });
}
async function list(restaurantId, query = {}, actor = {}) {
  const where = { restaurantId };
  const isAdmin = (actor.roles || []).includes('admin');
  const allowedBranches = (actor.branchIds || []).map(Number);
  if (query.branchId) {
    const branchId = Number(query.branchId);
    if (!Number.isSafeInteger(branchId) || branchId < 1) throw fail('Invalid branchId.');
    if (!isAdmin && !allowedBranches.includes(branchId)) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
    where.branchId = branchId;
  } else if (!isAdmin) {
    where.branchId = { [Op.in]: allowedBranches.length ? allowedBranches : [-1] };
  }
  if (query.userId) where.userId = Number(query.userId);
  if (query.from || query.to) {
    const from = query.from || query.to; const to = query.to || query.from;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || from > to) throw fail('Use valid YYYY-MM-DD from/to dates.');
    const start = new Date(from + 'T00:00:00+05:00');
    const end = new Date(new Date(to + 'T00:00:00+05:00').getTime() + 86400000);
    where.checkInAt = { [Op.gte]: start, [Op.lt]: end };
  }
  return AttendanceRecord.findAll({
    where, include: [
      { model: User, as: 'staff', attributes: ['id', 'name', 'email', 'phone'] },
      { model: Branch, as: 'branch', attributes: ['id', 'name', 'code'] },
    ], order: [['checkInAt', 'DESC']], limit: Math.min(Math.max(Number(query.limit) || 100, 1), 500),
  });
}
module.exports = { checkIn, checkOut, current, list };
