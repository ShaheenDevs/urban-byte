'use strict';

const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requirePermission } = require('../middleware/require-permission');
const controller = require('../controllers/employee-shift-controller');

router.use(authenticate, requirePermission('staff.manage'));
router.get('/', controller.list);
router.post('/', controller.create);
router.patch('/:id/cancel', controller.cancel);
module.exports = router;
