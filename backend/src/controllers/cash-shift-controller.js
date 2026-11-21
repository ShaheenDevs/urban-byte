'use strict';
const service=require('../services/cash-shift-service');const {success}=require('../utils/api-response');
const wrap=(fn,msg,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req)).then(data=>success(res,data,msg,status)).catch(next);
module.exports={
 open:wrap(r=>service.open(Number(r.auth.restaurantId),r.user,r.body||{}),'Cash shift opened.',201),
 current:wrap(r=>service.current(Number(r.auth.restaurantId),r.query),'Cash shifts loaded.'),
 entry:wrap(r=>service.addEntry(Number(r.auth.restaurantId),r.user,r.params.shiftId,r.body||{}),'Cash entry recorded.',201),
 close:wrap(r=>service.close(Number(r.auth.restaurantId),r.user,r.params.shiftId,r.body||{}),'Cash shift closed.'),
 report:wrap(r=>service.report(Number(r.auth.restaurantId),r.params.shiftId),'Cash shift report loaded.')
};