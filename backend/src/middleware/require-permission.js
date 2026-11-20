'use strict';
const { getCurrentUser } = require('../services/auth-service');
function requirePermission(permissionKey) {
  return async (req, res, next) => {
    try {
      const user = await getCurrentUser(req.auth.sub);
      if (!user) return res.status(401).json({ success: false, message: 'User account is unavailable.', code: 'ACCOUNT_UNAVAILABLE', data: null });
      req.user = user;
      if (!user.permissions.includes(permissionKey)) return res.status(403).json({ success: false, message: 'You do not have permission to perform this action.', code: 'FORBIDDEN', data: null });
      return next();
    } catch (error) { return next(error); }
  };
}
module.exports = { requirePermission };
