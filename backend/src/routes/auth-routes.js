'use strict';
const router = require('express').Router();
const controller = require('../controllers/auth-controller');
const { authenticate } = require('../middleware/auth');
const loginLimiter = require('express-rate-limit')({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: 'draft-7', legacyHeaders: false, message: { success: false, message: 'Too many login attempts. Try again later.', code: 'LOGIN_RATE_LIMITED', data: null } });

router.get('/roles', controller.publicRoles);
router.post('/login', loginLimiter, controller.login);
router.post('/refresh', controller.refresh);
router.post('/logout', controller.logout);
router.get('/me', authenticate, controller.me);
module.exports = router;
