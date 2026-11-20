'use strict';
const router=require('express').Router(),{authenticate}=require('../middleware/auth'),{requirePermission}=require('../middleware/require-permission'),c=require('../controllers/menu-controller');
router.use(authenticate);
router.get('/categories',requirePermission('menu.view'),c.listCategories);router.post('/categories',requirePermission('menu.manage'),c.createCategory);router.patch('/categories/:categoryId',requirePermission('menu.manage'),c.updateCategory);
router.get('/products',requirePermission('menu.view'),c.listProducts);router.post('/products',requirePermission('menu.manage'),c.createProduct);router.put('/branches/:branchId/variants/:variantId/price',requirePermission('menu.manage'),c.setBranchPrice);
router.get('/deals',requirePermission('menu.view'),c.listDeals);router.post('/deals',requirePermission('deals.manage'),c.createDeal);
module.exports=router;