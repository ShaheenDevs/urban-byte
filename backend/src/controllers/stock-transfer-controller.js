'use strict';

const service = require('../services/stock-transfer-service');
const { success } = require('../utils/api-response');

function restaurant(req) {
  const id = Number(req.auth?.restaurantId);
  if (!Number.isSafeInteger(id) || id < 1) throw Object.assign(new Error('Staff account is not assigned to a restaurant.'), { statusCode: 403, code: 'RESTAURANT_NOT_ASSIGNED' });
  return id;
}
function actor(req) { return req.user || { id: req.auth.sub, roles: req.auth.roles || [], branchIds: req.auth.branchIds || [] }; }
module.exports = {
  create(req, res, next) {
    service.create(restaurant(req), actor(req), req.body || {}).then((data) => success(res, data, 'Stock transfer request created.', 201)).catch(next);
  },
  list(req, res, next) {
    service.list(restaurant(req), actor(req), req.query || {}).then((data) => success(res, data, 'Stock transfer requests loaded.')).catch(next);
  },
  approve(req, res, next) {
    service.review(restaurant(req), actor(req), req.params.id, 'approve', req.body || {}).then((data) => success(res, data, 'Transfer approved and dispatched.')).catch(next);
  },
  reject(req, res, next) {
    service.review(restaurant(req), actor(req), req.params.id, 'reject', req.body || {}).then((data) => success(res, data, 'Transfer rejected.')).catch(next);
  },
  receive(req, res, next) {
    service.receive(restaurant(req), actor(req), req.params.id, req.body || {}).then((data) => success(res, data, 'Transfer receiving recorded.')).catch(next);
  },
};
