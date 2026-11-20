'use strict';
const router=require('express').Router(),{authenticate}=require('../middleware/auth'),{requirePermission}=require('../middleware/require-permission'),{requireAnyPermission}=require('../middleware/require-any-permission'),c=require('../controllers/order-controller');
router.use(authenticate);
router.post('/',requirePermission('orders.create'),c.create);
router.get('/',requireAnyPermission('orders.view_own','orders.view_all'),c.list);
router.get('/:orderId',requireAnyPermission('orders.view_own','orders.view_all'),c.get);
router.patch('/:orderId/status',requirePermission('orders.status.update'),c.updateStatus);
module.exports=router;