'use strict';
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requireAnyPermission } = require('../middleware/require-any-permission');
const { requirePermission } = require('../middleware/require-permission');
const controller = require('../controllers/dashboard-controller');

router.use(authenticate);
router.get('/summary',
  requireAnyPermission('dashboard.view', 'orders.view_all', 'orders.view_own', 'kitchen.orders.view'),
  requirePermission('dashboard.view'),
  controller.summary,
);

module.exports = router;
