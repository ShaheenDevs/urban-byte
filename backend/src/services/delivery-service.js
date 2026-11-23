'use strict';
const {Op}=require('sequelize');
const {DeliveryAssignment,Order,Payment,PaymentEvent,User,Role,UserBranch,OrderStatusHistory,sequelize}=require('../models');
const {validateTransition}=require('./order-lifecycle');
function fail(message,status=400,code='DELIVERY_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
function id(value){const n=Number(value);if(!Number.isSafeInteger(n)||n<1)throw fail('A valid ID is required.');return n;}
function assertBranch(user,branchId){if((user.roles||[]).includes('admin'))return;const allowed=(user.branchIds||[]).map(Number);if(!allowed.includes(Number(branchId)))throw fail('You are not assigned to this branch.',403,'BRANCH_FORBIDDEN');}
async function assign(restaurantId,actor,orderId,input={}){
 const targetId=id(input.deliveryUserId);
 return sequelize.transaction(async t=>{
  const order=await Order.findOne({where:{id:id(orderId),restaurantId,orderType:'delivery'},transaction:t,lock:t.LOCK.UPDATE});
  if(!order)throw fail('Delivery order not found.',404,'ORDER_NOT_FOUND');
  assertBranch(actor,order.branchId);
  if(!['placed','confirmed','ready'].includes(order.status))throw fail('Order is not eligible for delivery assignment.',409);
  const driver=await User.findOne({where:{id:targetId,restaurantId,isActive:true},include:[{model:Role,as:'roles',where:{slug:'delivery'},through:{attributes:[]},required:true}],transaction:t});
  if(!driver)throw fail('Active delivery staff member not found.',404,'DELIVERY_USER_NOT_FOUND');
  const branchMembership=await UserBranch.findOne({where:{userId:driver.id,branchId:order.branchId},transaction:t});
  if(!branchMembership)throw fail('Selected delivery staff member is not assigned to this order branch.',403,'DELIVERY_DRIVER_BRANCH_MISMATCH');
  let assignment=await DeliveryAssignment.findOne({where:{restaurantId,orderId:order.id},transaction:t,lock:t.LOCK.UPDATE});
  const now=new Date();
  if(assignment){if(['delivered','cancelled'].includes(assignment.status))throw fail('This delivery assignment is already closed.',409);await assignment.update({deliveryUserId:driver.id,assignedByUserId:actor.id,status:'assigned',assignedAt:now,pickedUpAt:null,outForDeliveryAt:null,deliveredAt:null},{transaction:t});}
  else assignment=await DeliveryAssignment.create({restaurantId,branchId:order.branchId,orderId:order.id,deliveryUserId:driver.id,assignedByUserId:actor.id,status:'assigned',assignedAt:now,codAmount:order.paymentMethod==='cod'?order.grandTotal:0},{transaction:t});
  return assignment;
 });
}
async function drivers(restaurantId,user,filters={}) {
 const where={restaurantId,isActive:true};
 if(filters.branchId) {
  const branchId=id(filters.branchId);
  assertBranch(user,branchId);
  const memberships=await UserBranch.findAll({where:{branchId},attributes:['userId']});
  where.id=memberships.map(row=>row.userId);
 } else if(!(user.permissions||[]).includes('settings.manage')) {
  const branchIds=(user.branchIds||[]).map(Number).filter(n=>Number.isSafeInteger(n)&&n>0);
  const memberships=await UserBranch.findAll({where:{branchId:{[Op.in]:branchIds.length?branchIds:[-1]}},attributes:['userId']});
  where.id=memberships.map(row=>row.userId);
 }
 const rows=await User.findAll({where,attributes:['id','name','phone'],include:[{model:Role,as:'roles',where:{slug:'delivery'},attributes:['slug'],through:{attributes:[]},required:true}],order:[['name','ASC']]});
 return rows.map(row=>({id:String(row.id),name:row.name,phone:row.phone}));
}
async function list(restaurantId,user,filters={}){
 const where={restaurantId};
 if(!user.permissions.includes('delivery.assignments.view_all'))where.deliveryUserId=id(user.id);
 if(filters.branchId){const branchId=id(filters.branchId);assertBranch(user,branchId);where.branchId=branchId;}
 else if(!(user.roles||[]).includes('admin'))where.branchId={[Op.in]:(user.branchIds||[]).map(Number).filter(n=>Number.isSafeInteger(n)&&n>0).length?(user.branchIds||[]).map(Number):[-1]};
 if(filters.status){if(!['assigned','picked_up','out_for_delivery','delivered','cancelled'].includes(filters.status))throw fail('Invalid delivery status.');where.status=filters.status;}
 return DeliveryAssignment.findAll({where,include:[{model:Order,as:'order',attributes:['id','orderNumber','orderType','customerName','customerPhone','deliveryAddress','grandTotal','paymentMethod','paymentStatus','status','notes']},{model:User,as:'deliveryUser',attributes:['id','name','phone']}],order:[['assignedAt','DESC']],limit:Math.min(Math.max(Number(filters.limit)||50,1),100)});
}
async function updateStatus(restaurantId,user,assignmentId,input={}){
 const next=input.status;
 if(!['picked_up','out_for_delivery','delivered'].includes(next))throw fail('Status must be picked_up, out_for_delivery or delivered.');
 return sequelize.transaction(async t=>{
  const where={id:id(assignmentId),restaurantId};
  if(!user.permissions.includes('delivery.assignments.view_all'))where.deliveryUserId=id(user.id);
  const assignment=await DeliveryAssignment.findOne({where,transaction:t,lock:t.LOCK.UPDATE});
  if(!assignment)throw fail('Delivery assignment not found.',404,'ASSIGNMENT_NOT_FOUND');
  assertBranch(user,assignment.branchId);
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
    const existingPaid=Number(await Payment.sum('amount',{where:{orderId:order.id,restaurantId,status:'verified'},transaction:t})||0);
    const codDue=Math.max(0,Number(order.grandTotal)-existingPaid);
    if(codDue>0){
     const payment=await Payment.create({restaurantId,branchId:order.branchId,orderId:order.id,method:'cod',status:'verified',amount:codDue.toFixed(2),recordedByUserId:user.id,verifiedByUserId:user.id,verifiedAt:now,notes:'Cash on delivery collected by assigned delivery staff.'},{transaction:t});
     await PaymentEvent.create({paymentId:payment.id,eventType:'recorded',actorUserId:user.id,notes:'COD collected by delivery staff.'},{transaction:t});
     await PaymentEvent.create({paymentId:payment.id,eventType:'verified',actorUserId:user.id,notes:'COD collection verified at delivery.'},{transaction:t});
     await order.update({paymentStatus:'paid',paymentMethod:'cod'},{transaction:t});
    }
    changes.codCollected=true;changes.codCollectedAt=now;
   } else if(order.paymentStatus!=='paid') {
    throw fail('Verify full payment before marking this delivery complete.',409,'PAYMENT_REQUIRED');
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
module.exports={assign,list,drivers,updateStatus};