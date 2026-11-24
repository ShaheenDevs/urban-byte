'use strict';
const service=require('../services/delivery-service'),{success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;throw e;}return n;}
module.exports={
 drivers(req,res,next){Promise.resolve().then(()=>service.drivers(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Delivery staff loaded.')).catch(next);},
 assign(req,res,next){Promise.resolve().then(()=>service.assign(restaurant(req),req.user,req.params.orderId,req.body||{})).then(data=>success(res,data,'Delivery assigned.',201)).catch(next);},
 unassigned(req,res,next){Promise.resolve().then(()=>service.unassigned(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Unassigned delivery orders loaded.')).catch(next);},
 list(req,res,next){Promise.resolve().then(()=>service.list(restaurant(req),req.user,req.query)).then(data=>success(res,data,'Delivery assignments loaded.')).catch(next);},
 status(req,res,next){Promise.resolve().then(()=>service.updateStatus(restaurant(req),req.user,req.params.assignmentId,req.body||{})).then(data=>success(res,data,'Delivery status updated.')).catch(next);}
};