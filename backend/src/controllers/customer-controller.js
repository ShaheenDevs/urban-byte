'use strict';
const service = require('../services/customer-service');
const { success } = require('../utils/api-response');
function restaurantId(req) {
  const id = Number(req.auth && req.auth.restaurantId);
  if (!Number.isSafeInteger(id) || id < 1) { const error = new Error('Staff account is not assigned to a restaurant.'); error.statusCode = 403; error.code = 'RESTAURANT_NOT_ASSIGNED'; throw error; }
  return id;
}
const wrap = (fn, message, status = 200) => (req, res, next) => Promise.resolve().then(() => fn(req, restaurantId(req))).then(data => success(res, data, message, status)).catch(next);
module.exports = {
  list: wrap((req, id) => service.list(id, req.query), 'Customers loaded.'),
  create: wrap((req, id) => service.create(id, req.body || {}), 'Customer created.', 201),
  update: wrap((req, id) => service.update(id, req.params.customerId, req.body || {}), 'Customer updated.'),
  history: wrap((req, id) => service.history(id, req.params.customerId, req.query), 'Customer order history loaded.')
};
