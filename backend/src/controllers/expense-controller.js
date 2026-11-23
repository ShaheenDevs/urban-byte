'use strict';
const service=require('../services/expense-service');const {success}=require('../utils/api-response');
const wrap=(fn,msg,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req)).then(data=>success(res,data,msg,status)).catch(next);
const restaurant=req=>{const id=Number(req.auth.restaurantId);if(!Number.isSafeInteger(id)||id<1)throw Object.assign(new Error('Restaurant context missing.'),{statusCode:403});return id;};
module.exports={
 list:wrap(r=>service.list(restaurant(r),r.user,r.query),'Expenses loaded.'),
 create:wrap(r=>service.create(restaurant(r),r.user,r.body||{}),'Expense submitted for approval.',201),
 approve:wrap(r=>service.approve(restaurant(r),r.user,r.params.expenseId),'Expense approved.'),
 reject:wrap(r=>service.reject(restaurant(r),r.user,r.params.expenseId,r.body||{}),'Expense rejected.'),
 summary:wrap(r=>service.summary(restaurant(r),r.user,r.query),'Expense summary loaded.')
};