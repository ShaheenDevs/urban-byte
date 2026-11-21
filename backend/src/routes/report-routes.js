'use strict';
const router=require('express').Router();const {authenticate}=require('../middleware/auth');const {requirePermission}=require('../middleware/require-permission');const controller=require('../controllers/report-controller');
router.use(authenticate);
router.get('/sales',requirePermission('reports.view'),controller.overview);
router.get('/financial',requirePermission('reports.view'),controller.financial);
router.get('/analytics',requirePermission('reports.view'),controller.analytics);\nrouter.get('/financial/export.csv',requirePermission('reports.view'),controller.financialCsv);\nrouter.get('/financial/export.pdf',requirePermission('reports.view'),controller.financialPdf);\nrouter.get('/analytics/export.csv',requirePermission('reports.view'),controller.analyticsCsv);\nrouter.get('/analytics/export.pdf',requirePermission('reports.view'),controller.analyticsPdf);
module.exports=router;