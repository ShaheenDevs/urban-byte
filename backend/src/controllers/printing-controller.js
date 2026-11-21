'use strict';
const service=require('../services/printing-service');const {success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;throw e;}return n;}
const wrap=(fn,msg,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req,restaurant(req))).then(data=>success(res,data,msg,status)).catch(next);
module.exports={
 register:wrap((r,id)=>service.registerPrinter(id,r.body||{}),'Printer registered.',201),
 printers:wrap((r,id)=>service.listPrinters(id,r.query.branchId),'Printers loaded.'),
 receipt:wrap((r,id)=>service.enqueue(id,r.user,r.params.orderId,'receipt',r.body||{}),'Receipt queued.',201),
 kitchen:wrap((r,id)=>service.enqueue(id,r.user,r.params.orderId,'kitchen_ticket',r.body||{}),'Kitchen ticket queued.',201),
 jobs:wrap((r,id)=>service.listJobs(id,r.query),'Print jobs loaded.'),
 next:wrap((r,id)=>service.claimNext(id,r.body?.branchId,r.body?.printerId),'Next print job loaded.'),
 status:wrap((r,id)=>service.updateStatus(id,r.params.jobId,r.body||{}),'Print job updated.'),
 retry:wrap((r,id)=>service.retry(id,r.params.jobId),'Print job queued for retry.')
};