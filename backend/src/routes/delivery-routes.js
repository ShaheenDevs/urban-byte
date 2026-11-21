'use strict';
const router=require('express').Router(),{authenticate}=require('../middleware/auth'),{requirePermission}=require('../middleware/require-permission'),{requireAnyPermission}=require('../middleware/require-any-permission'),c=require('../controllers/delivery-controller');
router.use(authenticate);
router.post('/orders/:orderId/assign',requirePermission('delivery.assign'),c.assign);
router.get('/assignments',requireAnyPermission('delivery.assignments.view_all','delivery.view_assigned'),c.list);
router.patch('/assignments/:assignmentId/status',requirePermission('delivery.status.update'),c.status);
module.exports=router;