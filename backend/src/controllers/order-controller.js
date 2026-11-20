'use strict';
const service=require('../services/order-service'),{success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;e.code='RESTAURANT_NOT_ASSIGNED';throw e;}return n;}
const wrap=(fn,message,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req,restaurant(req))).then(data=>success(res,data,message,status)).catch(next);
module.exports={
 create:wrap((r,id)=>service.createOrder(id,r.user,r.body||{},r.get('Idempotency-Key')),'Order created.',201),
 list:wrap((r,id)=>service.listOrders(id,r.user,r.query),'Orders loaded.'),
 get:wrap((r,id)=>service.getOrder(id,r.params.orderId,r.user),'Order loaded.'),
 updateStatus:wrap((r,id)=>service.updateStatus(id,r.params.orderId,r.user,r.body||{}),'Order status updated.')
};
