'use strict';

const { RestaurantSetting, User, Role } = require('../models');

function fail(message) {
  const error = new Error(message);
  error.statusCode = 400;
  error.code = 'INVALID_RESTAURANT_SETTINGS';
  return error;
}

function rate(value, label, max = 100) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0 || number > max) throw fail(label + ' must be between 0 and ' + max + '.');
  return number.toFixed(4);
}

function serialize(row) {
  return {
    restaurantId: row.restaurantId,
    taxEnabled: row.taxEnabled,
    taxRate: Number(row.taxRate),
    taxInclusive: row.taxInclusive,
    serviceChargeEnabled: row.serviceChargeEnabled,
    serviceChargeRate: Number(row.serviceChargeRate),
    discountEnabled: row.discountEnabled,
    maxDiscountPercent: Number(row.maxDiscountPercent),
    receiptHeader: row.receiptHeader,
    receiptFooter: row.receiptFooter,
    diningTables: row.diningTables || [],
    orderTypes: row.orderTypes || [{ key: 'dine_in', name: 'Dine In' }, { key: 'takeaway', name: 'Takeaway' }, { key: 'delivery', name: 'Delivery' }],
    kitchenPrintGroups: row.kitchenPrintGroups || [],
    defaultDeliveryUserId: row.defaultDeliveryUserId == null ? null : String(row.defaultDeliveryUserId),
    deliveryBaseFee: Number(row.deliveryBaseFee || 0),
    deliveryPerKmFee: Number(row.deliveryPerKmFee || 0),
    deliveryFreeRadiusKm: Number(row.deliveryFreeRadiusKm || 0),
  };
}

async function get(restaurantId) {
  const [row] = await RestaurantSetting.findOrCreate({ where: { restaurantId }, defaults: { restaurantId } });
  return serialize(row);
}

async function update(restaurantId, input = {}) {
  const values = {
    taxEnabled: input.taxEnabled === true,
    taxRate: rate(input.taxRate ?? 0, 'Tax rate'),
    taxInclusive: input.taxInclusive === true,
    serviceChargeEnabled: input.serviceChargeEnabled === true,
    serviceChargeRate: rate(input.serviceChargeRate ?? 0, 'Service charge rate'),
    discountEnabled: input.discountEnabled !== false,
    maxDiscountPercent: rate(input.maxDiscountPercent ?? 20, 'Maximum discount', 100),
    receiptHeader: input.receiptHeader == null ? null : String(input.receiptHeader).trim().slice(0, 250),
    receiptFooter: input.receiptFooter == null ? null : String(input.receiptFooter).trim().slice(0, 500),
    deliveryBaseFee: rate(input.deliveryBaseFee ?? 0, 'Delivery base fee', 99999999),
    deliveryPerKmFee: rate(input.deliveryPerKmFee ?? 0, 'Delivery per-km fee', 99999999),
    deliveryFreeRadiusKm: rate(input.deliveryFreeRadiusKm ?? 0, 'Free delivery radius', 1000),
    diningTables: Array.isArray(input.diningTables) ? input.diningTables.map((t) => ({ id: String(t.id || '').slice(0, 40), name: String(t.name || '').trim().slice(0, 80), branchId: t.branchId ? Number(t.branchId) : null, isActive: t.isActive !== false })).filter((t) => t.id && t.name).slice(0, 200) : undefined,
    orderTypes: Array.isArray(input.orderTypes) ? input.orderTypes.map((t) => ({ key: String(t.key || '').trim().toLowerCase().replace(/[^a-z0-9_]/g, '_').slice(0, 40), name: String(t.name || '').trim().slice(0, 80) })).filter((t) => t.key && t.name).slice(0, 30) : undefined,
    kitchenPrintGroups: Array.isArray(input.kitchenPrintGroups) ? input.kitchenPrintGroups.map((g) => ({
      id: String(g.id || '').slice(0, 50),
      name: String(g.name || '').trim().slice(0, 100),
      branchId: g.branchId ? Number(g.branchId) : null,
      printerId: g.printerId ? Number(g.printerId) : null,
      categoryIds: Array.isArray(g.categoryIds) ? [...new Set(g.categoryIds.map(Number).filter((n) => Number.isSafeInteger(n) && n > 0))].slice(0, 100) : [],
      productIds: Array.isArray(g.productIds) ? [...new Set(g.productIds.map(Number).filter((n) => Number.isSafeInteger(n) && n > 0))].slice(0, 300) : [],
      excludedProductIds: Array.isArray(g.excludedProductIds) ? [...new Set(g.excludedProductIds.map(Number).filter((n) => Number.isSafeInteger(n) && n > 0))].slice(0, 300) : [],
      isActive: g.isActive !== false,
    })).filter((g) => g.id && g.name && (g.categoryIds.length || g.productIds.length)).slice(0, 50) : undefined,
  };
  if (input.defaultDeliveryUserId !== undefined) {
    if (input.defaultDeliveryUserId === null || input.defaultDeliveryUserId === '') {
      values.defaultDeliveryUserId = null;
    } else {
      const driverId = Number(input.defaultDeliveryUserId);
      if (!Number.isSafeInteger(driverId) || driverId < 1) throw fail('Select a valid default delivery staff member.');
      const driver = await User.findOne({ where: { id: driverId, restaurantId, isActive: true }, include: [{ model: Role, as: 'roles', where: { slug: 'delivery' }, through: { attributes: [] }, required: true }] });
      if (!driver) throw fail('Default delivery staff must be an active Delivery-role employee of this restaurant.');
      values.defaultDeliveryUserId = driver.id;
    }
  }
  if (values.taxEnabled && Number(values.taxRate) <= 0) throw fail('Enable a tax rate greater than zero, or disable tax.');
  if (values.serviceChargeEnabled && Number(values.serviceChargeRate) <= 0) throw fail('Enable a service charge rate greater than zero, or disable service charge.');
  const [row] = await RestaurantSetting.findOrCreate({ where: { restaurantId }, defaults: { restaurantId, ...values } });
  if (values.diningTables === undefined) delete values.diningTables;
  if (values.orderTypes === undefined) delete values.orderTypes;
  if (values.kitchenPrintGroups === undefined) delete values.kitchenPrintGroups;
  if (values.orderTypes && !values.orderTypes.some((t) => t.key === 'takeaway')) throw fail('At least one Takeaway order type must remain configured.');
  if (row.changed()) await row.update(values);
  else await row.update(values);
  return serialize(row);
}

module.exports = { get, update };
