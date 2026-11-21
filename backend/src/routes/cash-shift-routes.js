'use strict';
const router=require('express').Router();const {authenticate}=require('../middleware/auth');const {requirePermission}=require('../middleware/require-permission');const c=require('../controllers/cash-shift-controller');
router.use(authenticate);
router.post('/open',requirePermission('cash_shifts.open'),c.open);
router.get('/current',requirePermission('cash_shifts.view'),c.current);
router.post('/:shiftId/entries',requirePermission('cash_shifts.manage'),c.entry);
router.post('/:shiftId/close',requirePermission('cash_shifts.close'),c.close);
router.get('/:shiftId/report',requirePermission('cash_shifts.view'),c.report);
module.exports=router;