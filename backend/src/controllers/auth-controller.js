'use strict';

const authService = require('../services/auth-service');
const { success } = require('../utils/api-response');

async function login(req, res, next) {
  try {
    const { identifier, password } = req.body;
    if (typeof identifier !== 'string' || !identifier.trim() || typeof password !== 'string' || !password) {
      return res.status(422).json({ success: false, message: 'Identifier and password are required.', code: 'VALIDATION_ERROR', data: null });
    }
    return res.status(200).json(success('Login successful.', await authService.login(identifier.trim(), password)));
  } catch (error) { return next(error); }
}

async function refresh(req, res, next) {
  try {
    const { refreshToken } = req.body;
    if (typeof refreshToken !== 'string' || !refreshToken) return res.status(422).json({ success: false, message: 'Refresh token is required.', code: 'VALIDATION_ERROR', data: null });
    return res.status(200).json(success('Session refreshed.', await authService.refresh(refreshToken)));
  } catch (error) { return next(error); }
}

async function logout(req, res, next) {
  try {
    await authService.logout(req.body.refreshToken);
    return res.status(200).json(success('Session revoked.', null));
  } catch (error) { return next(error); }
}

async function me(req, res, next) {
  try {
    const user = await authService.getCurrentUser(req.auth.sub);
    if (!user) return res.status(401).json({ success: false, message: 'User account is unavailable.', code: 'ACCOUNT_UNAVAILABLE', data: null });
    return res.status(200).json(success('Current user loaded.', user));
  } catch (error) { return next(error); }
}

module.exports = { login, refresh, logout, me };
