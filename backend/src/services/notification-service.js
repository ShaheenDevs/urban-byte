'use strict';
const {Op}=require('sequelize');
const {Notification,Permission,Role,UserRole,User,UserPermission}=require('../models');
function fail(message,status=400,code='VALIDATION_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;throw e;}
async function recipientIds(restaurantId,permissionKeys,transaction){
 const permissions=await Permission.findAll({where:{permissionKey:{[Op.in]:permissionKeys}},attributes:['id'],transaction});
 if(!permissions.length)return [];
 const roleGrants=await require('../models').RolePermission.findAll({where:{permissionId:{[Op.in]:permissions.map(p=>p.id)}},attributes:['roleId'],transaction});
 const roleIds=[...new Set(roleGrants.map(x=>String(x.roleId)))];if(!roleIds.length)return [];
 const links=await UserRole.findAll({where:{roleId:{[Op.in]:roleIds}},attributes:['userId'],transaction});
 const userIds=[...new Set(links.map(x=>String(x.userId)))];if(!userIds.length)return [];
 const users=await User.findAll({where:{id:{[Op.in]:userIds},restaurantId,isActive:true},attributes:['id'],transaction});
 if(!users.length)return [];
 const overrides=await UserPermission.findAll({where:{userId:{[Op.in]:users.map(u=>u.id)},permissionId:{[Op.in]:permissions.map(p=>p.id)},effect:'deny'},attributes:['userId','permissionId'],transaction});
 const denied=new Set(overrides.map(x=>String(x.userId)+':'+String(x.permissionId)));
 const allowed=[];
 for(const user of users){let granted=false;for(const permission of permissions){const roleHas=roleGrants.some(r=>String(r.roleId)===String(links.find(l=>String(l.userId)===String(user.id))?.roleId));if(roleHas&&!denied.has(String(user.id)+':'+String(permission.id))){granted=true;break;}}if(granted)allowed.push(user.id);}
 return allowed;
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