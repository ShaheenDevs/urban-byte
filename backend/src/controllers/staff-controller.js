'use strict';
const service=require('../services/staff-service');
const {success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;throw e;}return n;}
function actor(req){return {id:req.auth?.sub,ipAddress:req.ip};}
module.exports={
 list(req,res,next){Promise.resolve().then(()=>service.list(restaurant(req),req.query)).then(data=>success(res,data,'Staff loaded.')).catch(next);},
 create(req,res,next){Promise.resolve().then(()=>service.create(restaurant(req),req.body||{},actor(req))).then(data=>success(res,data,'Staff member created.',201)).catch(next);},
 update(req,res,next){Promise.resolve().then(()=>service.update(restaurant(req),req.params.userId,req.body||{},actor(req))).then(data=>success(res,data,'Staff member updated.')).catch(next);},
 roles(req,res,next){service.roles().then(data=>success(res,data,'Roles loaded.')).catch(next);},
 permissions(req,res,next){service.permissions().then(data=>success(res,data,'Permissions loaded.')).catch(next);},
 branches(req,res,next){service.branches(restaurant(req)).then(data=>success(res,data,'Branches loaded.')).catch(next);},
 override(req,res,next){Promise.resolve().then(()=>service.setOverride(restaurant(req),req.params.userId,req.body||{},actor(req))).then(data=>success(res,data,'Permission override saved.')).catch(next);},
 removeOverride(req,res,next){Promise.resolve().then(()=>service.removeOverride(restaurant(req),req.params.userId,req.params.permissionId,actor(req))).then(data=>success(res,data,'Permission override removed.')).catch(next);},
 history(req,res,next){Promise.resolve().then(()=>service.history(restaurant(req),req.query)).then(data=>success(res,data,'Audit history loaded.')).catch(next);}
};
