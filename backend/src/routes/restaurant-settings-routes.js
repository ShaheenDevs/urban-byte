'use strict';

const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requirePermission } = require('../middleware/require-permission');
const controller = require('../controllers/restaurant-settings-controller');

router.use(authenticate, requirePermission('settings.manage'));
router.get('/', controller.get);
router.put('/', controller.update);

module.exports = router;
