'use strict';

const service = require('../services/attendance-service');
const { success } = require('../utils/api-response');

function restaurantId(req) {
  const id = Number(req.auth?.restaurantId);
  if (!Number.isSafeInteger(id) || id < 1) throw Object.assign(new Error('Staff account is not assigned to a restaurant.'), { statusCode: 403 });
  return id;
}
module.exports = {
  checkIn(req, res, next) {
    service.checkIn(restaurantId(req), req.auth.sub, req.body || {}, req.ip)
      .then((data) => success(res, data, 'Attendance check-in recorded.', 201)).catch(next);
  },
  checkOut(req, res, next) {
    service.checkOut(restaurantId(req), req.auth.sub, req.body || {}, req.ip)
      .then((data) => success(res, data, 'Attendance check-out recorded.')).catch(next);
  },
  current(req, res, next) {
    service.current(restaurantId(req), req.auth.sub)
      .then((data) => success(res, data, 'Current attendance loaded.')).catch(next);
  },
  list(req, res, next) {
    service.list(restaurantId(req), req.query)
      .then((data) => success(res, data, 'Attendance history loaded.')).catch(next);
  },
};
