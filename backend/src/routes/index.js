'use strict';
const router=require('express').Router();
router.use('/health',require('./health-routes'));
router.use('/auth',require('./auth-routes'));
router.use('/menu',require('./menu-routes'));
router.use('/orders',require('./order-routes'));
router.use('/kitchen',require('./kitchen-routes'));
router.use('/inventory',require('./inventory-routes'));
module.exports=router;