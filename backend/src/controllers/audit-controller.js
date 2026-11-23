'use strict';
const service = require('../services/audit-service');
const { success } = require('../utils/api-response');
async function list(req, res, next) {
  const restaurantId = Number(req.auth?.restaurantId);
  if (!Number.isSafeInteger(restaurantId) || restaurantId < 1) {
    const error = new Error('Staff account is not assigned to a restaurant.');
    error.statusCode = 403;
    return next(error);
  }
  try {
    const result = await service.list(restaurantId, req.user, req.query);
    return success(res, result, 'Audit history loaded.');
  } catch (error) { return next(error); }
}
module.exports = { list };
