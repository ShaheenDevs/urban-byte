'use strict';

const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requirePermission } = require('../middleware/require-permission');
const { requireAnyPermission } = require('../middleware/require-any-permission');
const controller = require('../controllers/restaurant-settings-controller');

router.use(authenticate);
router.get('/', requireAnyPermission('settings.manage', 'orders.create'), controller.get);
router.put('/', requirePermission('settings.manage'), controller.update);

module.exports = router;
