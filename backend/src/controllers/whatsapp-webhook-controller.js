'use strict';
const {success}=require('../utils/api-response');const service=require('../services/whatsapp-webhook-service');
function verify(req,res){const challenge=service.verifyChallenge(req.query['hub.mode'],req.query['hub.verify_token'],req.query['hub.challenge']);if(challenge===null)return res.sendStatus(403);return res.status(200).type('text/plain').send(challenge);}
async function receive(req,res,next){try{if(!service.verifyWebhookSignature(req.rawBody,req.get('x-hub-signature-256')))return res.sendStatus(401);const result=await service.processWebhook(req.body);return success(res,result,'Webhook accepted.');}catch(e){return next(e);}}
module.exports={verify,receive};