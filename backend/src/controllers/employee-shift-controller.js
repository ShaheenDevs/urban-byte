'use strict';

const service = require('../services/employee-shift-service');
const { success } = require('../utils/api-response');
function restaurantId(req) {
  const id = Number(req.auth?.restaurantId);
  if (!Number.isSafeInteger(id) || id < 1) throw Object.assign(new Error('Staff account is not assigned to a restaurant.'), { statusCode: 403 });
  return id;
}
function actor(req) {
  const user = req.user || {};
  return { id: req.auth.sub, roles: user.roles || req.auth.roles || [], branchIds: user.branchIds || req.auth.branchIds || [] };
}
module.exports = {
  create(req, res, next) {
    service.create(restaurantId(req), actor(req), req.body || {}, req.ip)
      .then((data) => success(res, data, 'Employee shift scheduled.', 201)).catch(next);
  },
  list(req, res, next) {
    service.list(restaurantId(req), actor(req), req.query)
      .then((data) => success(res, data, 'Employee shifts loaded.')).catch(next);
  },
  cancel(req, res, next) {
    service.cancel(restaurantId(req), actor(req), req.params.id, req.ip)
      .then((data) => success(res, data, 'Employee shift cancelled.')).catch(next);
  },
};
