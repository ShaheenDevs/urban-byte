'use strict';
const {Op}=require('sequelize');
const {DeliveryAssignment,Order,User,Role,OrderStatusHistory,sequelize}=require('../models');
const {validateTransition}=require('./order-lifecycle');
function fail(message,status=400,code='DELIVERY_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
function id(value){const n=Number(value);if(!Number.isSafeInteger(n)||n<1)throw fail('A valid ID is required.');return n;}
async function assign(restaurantId,actor,orderId,input={}){
 const targetId=id(input.deliveryUserId);
 return sequelize.transaction(async t=>{
  const order=await Order.findOne({where:{id:id(orderId),restaurantId,orderType:'delivery'},transaction:t,lock:t.LOCK.UPDATE});
  if(!order)throw fail('Delivery order not found.',404,'ORDER_NOT_FOUND');
  if(!['placed','confirmed','ready'].includes(order.status))throw fail('Order is not eligible for delivery assignment.',409);
  const driver=await User.findOne({where:{id:targetId,restaurantId,isActive:true},include:[{model:Role,as:'roles',where:{slug:'delivery'},through:{attributes:[]},required:true}],transaction:t});
  if(!driver)throw fail('Active delivery staff member not found.',404,'DELIVERY_USER_NOT_FOUND');
  let assignment=await DeliveryAssignment.findOne({where:{restaurantId,orderId:order.id},transaction:t,lock:t.LOCK.UPDATE});
  const now=new Date();
  if(assignment){if(['delivered','cancelled'].includes(assignment.status))throw fail('This delivery assignment is already closed.',409);await assignment.update({deliveryUserId:driver.id,assignedByUserId:actor.id,status:'assigned',assignedAt:now,pickedUpAt:null,outForDeliveryAt:null,deliveredAt:null},{transaction:t});}
  else assignment=await DeliveryAssignment.create({restaurantId,branchId:order.branchId,orderId:order.id,deliveryUserId:driver.id,assignedByUserId:actor.id,status:'assigned',assignedAt:now,codAmount:order.paymentMethod==='cod'?order.grandTotal:0},{transaction:t});
  return assignment;
 });
}
async function list(restaurantId,user,filters={}){
 const where={restaurantId};
 if(!user.permissions.includes('delivery.assignments.view_all'))where.deliveryUserId=id(user.id);
 if(filters.branchId)where.branchId=id(filters.branchId);
 if(filters.status){if(!['assigned','picked_up','out_for_delivery','delivered','cancelled'].includes(filters.status))throw fail('Invalid delivery status.');where.status=filters.status;}
 return DeliveryAssignment.findAll({where,include:[{model:Order,as:'order',attributes:['id','orderNumber','orderType','customerName','customerPhone','deliveryAddress','grandTotal','paymentMethod','paymentStatus','status','notes']}],order:[['assignedAt','DESC']],limit:Math.min(Math.max(Number(filters.limit)||50,1),100)});
}
async function updateStatus(restaurantId,user,assignmentId,input={}){
 const next=input.status;
 if(!['picked_up','out_for_delivery','delivered'].includes(next))throw fail('Status must be picked_up, out_for_delivery or delivered.');
 return sequelize.transaction(async t=>{
  const where={id:id(assignmentId),restaurantId};
  if(!user.permissions.includes('delivery.assignments.view_all'))where.deliveryUserId=id(user.id);
  const assignment=await DeliveryAssignment.findOne({where,transaction:t,lock:t.LOCK.UPDATE});
  if(!assignment)throw fail('Delivery assignment not found.',404,'ASSIGNMENT_NOT_FOUND');
  const order=await Order.findOne({where:{id:assignment.orderId,restaurantId},transaction:t,lock:t.LOCK.UPDATE});
  if(!order)throw fail('Order not found.',404,'ORDER_NOT_FOUND');
  const now=new Date(),changes={status:next};
  if(next==='picked_up'){if(assignment.status!=='assigned')throw fail('Only assigned orders can be picked up.',409);changes.pickedUpAt=now;}
  if(next==='out_for_delivery'){if(assignment.status!=='picked_up')throw fail('Order must be picked up first.',409);if(order.status==='ready') {validateTransition('ready','out_for_delivery');await order.update({status:'out_for_delivery'},{transaction:t});await OrderStatusHistory.create({orderId:order.id,fromStatus:'ready',toStatus:'out_for_delivery',changedByUserId:user.id,note:'Delivery started'},{transaction:t});}else if(order.status!=='out_for_delivery')throw fail('Kitchen must mark this order ready before dispatch.',409);changes.outForDeliveryAt=now;}
  if(next==='delivered'){
   if(assignment.status!=='out_for_delivery')throw fail('Start the delivery route before marking an order delivered.',409);
   if(order.paymentMethod==='cod'&&Number(assignment.codAmount)>0&&!assignment.codCollected){
    if(input.codCollected!==true)throw fail('Confirm COD collection before marking delivered.',409,'COD_NOT_COLLECTED');
    if(!user.permissions.includes('payments.cod.collect'))throw fail('You do not have permission to record COD collection.',403,'FORBIDDEN');
    changes.codCollected=true;changes.codCollectedAt=now;
   }
   if(order.status==='out_for_delivery'){validateTransition('out_for_delivery','completed');await order.update({status:'completed',completedAt:now},{transaction:t});await OrderStatusHistory.create({orderId:order.id,fromStatus:'out_for_delivery',toStatus:'completed',changedByUserId:user.id,note:'Delivery completed'},{transaction:t});}
   else if(order.status!=='completed')throw fail('Order must be out for delivery before completion.',409);
   changes.deliveredAt=now;
  }
  if(input.note!==undefined)changes.deliveryNote=String(input.note).slice(0,500);
  await assignment.update(changes,{transaction:t});
  return DeliveryAssignment.findByPk(assignment.id,{include:[{model:Order,as:'order'}],transaction:t});
 });
}
module.exports={assign,list,updateStatus};