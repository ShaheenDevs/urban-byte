'use strict';

const { Op } = require('sequelize');
const { AuditLog, User } = require('../models');

function fail(message, status = 400, code = 'AUDIT_FILTER_ERROR') {
  return Object.assign(new Error(message), { statusCode: status, code });
}
function scope(user, query = {}) {
  const admin = (user.roles || []).includes('admin');
  const allowed = (user.branchIds || []).map(Number).filter((id) => Number.isSafeInteger(id) && id > 0);
  const where = {};
  if (query.branchId !== undefined && query.branchId !== '') {
    const branchId = Number(query.branchId);
    if (!Number.isSafeInteger(branchId) || branchId < 1) throw fail('Invalid branchId.');
    if (!admin && !allowed.includes(branchId)) throw fail('You are not assigned to this branch.', 403, 'BRANCH_FORBIDDEN');
    where.branchId = branchId;
  } else if (!admin) {
    where.branchId = { [Op.in]: allowed.length ? allowed : [-1] };
  }
  if (query.actorUserId) {
    const actorUserId = Number(query.actorUserId);
    if (!Number.isSafeInteger(actorUserId) || actorUserId < 1) throw fail('Invalid actorUserId.');
    where.actorUserId = actorUserId;
  }
  if (query.entityType) where.entityType = String(query.entityType).trim().slice(0, 80);
  if (query.entityId) where.entityId = String(query.entityId).trim().slice(0, 80);
  if (query.action) where.action = { [Op.like]: '%' + String(query.action).trim().slice(0, 80) + '%' };
  if (query.from || query.to) {
    const from = query.from || query.to, to = query.to || query.from;
    const valid = (v) => /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v + 'T00:00:00Z')) && new Date(v + 'T00:00:00Z').toISOString().slice(0, 10) === v;
    if (!valid(from) || !valid(to) || from > to) throw fail('Use valid from/to dates in YYYY-MM-DD format.');
    where.createdAt = {
      [Op.gte]: new Date(new Date(from + 'T00:00:00Z').getTime() - 5 * 60 * 60 * 1000),
      [Op.lt]: new Date(new Date(to + 'T00:00:00Z').getTime() - 5 * 60 * 60 * 1000 + 86400000),
    };
  }
  return where;
}
async function list(restaurantId, user, query = {}) {
  const limit = Math.min(Math.max(Number(query.limit) || 50, 1), 200);
  const page = Math.max(Number(query.page) || 1, 1);
  if (!Number.isSafeInteger(page)) throw fail('Invalid page.');
  const where = { restaurantId, ...scope(user, query) };
  const result = await AuditLog.findAndCountAll({
    where,
    include: [{ model: User, as: 'actor', attributes: ['id', 'name', 'email'], required: false }],
    order: [['createdAt', 'DESC'], ['id', 'DESC']],
    limit, offset: (page - 1) * limit, distinct: true,
  });
  return {
    items: result.rows,
    pagination: { page, limit, total: result.count, totalPages: Math.ceil(result.count / limit) },
    filters: { branchId: query.branchId || null, actorUserId: query.actorUserId || null, action: query.action || null, entityType: query.entityType || null, from: query.from || null, to: query.to || null },
  };
}
module.exports = { list, scope };
