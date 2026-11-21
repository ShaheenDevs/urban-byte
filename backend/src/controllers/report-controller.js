'use strict';
const service=require('../services/report-service');const {success}=require('../utils/api-response');
function overview(req,res,next){
 const restaurantId=Number(req.auth?.restaurantId);
 if(!Number.isSafeInteger(restaurantId)||restaurantId<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;return next(e);}
 return service.overview(restaurantId,req.query).then(data=>success(res,data,'Sales report loaded.')).catch(next);
}
function financial(req,res,next){const restaurantId=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(restaurantId)||restaurantId<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;return next(e);}return service.financial(restaurantId,req.query).then(data=>success(res,data,'Financial report loaded.')).catch(next);}\nmodule.exports={overview,financial};