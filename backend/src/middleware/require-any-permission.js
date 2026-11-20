'use strict';
const {getCurrentUser}=require('../services/auth-service');
function requireAnyPermission(...keys){return async(req,res,next)=>{try{const user=await getCurrentUser(req.auth.sub);if(!user)return res.status(401).json({success:false,message:'User account is unavailable.',code:'ACCOUNT_UNAVAILABLE',data:null});req.user=user;if(!keys.some(key=>user.permissions.includes(key)))return res.status(403).json({success:false,message:'You do not have permission to perform this action.',code:'FORBIDDEN',data:null});next();}catch(error){next(error);}};}
module.exports={requireAnyPermission};