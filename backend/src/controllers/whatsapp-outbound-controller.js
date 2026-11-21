'use strict';
const service=require('../services/whatsapp-outbound-service');const {success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;throw e;}return n;}
async function send(req,res,next){try{return success(res,await service.sendText(restaurant(req),req.params.conversationId,req.body||{}),'WhatsApp message sent.',201);}catch(e){return next(e);}}
module.exports={send};