'use strict';
const router=require('express').Router(),{authenticate}=require('../middleware/auth'),{requirePermission}=require('../middleware/require-permission'),c=require('../controllers/inventory-controller');
router.use(authenticate);
router.get('/items',requirePermission('inventory.view'),c.listItems);
router.post('/items',requirePermission('inventory.manage'),c.createItem);
router.get('/stock',requirePermission('inventory.view'),c.stock);
router.post('/stock/adjust',requirePermission('inventory.adjust'),c.adjust);
router.get('/movements',requirePermission('inventory.view'),c.movements);
module.exports=router;