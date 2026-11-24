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
  if(!['placed','confirmed','preparing','ready'].includes(order.status))throw fail('Order is not eligible for delivery assignment.',409);
  const isWaiter=(actor.roles||[]).includes('waiter')&&!(actor.roles||[]).includes('admin')&&!(actor.roles||[]).includes('supervisor');
  if(isWaiter&&Number(order.createdByUserId)!==Number(actor.id))throw fail('Waiters can only assign delivery riders to their own orders.',403,'DELIVERY_ASSIGNMENT_FORBIDDEN');
  const driver=await User.findOne({where:{id:targetId,restaurantId,isActive:true},include:[{model:Role,as:'roles',where:{slug:'delivery'},through:{attributes:[]},required:true}],transaction:t});
  if(!driver)throw fail('Active delivery staff member not found.',404,'DELIVERY_USER_NOT_FOUND');
  const branchMembership=await UserBranch.findOne({where:{userId:driver.id,branchId:order.branchId},transaction:t});
  if(!branchMembership)throw fail('Selected delivery staff member is not assigned to this order branch.',403,'DELIVERY_DRIVER_BRANCH_MISMATCH');
  let assignment=await DeliveryAssignment.findOne({where:{restaurantId,orderId:order.id},transaction:t,lock:t.LOCK.UPDATE});
  if(isWaiter&&assignment)throw fail('Waiters cannot reassign an order that already has a delivery rider.',403,'DELIVERY_REASSIGNMENT_FORBIDDEN');
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
async function unassigned(restaurantId,user,filters={}) {
 const where={restaurantId,orderType:'delivery',status:{[Op.in]:['placed','confirmed','preparing','ready']}};
 const isWaiter=(user.roles||[]).includes('waiter')&&!(user.roles||[]).includes('admin')&&!(user.roles||[]).includes('supervisor');
 if(isWaiter)where.createdByUserId=user.id;
 if(filters.branchId) {
  const branchId=id(filters.branchId);
  assertBranch(user,branchId);
  where.branchId=branchId;
 } else if(!(user.roles||[]).includes('admin')) {
  const branchIds=(user.branchIds||[]).map(Number).filter(n=>Number.isSafeInteger(n)&&n>0);
  where.branchId={[Op.in]:branchIds.length?branchIds:[-1]};
 }
 const existing=await DeliveryAssignment.findAll({where:{restaurantId},attributes:['orderId']});
 const assignedIds=existing.map(row=>Number(row.orderId));
 if(assignedIds.length)where.id={[Op.notIn]:assignedIds};
 const rows=await Order.findAll({where,attributes:['id','branchId','orderNumber','customerName','customerPhone','deliveryAddress','grandTotal','paymentMethod','paymentStatus','status','notes','placedAt'],order:[['placedAt','ASC']],limit:100});
 return rows.map(row=>row.toJSON());
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
    changes.codAmount=codDue.toFixed(2);changes.codCollected=true;changes.codCollectedAt=now;
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

function dateBounds(filters={}) {
 const valid=value=>{if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;const [y,m,d]=value.split('-').map(Number);const date=new Date(Date.UTC(y,m-1,d));return date.getUTCFullYear()===y&&date.getUTCMonth()===m-1&&date.getUTCDate()===d;};
 const from=filters.from||filters.startDate, to=filters.to||filters.endDate;
 if((from&&!valid(from))||(to&&!valid(to)))throw fail('Dates must use YYYY-MM-DD format.');
 if(from&&to&&from>to)throw fail('Start date cannot be after end date.');
 const start=from||to, end=to||from;
 if(!start)return null;
 return { [Op.gte]:new Date(start+'T00:00:00+05:00'), [Op.lt]:new Date(new Date(end+'T00:00:00+05:00').getTime()+86400000) };
}
async function history(restaurantId,user,filters={}) {
 const where={restaurantId};
 const canViewAll=(user.permissions||[]).includes('delivery.assignments.view_all');
 if(!canViewAll)where.deliveryUserId=id(user.id);
 else if(filters.riderId)where.deliveryUserId=id(filters.riderId);
 if(filters.branchId){const branchId=id(filters.branchId);assertBranch(user,branchId);where.branchId=branchId;}
 else if(!(user.roles||[]).includes('admin'))where.branchId={[Op.in]:(user.branchIds||[]).map(Number).filter(n=>n>0).length?(user.branchIds||[]).map(Number):[-1]};
 const bounds=dateBounds(filters);if(bounds)where.deliveredAt=bounds;
 return DeliveryAssignment.findAll({where,include:[{model:Order,as:'order',attributes:['id','orderNumber','customerName','customerPhone','deliveryAddress','grandTotal','deliveryFee','deliveryDistanceKm','paymentMethod','paymentStatus']},{model:User,as:'deliveryUser',attributes:['id','name','phone']}],order:[['deliveredAt','DESC']],limit:Math.min(Math.max(Number(filters.limit)||100,1),250)});
}
async function codCollections(restaurantId,user,filters={}) {
 const where={restaurantId,codCollected:true};
 if(!(user.permissions||[]).includes('delivery.assignments.view_all'))where.deliveryUserId=id(user.id);
 else if(filters.riderId)where.deliveryUserId=id(filters.riderId);
 if(filters.branchId){const branchId=id(filters.branchId);assertBranch(user,branchId);where.branchId=branchId;}
 else if(!(user.roles||[]).includes('admin'))where.branchId={[Op.in]:(user.branchIds||[]).map(Number).filter(n=>n>0).length?(user.branchIds||[]).map(Number):[-1]};
 const bounds=dateBounds(filters);if(bounds)where.codCollectedAt=bounds;
 const rows=await DeliveryAssignment.findAll({where,include:[{model:Order,as:'order',attributes:['id','orderNumber','customerName','grandTotal']},{model:User,as:'deliveryUser',attributes:['id','name']}],order:[['codCollectedAt','DESC']],limit:500});
 const byRider=new Map();let total=0;
 for(const row of rows){const rider=row.deliveryUser||{};const key=String(rider.id||row.deliveryUserId);const amount=Number(row.codAmount||0);total+=amount;const current=byRider.get(key)||{riderId:key,riderName:rider.name||'Delivery staff',orders:0,amount:0};current.orders++;current.amount+=amount;byRider.set(key,current);}
 return {dateFrom:filters.from||filters.startDate||null,dateTo:filters.to||filters.endDate||null,totalCollected:Number(total.toFixed(2)),orders:rows.length,byRider:[...byRider.values()].map(x=>({...x,amount:Number(x.amount.toFixed(2))})),items:rows};
}
async function analytics(restaurantId,user,filters={}) {
 const where={restaurantId};
 if(!(user.permissions||[]).includes('delivery.assignments.view_all'))where.deliveryUserId=id(user.id);
 else if(filters.riderId)where.deliveryUserId=id(filters.riderId);
 if(filters.branchId){const branchId=id(filters.branchId);assertBranch(user,branchId);where.branchId=branchId;}
 else if(!(user.roles||[]).includes('admin'))where.branchId={[Op.in]:(user.branchIds||[]).map(Number).filter(n=>n>0).length?(user.branchIds||[]).map(Number):[-1]};
 const bounds=dateBounds(filters);if(bounds)where.assignedAt=bounds;
 const rows=await DeliveryAssignment.findAll({where,attributes:['id','deliveryUserId','status','codAmount','codCollected','outForDeliveryAt','deliveredAt','assignedAt']});
 const delivered=rows.filter(x=>x.status==='delivered');const closed=rows.filter(x=>['delivered','cancelled'].includes(x.status));
 const durations=delivered.filter(x=>x.outForDeliveryAt&&x.deliveredAt).map(x=>(new Date(x.deliveredAt)-new Date(x.outForDeliveryAt))/60000).filter(x=>Number.isFinite(x)&&x>=0);
 const collected=rows.filter(x=>x.codCollected);
 const totalCod=collected.reduce((n,x)=>n+Number(x.codAmount||0),0);
 const byRider=new Map();
 for(const row of rows){const key=String(row.deliveryUserId);const x=byRider.get(key)||{riderId:key,total:0,delivered:0,cancelled:0,pending:0,codCollected:0,codAmount:0,durationTotal:0,durationCount:0};x.total++;if(row.status==='delivered')x.delivered++;else if(row.status==='cancelled')x.cancelled++;else x.pending++;if(row.codCollected){x.codCollected++;x.codAmount+=Number(row.codAmount||0);}if(row.outForDeliveryAt&&row.deliveredAt){const d=(new Date(row.deliveredAt)-new Date(row.outForDeliveryAt))/60000;if(Number.isFinite(d)&&d>=0){x.durationTotal+=d;x.durationCount++;}}byRider.set(key,x);}
 return {totalAssignments:rows.length,delivered:delivered.length,cancelled:rows.filter(x=>x.status==='cancelled').length,pending:rows.length-closed.length,deliverySuccessRate:rows.length?Number((delivered.length/rows.length*100).toFixed(1)):0,averageDeliveryMinutes:durations.length?Number((durations.reduce((a,b)=>a+b,0)/durations.length).toFixed(1)):null,codCollected:Number(totalCod.toFixed(2)),riders:[...byRider.values()].map(x=>({riderId:x.riderId,total:x.total,delivered:x.delivered,cancelled:x.cancelled,pending:x.pending,deliverySuccessRate:x.total?Number((x.delivered/x.total*100).toFixed(1)):0,codCollected:x.codCollected,codAmount:Number(x.codAmount.toFixed(2)),averageDeliveryMinutes:x.durationCount?Number((x.durationTotal/x.durationCount).toFixed(1)):null}))};
}

module.exports={assign,list,drivers,unassigned,updateStatus,history,codCollections,analytics};