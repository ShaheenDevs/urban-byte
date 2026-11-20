const { nodeEnv } = require('../config/env');
function notFound(req, res) { return res.status(404).json({ success: false, message: 'Route not found', code: 'NOT_FOUND', data: null }); }
function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);
  const status = Number(err.statusCode || 500);
  const message = status >= 500 && nodeEnv === 'production' ? 'Internal server error' : err.message;
  if (nodeEnv !== 'test') console.error(err);
  return res.status(status).json({ success: false, message, code: err.code || 'INTERNAL_ERROR', data: null });
}
module.exports = { notFound, errorHandler };
