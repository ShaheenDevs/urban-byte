'use strict';
const router=require('express').Router();const {authenticate}=require('../middleware/auth');const {requirePermission}=require('../middleware/require-permission');const c=require('../controllers/expense-controller');
router.use(authenticate);
router.get('/',requirePermission('expenses.view'),c.list);
router.post('/',requirePermission('expenses.create'),c.create);
router.get('/reports/summary',requirePermission('expenses.view'),c.summary);
router.post('/:expenseId/approve',requirePermission('expenses.approve'),c.approve);
router.post('/:expenseId/reject',requirePermission('expenses.approve'),c.reject);
module.exports=router;