'use strict';
const service=require('../services/payment-service');const {success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;throw e;}return n;}
const wrap=(fn,msg,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req,restaurant(req))).then(data=>success(res,data,msg,status)).catch(next);
module.exports={
 record:wrap((r,id)=>service.record(id,r.user,r.body||{}),'Payment recorded.',201),
 codIntent:wrap((r,id)=>service.setCashOnDelivery(id,r.user,r.body||{}),'Cash on delivery selected.'),
 list:wrap((r,id)=>service.list(id,r.user,r.query),'Payments loaded.'),
 verify:wrap((r,id)=>service.verify(id,r.user,r.params.paymentId),'Payment verified.'),
 summary:wrap((r,id)=>service.dailySummary(id,r.user,r.query),'Daily payment summary loaded.')
};