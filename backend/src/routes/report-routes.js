'use strict';
const router=require('express').Router();const {authenticate}=require('../middleware/auth');const {requirePermission}=require('../middleware/require-permission');const controller=require('../controllers/report-controller');
router.use(authenticate);
router.get('/sales',requirePermission('reports.view'),controller.overview);
module.exports=router;