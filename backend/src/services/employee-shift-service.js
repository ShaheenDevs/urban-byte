'use strict';

const { Op } = require('sequelize');
const { EmployeeShift, User, UserBranch, Branch, AuditLog, sequelize } = require('../models');

function fail(message, status = 400, code = 'SHIFT_ERROR') {
  return Object.assign(new Error(message), { statusCode: status, code });
}
function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(value + 'T00:00:00Z');
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}
function validTime(value) { return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value); }
async function branchAccess(restaurantId, actor, branchId, transaction) {
  const branch = await Branch.findOne({ where: { id: branchId, restaurantId, isActive: true }, transaction });
  if (!branch) throw fail('Branch not found or inactive.', 404, 'BRANCH_NOT_FOUND');
  if (!(actor.roles || []).includes('admin') && !(actor.branchIds || []).map(Number).includes(Number(branchId))) {
    throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
  }
  return branch;
}
async function audit(transaction, restaurantId, actorId, shift, action, ipAddress) {
  await AuditLog.create({
    restaurantId, branchId: shift.branchId, actorUserId: actorId, entityType: 'employee_shift', entityId: String(shift.id),
    action, metadata: { branchId: shift.branchId, userId: shift.userId, shiftDate: shift.shiftDate, startTime: shift.startTime, endTime: shift.endTime, status: shift.status },
    ipAddress: ipAddress || null,
  }, { transaction });
}
async function create(restaurantId, actor, input = {}, ipAddress) {
  const branchId = Number(input.branchId), userId = Number(input.userId);
  if (!Number.isSafeInteger(branchId) || branchId < 1 || !Number.isSafeInteger(userId) || userId < 1) throw fail('Valid branchId and userId are required.');
  if (!validDate(input.shiftDate) || !validTime(input.startTime) || !validTime(input.endTime) || input.startTime >= input.endTime) {
    throw fail('Provide shiftDate (YYYY-MM-DD), startTime and endTime (HH:mm); endTime must be later than startTime.');
  }
  return sequelize.transaction(async (transaction) => {
    await branchAccess(restaurantId, actor, branchId, transaction);
    const staff = await User.findOne({ where: { id: userId, restaurantId, isActive: true }, transaction });
    if (!staff) throw fail('Active employee not found in this restaurant.', 404, 'STAFF_NOT_FOUND');
    const assignment = await UserBranch.findOne({ where: { userId, branchId }, transaction });
    if (!assignment && !(actor.roles || []).includes('admin')) throw fail('Employee is not assigned to the selected branch.', 409, 'EMPLOYEE_BRANCH_MISMATCH');
    const overlap = await EmployeeShift.findOne({
      where: { restaurantId, branchId, userId, shiftDate: input.shiftDate, status: 'scheduled',
        startTime: { [Op.lt]: input.endTime }, endTime: { [Op.gt]: input.startTime } }, transaction, lock: transaction.LOCK.UPDATE,
    });
    if (overlap) throw fail('This employee already has an overlapping shift.', 409, 'SHIFT_OVERLAP');
    const shift = await EmployeeShift.create({
      restaurantId, branchId, userId, shiftDate: input.shiftDate, startTime: input.startTime,
      endTime: input.endTime, notes: input.notes ? String(input.notes).trim().slice(0, 500) : null,
      createdBy: actor.id,
    }, { transaction });
    await audit(transaction, restaurantId, actor.id, shift, 'employee_shift.created', ipAddress);
    return shift;
  });
}
async function list(restaurantId, actor, query = {}) {
  const where = { restaurantId };
  const isAdmin = (actor.roles || []).includes('admin');
  const allowed = (actor.branchIds || []).map(Number);
  if (query.branchId) {
    const id = Number(query.branchId);
    if (!Number.isSafeInteger(id) || id < 1) throw fail('Invalid branchId.');
    if (!isAdmin && !allowed.includes(id)) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
    where.branchId = id;
  } else if (!isAdmin) where.branchId = { [Op.in]: allowed.length ? allowed : [-1] };
  if (query.userId) where.userId = Number(query.userId);
  if (query.from || query.to) {
    const from = query.from || query.to, to = query.to || query.from;
    if (!validDate(from) || !validDate(to) || from > to) throw fail('Use valid from/to dates in YYYY-MM-DD format.');
    where.shiftDate = { [Op.between]: [from, to] };
  }
  if (query.status) {
    if (!['scheduled', 'cancelled'].includes(query.status)) throw fail('Invalid shift status.');
    where.status = query.status;
  }
  return EmployeeShift.findAll({
    where, include: [
      { model: User, as: 'staff', attributes: ['id', 'name', 'email', 'phone'] },
      { model: Branch, as: 'branch', attributes: ['id', 'name', 'code'] },
    ], order: [['shiftDate', 'ASC'], ['startTime', 'ASC']],
    limit: Math.min(Math.max(Number(query.limit) || 100, 1), 500),
  });
}
async function cancel(restaurantId, actor, shiftId, ipAddress) {
  return sequelize.transaction(async (transaction) => {
    const shift = await EmployeeShift.findOne({ where: { id: shiftId, restaurantId }, transaction, lock: transaction.LOCK.UPDATE });
    if (!shift) throw fail('Shift not found.', 404, 'SHIFT_NOT_FOUND');
    await branchAccess(restaurantId, actor, shift.branchId, transaction);
    if (shift.status === 'cancelled') return shift;
    shift.status = 'cancelled';
    await shift.save({ transaction });
    await audit(transaction, restaurantId, actor.id, shift, 'employee_shift.cancelled', ipAddress);
    return shift;
  });
}
module.exports = { create, list, cancel };
