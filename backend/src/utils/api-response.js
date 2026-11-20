function success(res, data = null, message = 'Success', statusCode = 200) { return res.status(statusCode).json({ success: true, message, data }); }
function failure(res, message = 'Request failed', statusCode = 400, code = 'REQUEST_FAILED') { return res.status(statusCode).json({ success: false, message, code, data: null }); }
module.exports = { success, failure };
