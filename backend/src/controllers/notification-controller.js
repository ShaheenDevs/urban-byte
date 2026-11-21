'use strict';
const service=require('../services/notification-service');
const {success}=require('../utils/api-response');
function tenant(req){const id=Number(req.user?.restaurantId);if(!Number.isSafeInteger(id)||id<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;e.code='RESTAURANT_NOT_ASSIGNED';throw e;}return id;}
module.exports={
 list(req,res,next){Promise.resolve().then(()=>service.list(req.user,req.query)).then(data=>success(res,data,'Notifications loaded.')).catch(next);},
 unread(req,res,next){Promise.resolve().then(()=>service.unreadCount(req.user)).then(data=>success(res,{count:data},'Unread count loaded.')).catch(next);},
 read(req,res,next){Promise.resolve().then(()=>service.markRead(req.user,req.params.notificationId)).then(data=>success(res,data,'Notification marked as read.')).catch(next);},
 readAll(req,res,next){Promise.resolve().then(()=>service.markAllRead(req.user)).then(data=>success(res,data,'Notifications marked as read.')).catch(next);}
};