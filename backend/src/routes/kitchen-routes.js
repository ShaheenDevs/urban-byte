'use strict';
const router=require('express').Router(),{authenticate}=require('../middleware/auth'),{requirePermission}=require('../middleware/require-permission'),c=require('../controllers/kitchen-controller');
router.use(authenticate);
router.get('/tickets',requirePermission('kitchen.orders.view'),c.queue);
router.patch('/tickets/:ticketId/prepare',requirePermission('kitchen.orders.prepare'),c.prepare);
router.patch('/tickets/:ticketId/ready',requirePermission('kitchen.orders.ready'),c.ready);
module.exports=router;