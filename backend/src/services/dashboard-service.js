'use strict';
const { Op, fn, col } = require('sequelize');
const { Order, Branch } = require('../models');

const OPEN_STATUSES = ['placed', 'confirmed', 'preparing', 'ready', 'out_for_delivery'];
const KARACHI_OFFSET_MINUTES = 300;

function localDayBounds(now = new Date()) {
  const local = new Date(now.getTime() + KARACHI_OFFSET_MINUTES * 60_000);
  const start = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - KARACHI_OFFSET_MINUTES * 60_000);
  return { start, end: new Date(start.getTime() + 24 * 60 * 60_000) };
}

function orderScope(user) {
  const permissions = new Set(user.permissions || []);
  if (permissions.has('orders.view_all')) return {};
  if (permissions.has('kitchen.orders.view')) return { status: { [Op.in]: ['confirmed', 'preparing', 'ready'] } };
  if (permissions.has('orders.view_own')) return { createdByUserId: Number(user.id) };
  return { id: -1 };
}

async function getDashboardSummary(restaurantId, user, branchId) {
  const scope = orderScope(user);
  const where = { restaurantId, ...scope };
  if (branchId !== undefined && branchId !== null && branchId !== '') {
    const id = Number(branchId);
    if (!Number.isSafeInteger(id) || id < 1) {
      const error = new Error('branchId must be a valid positive integer.');
      error.statusCode = 400;
      error.code = 'INVALID_BRANCH';
      throw error;
    }
    const branch = await Branch.findOne({ where: { id, restaurantId, isActive: true }, attributes: ['id'] });
    if (!branch) {
      const error = new Error('Branch not found for this restaurant.');
      error.statusCode = 404;
      error.code = 'BRANCH_NOT_FOUND';
      throw error;
    }
    where.branchId = id;
  }

  const { start, end } = localDayBounds();
  const todayWhere = { ...where, placedAt: { [Op.gte]: start, [Op.lt]: end } };
  const [todayOrders, openOrders, completedToday, pendingPayments, paidRevenue, statusRows, recentOrders] = await Promise.all([
    Order.count({ where: todayWhere }),
    Order.count({ where: { ...where, status: { [Op.in]: OPEN_STATUSES } } }),
    Order.count({ where: { ...todayWhere, status: 'completed' } }),
    Order.count({ where: { ...where, paymentStatus: { [Op.in]: ['unpaid', 'pending'] } } }),
    Order.sum('grandTotal', { where: { ...todayWhere, paymentStatus: 'paid' } }),
    Order.findAll({ where, attributes: ['status', [fn('COUNT', col('id')), 'count']], group: ['status'], raw: true }),
    Order.findAll({
      where,
      attributes: ['id', 'orderNumber', 'orderType', 'status', 'paymentStatus', 'grandTotal', 'customerName', 'placedAt'],
      order: [['placedAt', 'DESC']],
      limit: 6,
      raw: true,
    }),
  ]);

  return {
    timezone: 'Asia/Karachi',
    period: { startsAt: start.toISOString(), endsAt: end.toISOString() },
    metrics: {
      todayOrders,
      openOrders,
      completedToday,
      pendingPayments,
      paidRevenueToday: Number(paidRevenue || 0).toFixed(2),
    },
    statusBreakdown: statusRows.map((row) => ({ status: row.status, count: Number(row.count) })),
    recentOrders,
  };
}

module.exports = { getDashboardSummary, localDayBounds, orderScope };
