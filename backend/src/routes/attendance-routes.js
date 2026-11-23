'use strict';

const router = require('express').Router();
const { authenticate } = require('../middleware/auth');
const { requirePermission } = require('../middleware/require-permission');
const controller = require('../controllers/attendance-controller');

router.use(authenticate);
router.get('/me', controller.current);
router.post('/check-in', controller.checkIn);
router.post('/check-out', controller.checkOut);
router.get('/', requirePermission('staff.manage'), controller.list);

module.exports = router;
