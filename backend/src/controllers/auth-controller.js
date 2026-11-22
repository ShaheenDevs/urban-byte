'use strict';

const authService = require('../services/auth-service');
const staffService = require('../services/staff-service');
const { success } = require('../utils/api-response');

async function login(req, res, next) {
  try {
    const { identifier, password } = req.body || {};
    if (typeof identifier !== 'string' || !identifier.trim() || typeof password !== 'string' || !password) {
      return res.status(422).json({ success: false, message: 'Identifier and password are required.', code: 'VALIDATION_ERROR', data: null });
    }
    return success(res, await authService.login(identifier.trim(), password), 'Login successful.');
  } catch (error) { return next(error); }
}

async function refresh(req, res, next) {
  try {
    const { refreshToken } = req.body || {};
    if (typeof refreshToken !== 'string' || !refreshToken) return res.status(422).json({ success: false, message: 'Refresh token is required.', code: 'VALIDATION_ERROR', data: null });
    return success(res, await authService.refresh(refreshToken), 'Session refreshed.');
  } catch (error) { return next(error); }
}

async function logout(req, res, next) {
  try {
    await authService.logout(req.body?.refreshToken);
    return success(res, null, 'Session revoked.');
  } catch (error) { return next(error); }
}

async function me(req, res, next) {
  try {
    const user = await authService.getCurrentUser(req.auth.sub);
    if (!user) return res.status(401).json({ success: false, message: 'User account is unavailable.', code: 'ACCOUNT_UNAVAILABLE', data: null });
    return success(res, user, 'Current user loaded.');
  } catch (error) { return next(error); }
}

async function publicRoles(req, res, next) {
  try {
    const roles = await staffService.roles();
    return success(res, roles.map(({ id, name, slug, description }) => ({ id, name, slug, description })), 'Available roles loaded.');
  } catch (error) { return next(error); }
}

module.exports = { login, refresh, logout, me, publicRoles };
