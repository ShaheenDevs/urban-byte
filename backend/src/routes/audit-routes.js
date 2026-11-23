'use strict';
const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requirePermission } = require('../middleware/require-permission');
const controller = require('../controllers/audit-controller');
router.use(authenticate);
router.get('/', requirePermission('audit.view'), controller.list);
module.exports = router;
