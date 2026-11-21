'use strict';
const { Customer, Order } = require('../models');
function fail(message, statusCode = 400, code = 'VALIDATION_ERROR') { const error = new Error(message); error.statusCode = statusCode; error.code = code; return error; }
function normalizePhone(value) {
  if (typeof value !== 'string') throw fail('A valid customer phone number is required.');
  const phone = value.trim().replace(/[\s()-]/g, '');
  if (!/^\+?[0-9]{7,15}$/.test(phone)) throw fail('Phone number must contain 7 to 15 digits.');
  return phone;
}
function normalizeName(value) {
  if (typeof value !== 'string' || value.trim().length < 2) throw fail('Customer name must contain at least 2 characters.');
  return value.trim().slice(0, 150);
}
async function list(restaurantId, query = {}) {
  const limit = Math.min(Math.max(Number(query.limit) || 25, 1), 100);
  const offset = Math.max(Number(query.offset) || 0, 0);
  const where = { restaurantId, isActive: true };
  if (query.search) {
    const term = String(query.search).trim().slice(0, 100);
    where[require('sequelize').Op.or] = [
      { name: { [require('sequelize').Op.like]: '%' + term + '%' } },
      { phone: { [require('sequelize').Op.like]: '%' + term + '%' } }
    ];
  }
  const result = await Customer.findAndCountAll({ where, limit, offset, order: [['updatedAt', 'DESC']] });
  return { items: result.rows, total: result.count, limit, offset };
}
async function create(restaurantId, input = {}) {
  const phone = normalizePhone(input.phone);
  const values = { restaurantId, phone, name: normalizeName(input.name), email: input.email ? String(input.email).trim().slice(0, 190) : null, notes: input.notes ? String(input.notes).trim().slice(0, 2000) : null };
  const [customer, created] = await Customer.findOrCreate({ where: { restaurantId, phone }, defaults: values });
  if (!created) throw fail('A customer with this phone number already exists.', 409, 'CUSTOMER_EXISTS');
  return customer;
}
async function update(restaurantId, customerId, input = {}) {
  const customer = await Customer.findOne({ where: { id: Number(customerId), restaurantId, isActive: true } });
  if (!customer) throw fail('Customer not found.', 404, 'CUSTOMER_NOT_FOUND');
  const changes = {};
  if (input.name !== undefined) changes.name = normalizeName(input.name);
  if (input.phone !== undefined) changes.phone = normalizePhone(input.phone);
  if (input.email !== undefined) changes.email = input.email ? String(input.email).trim().slice(0, 190) : null;
  if (input.notes !== undefined) changes.notes = input.notes ? String(input.notes).trim().slice(0, 2000) : null;
  await customer.update(changes);
  return customer;
}
async function history(restaurantId, customerId, query = {}) {
  const customer = await Customer.findOne({ where: { id: Number(customerId), restaurantId, isActive: true } });
  if (!customer) throw fail('Customer not found.', 404, 'CUSTOMER_NOT_FOUND');
  const limit = Math.min(Math.max(Number(query.limit) || 20, 1), 100);
  const offset = Math.max(Number(query.offset) || 0, 0);
  const result = await Order.findAndCountAll({
    where: { restaurantId, customerPhone: customer.phone },
    attributes: ['id', 'orderNumber', 'orderType', 'source', 'status', 'paymentStatus', 'grandTotal', 'placedAt', 'completedAt'],
    order: [['placedAt', 'DESC']], limit, offset
  });
  const lifetimeValue = result.rows.reduce((sum, order) => sum + (order.paymentStatus === 'paid' ? Number(order.grandTotal) : 0), 0);
  return { customer, orders: result.rows, totalOrders: result.count, paidOrderValueInCurrentPage: lifetimeValue, limit, offset };
}
module.exports = { list, create, update, history, normalizePhone };
