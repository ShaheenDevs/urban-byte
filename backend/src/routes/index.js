'use strict';
const router=require('express').Router();
router.use('/health',require('./health-routes'));
router.use('/auth',require('./auth-routes'));
router.use('/menu',require('./menu-routes'));
module.exports=router;