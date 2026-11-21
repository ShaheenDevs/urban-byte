'use strict';
const router=require('express').Router();const c=require('../controllers/whatsapp-webhook-controller');
router.get('/webhook',c.verify);router.post('/webhook',c.receive);module.exports=router;