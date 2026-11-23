'use strict';

const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requirePermission } = require('../middleware/require-permission');
const controller = require('../controllers/stock-transfer-controller');

router.use(authenticate);
router.get('/', requirePermission('inventory.view'), controller.list);
router.post('/', requirePermission('inventory.adjust'), controller.create);
router.post('/:id/approve', requirePermission('inventory.adjust'), controller.approve);
router.post('/:id/reject', requirePermission('inventory.adjust'), controller.reject);
router.post('/:id/receive', requirePermission('inventory.adjust'), controller.receive);
module.exports = router;
