'use strict';
function resolveNotificationRecipients(users,permissions,roleLinks,roleGrants,overrides){
 const granted=new Set();
 for(const link of roleLinks)for(const grant of roleGrants)if(String(link.roleId)===String(grant.roleId))granted.add(String(link.userId)+':'+String(grant.permissionId));
 const explicit=new Map(overrides.map(x=>[String(x.userId)+':'+String(x.permissionId),x.effect]));
 return users.filter(user=>permissions.some(permission=>{
  const key=String(user.id)+':'+String(permission.id),effect=explicit.get(key);
  if(effect==='deny')return false;
  return effect==='allow'||granted.has(key);
 })).map(user=>user.id);
}
module.exports={resolveNotificationRecipients};
