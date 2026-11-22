'use strict';

const { RestaurantSetting } = require('../models');

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
  };
  if (values.taxEnabled && Number(values.taxRate) <= 0) throw fail('Enable a tax rate greater than zero, or disable tax.');
  if (values.serviceChargeEnabled && Number(values.serviceChargeRate) <= 0) throw fail('Enable a service charge rate greater than zero, or disable service charge.');
  const [row] = await RestaurantSetting.findOrCreate({ where: { restaurantId }, defaults: { restaurantId, ...values } });
  if (row.changed()) await row.update(values);
  else await row.update(values);
  return serialize(row);
}

module.exports = { get, update };
