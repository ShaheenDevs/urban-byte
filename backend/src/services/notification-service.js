'use strict';
const {Op}=require('sequelize');
const {Notification,Permission,Role,UserRole,User,UserPermission}=require('../models');
function fail(message,status=400,code='VALIDATION_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;throw e;}
async function recipientIds(restaurantId,permissionKeys,transaction){
 const [permissions,users]=await Promise.all([
  Permission.findAll({where:{permissionKey:{[Op.in]:permissionKeys}},attributes:['id'],transaction}),
  User.findAll({where:{restaurantId,isActive:true},attributes:['id'],transaction})
 ]);
 if(!permissions.length||!users.length)return [];
 const permissionIds=permissions.map(p=>String(p.id)),userIds=users.map(u=>String(u.id));
 const [roleLinks,roleGrants,overrides]=await Promise.all([
  UserRole.findAll({where:{userId:{[Op.in]:userIds}},attributes:['userId','roleId'],transaction}),
  require('../models').RolePermission.findAll({where:{permissionId:{[Op.in]:permissionIds}},attributes:['roleId','permissionId'],transaction}),
  UserPermission.findAll({where:{userId:{[Op.in]:userIds},permissionId:{[Op.in]:permissionIds}},attributes:['userId','permissionId','effect'],transaction})
 ]);
 const grantedByRole=new Set();
 for(const link of roleLinks){for(const grant of roleGrants){if(String(link.roleId)===String(grant.roleId))grantedByRole.add(String(link.userId)+':'+String(grant.permissionId));}}
 const explicit=new Map(overrides.map(x=>[String(x.userId)+':'+String(x.permissionId),x.effect]));
 return users.filter(user=>permissions.some(permission=>{
  const key=String(user.id)+':'+String(permission.id),effect=explicit.get(key);
  if(effect==='deny')return false;
  return effect==='allow'||grantedByRole.has(key);
 })).map(user=>user.id);
}
async function notifyPermissions(restaurantId,permissionKeys,payload,transaction){
 const ids=await recipientIds(restaurantId,permissionKeys,transaction);
 if(!ids.length)return [];
 const rows=ids.map(userId=>({restaurantId,userId,type:String(payload.type||'general').slice(0,80),title:String(payload.title||'Urban Byte update').slice(0,180),body:String(payload.body||'').slice(0,1000),data:payload.data||{}}));
 return Notification.bulkCreate(rows,{transaction});
}
async function list(user,filters={}){
 const limit=Math.min(Math.max(Number(filters.limit)||30,1),100),where={restaurantId:user.restaurantId,userId:user.id};
 if(filters.unread==='true')where.readAt=null;
 return Notification.findAll({where,order:[['createdAt','DESC']],limit});
}
async function markRead(user,id){const n=Number(id);if(!Number.isSafeInteger(n)||n<1)fail('A valid notification ID is required.');const row=await Notification.findOne({where:{id:n,restaurantId:user.restaurantId,userId:user.id}});if(!row)fail('Notification not found.',404,'NOTIFICATION_NOT_FOUND');if(!row.readAt)await row.update({readAt:new Date()});return row;}
async function markAllRead(user){return Notification.update({readAt:new Date()},{where:{restaurantId:user.restaurantId,userId:user.id,readAt:null}}).then(([count])=>({updated:count}));}
async function unreadCount(user){return Notification.count({where:{restaurantId:user.restaurantId,userId:user.id,readAt:null}});}
module.exports={notifyPermissions,list,markRead,markAllRead,unreadCount};