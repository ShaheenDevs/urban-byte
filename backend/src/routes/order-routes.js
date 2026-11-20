'use strict';
const router=require('express').Router(),{authenticate}=require('../middleware/auth'),{requirePermission}=require('../middleware/require-permission'),c=require('../controllers/order-controller');
router.use(authenticate);
router.post('/',requirePermission('orders.create'),c.create);
router.get('/',requirePermission('orders.view_own'),c.list);
router.get('/:orderId',requirePermission('orders.view_own'),c.get);
router.patch('/:orderId/status',requirePermission('orders.status.update'),c.updateStatus);
module.exports=router;
