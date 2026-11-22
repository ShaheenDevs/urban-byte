'use strict';

const service = require('../services/restaurant-settings-service');
const { success } = require('../utils/api-response');

function restaurant(req) {
  const id = Number(req.auth?.restaurantId);
  if (!Number.isSafeInteger(id) || id < 1) {
    const error = new Error('Staff account is not assigned to a restaurant.');
    error.statusCode = 403;
    throw error;
  }
  return id;
}

module.exports = {
  get(req, res, next) {
    return Promise.resolve().then(() => service.get(restaurant(req)))
      .then((data) => success(res, data, 'Restaurant settings loaded.'))
      .catch(next);
  },
  update(req, res, next) {
    return Promise.resolve().then(() => service.update(restaurant(req), req.body || {}))
      .then((data) => success(res, data, 'Restaurant settings saved.'))
      .catch(next);
  },
};
