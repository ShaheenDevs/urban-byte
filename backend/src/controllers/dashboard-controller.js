'use strict';
const { success } = require('../utils/api-response');
const dashboardService = require('../services/dashboard-service');

function summary(req, res, next) {
  const restaurantId = Number(req.auth?.restaurantId);
  if (!Number.isSafeInteger(restaurantId) || restaurantId < 1) {
    const error = new Error('Staff account is not assigned to a restaurant.');
    error.statusCode = 403;
    error.code = 'RESTAURANT_NOT_ASSIGNED';
    return next(error);
  }
  return dashboardService.getDashboardSummary(restaurantId, req.user, req.query.branchId)
    .then((data) => success(res, data, 'Dashboard summary loaded.'))
    .catch(next);
}

module.exports = { summary };
