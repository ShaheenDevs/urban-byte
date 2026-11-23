'use strict';
const { Op, fn, col } = require('sequelize');
const { Order, Branch, Payment } = require('../models');

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

function parsePeriod(query = {}) {
  const valid = (value) => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value + 'T00:00:00+05:00'));
  const today = new Date(Date.now() + KARACHI_OFFSET_MINUTES * 60_000).toISOString().slice(0, 10);
  const startDate = query.startDate || today;
  const endDate = query.endDate || today;
  if (!valid(startDate) || !valid(endDate) || startDate > endDate) {
    const error = new Error('Provide a valid date range using YYYY-MM-DD; start must not be after end.');
    error.statusCode = 400; error.code = 'INVALID_DATE_RANGE'; throw error;
  }
  const validTime = (value) => typeof value === 'string' && /^\\d{2}:\\d{2}$/.test(value) && Number(value.slice(0,2)) < 24 && Number(value.slice(3,5)) < 60;
  const startTime = query.startTime || null;
  const endTime = query.endTime || null;
  if ((startTime && !validTime(startTime)) || (endTime && !validTime(endTime)) || (!!startTime !== !!endTime)) {
    const error = new Error('Provide both startTime and endTime using HH:mm format.');
    error.statusCode = 400; error.code = 'INVALID_TIME_RANGE'; throw error;
  }
  return {
    startDate, endDate, startTime, endTime,
    start: new Date(startDate + 'T' + (startTime || '00:00') + ':00+05:00'),
    end: startTime
      ? new Date(new Date(endDate + 'T' + endTime + ':00+05:00').getTime() + 60000)
      : new Date(new Date(endDate + 'T00:00:00+05:00').getTime() + 86400000),
  };
}

async function getDashboardSummary(restaurantId, user, branchId, query = {}) {
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

  const { start, end, startDate, endDate } = parsePeriod(query);
  const todayWhere = { ...where, placedAt: { [Op.gte]: start, [Op.lt]: end } };
  const [todayOrders, openOrders, completedToday, pendingPayments, paidRevenue, statusRows, recentOrders] = await Promise.all([
    Order.count({ where: todayWhere }),
    Order.count({ where: { ...where, status: { [Op.in]: OPEN_STATUSES } } }),
    Order.count({ where: { ...todayWhere, status: 'completed' } }),
    Order.count({ where: { ...todayWhere, paymentStatus: { [Op.in]: ['unpaid', 'pending'] } } }),
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


  const pendingOrders = await Order.findAll({
    where: { ...todayWhere, paymentStatus: { [Op.in]: ['unpaid', 'pending', 'partially_paid'] } },
    attributes: ['id', 'grandTotal'],
    include: [{ model: Payment, as: 'payments', attributes: ['amount', 'status'], required: false }],
  });
  const pendingRevenue = pendingOrders.reduce((sum, order) => {
    const verified = (order.payments || []).filter((payment) => payment.status === 'verified')
      .reduce((paid, payment) => paid + Number(payment.amount || 0), 0);
    return sum + Math.max(0, Number(order.grandTotal || 0) - verified);
  }, 0);

  return {
    timezone: 'Asia/Karachi',
    period: { startDate, endDate, startTime, endTime, startsAt: start.toISOString(), endsAt: end.toISOString() },
    metrics: {
      todayOrders,
      openOrders,
      completedToday,
      pendingPayments,
      pendingRevenue: Number(pendingRevenue || 0).toFixed(2),
      paidRevenueToday: Number(paidRevenue || 0).toFixed(2),
    },
    statusBreakdown: statusRows.map((row) => ({ status: row.status, count: Number(row.count) })),
    recentOrders,
  };
}

module.exports = { getDashboardSummary, localDayBounds, orderScope };
