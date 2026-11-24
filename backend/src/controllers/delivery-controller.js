'use strict';
const service=require('../services/delivery-service'),{success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;throw e;}return n;}
module.exports={
 drivers(req,res,next){Promise.resolve().then(()=>service.drivers(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Delivery staff loaded.')).catch(next);},
 assign(req,res,next){Promise.resolve().then(()=>service.assign(restaurant(req),req.user,req.params.orderId,req.body||{})).then(data=>success(res,data,'Delivery assigned.',201)).catch(next);},
 unassigned(req,res,next){Promise.resolve().then(()=>service.unassigned(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Unassigned delivery orders loaded.')).catch(next);},
 list(req,res,next){Promise.resolve().then(()=>service.list(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Delivery assignments loaded.')).catch(next);},
 history(req,res,next){Promise.resolve().then(()=>service.history(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Rider delivery history loaded.')).catch(next);},
 codCollections(req,res,next){Promise.resolve().then(()=>service.codCollections(restaurant(req),req.user,req.query)).then(data=>success(res,data,'COD collection report loaded.')).catch(next);},
 analytics(req,res,next){Promise.resolve().then(()=>service.analytics(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Delivery performance analytics loaded.')).catch(next);},
 submitCodSettlement(req,res,next){Promise.resolve().then(()=>service.submitCodSettlement(restaurant(req),req.user,req.body||{})).then(data=>success(res,data,'COD cash handover submitted for approval.',201)).catch(next);},
 listCodSettlements(req,res,next){Promise.resolve().then(()=>service.listCodSettlements(restaurant(req),req.user,req.query)).then(data=>success(res,data,'COD cash settlements loaded.')).catch(next);},
 reviewCodSettlement(req,res,next){Promise.resolve().then(()=>service.reviewCodSettlement(restaurant(req),req.user,req.params.settlementId,req.body?.approve===true,req.body||{})).then(data=>success(res,data,'COD cash settlement reviewed.')).catch(next);},
 updateLocation(req,res,next){Promise.resolve().then(()=>service.updateRiderLocation(restaurant(req),req.user,req.params.assignmentId,req.body||{})).then(data=>success(res,data,'Rider location updated.')).catch(next);},
 status(req,res,next){Promise.resolve().then(()=>service.updateStatus(restaurant(req),req.user,req.params.assignmentId,req.body||{})).then(data=>success(res,data,'Delivery status updated.')).catch(next);}
};
