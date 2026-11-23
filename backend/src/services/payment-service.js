'use strict';
const {Op}=require('sequelize');
const {Payment,PaymentEvent,Order,sequelize}=require('../models');
function fail(message,status=400,code='PAYMENT_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
function money(value){const n=Number(value);if(!Number.isFinite(n)||n<=0||n>9999999999.99)throw fail('Payment amount must be greater than zero.');return n.toFixed(2);}
async function record(restaurantId,user,input={}){
 const method=input.method;
 if(!['cash','card','easypaisa','jazzcash','bank_transfer','cod'].includes(method))throw fail('Unsupported payment method.');
 const amount=money(input.amount);
 return sequelize.transaction(async transaction=>{
  const order=await Order.findOne({where:{id:Number(input.orderId),restaurantId},transaction,lock:transaction.LOCK.UPDATE});
  if(!order)throw fail('Order not found.',404,'ORDER_NOT_FOUND');
  if(order.paymentStatus==='paid'||order.paymentStatus==='refunded')throw fail('This order cannot accept another payment.',409);
  if(Number(amount)>Number(order.grandTotal))throw fail('Payment cannot exceed the outstanding order total.');
  const markReceived = input.markReceived === true && user.permissions.includes('payments.record');
  const committed = Number(await Payment.sum('amount', {
   where: { orderId: order.id, restaurantId, status: { [Op.in]: ['pending', 'verified'] } }, transaction
  }) || 0);
  if (committed + Number(amount) > Number(order.grandTotal)) throw fail('Payment exceeds the remaining balance.', 409, 'PAYMENT_EXCEEDS_BALANCE');
  const payment=await Payment.create({restaurantId,branchId:order.branchId,orderId:order.id,method,status:markReceived?'verified':'pending',amount,reference:input.reference?String(input.reference).trim().slice(0,120):null,recordedByUserId:user.id,verifiedByUserId:markReceived?user.id:null,verifiedAt:markReceived?new Date():null,notes:input.notes?String(input.notes).slice(0,500):null},{transaction});
  await PaymentEvent.create({paymentId:payment.id,eventType:'recorded',actorUserId:user.id,notes:markReceived?'Payment received and confirmed by POS operator.':'Payment recorded; awaiting verification.'},{transaction});
  if(markReceived) await PaymentEvent.create({paymentId:payment.id,eventType:'verified',actorUserId:user.id,notes:'Payment marked received at POS.'},{transaction});
  const alreadyPaid = Number(await Payment.sum('amount',{where:{orderId:order.id,restaurantId,status:'verified'},transaction}) || 0);
  if(alreadyPaid >= Number(order.grandTotal)) await order.update({paymentStatus:'paid',paymentMethod:method},{transaction});
  else await order.update({paymentStatus:'pending',paymentMethod:method},{transaction});
  return payment;
 });
}
async function verify(restaurantId,user,paymentId){
 return sequelize.transaction(async transaction=>{
  const payment=await Payment.findOne({where:{id:Number(paymentId),restaurantId},transaction,lock:transaction.LOCK.UPDATE});
  if(!payment)throw fail('Payment not found.',404,'PAYMENT_NOT_FOUND');
  if(payment.status!=='pending')throw fail('Only pending payments can be verified.',409);
  const order=await Order.findOne({where:{id:payment.orderId,restaurantId},transaction,lock:transaction.LOCK.UPDATE});
  if(!order)throw fail('Order not found.',404);
  const alreadyPaid=await Payment.sum('amount',{where:{orderId:order.id,restaurantId,status:'verified'},transaction})||0;
  if(Number(alreadyPaid)+Number(payment.amount)>Number(order.grandTotal))throw fail('Verified payments would exceed the order total.',409);
  const now=new Date();
  await payment.update({status:'verified',verifiedByUserId:user.id,verifiedAt:now},{transaction});
  await PaymentEvent.create({paymentId:payment.id,eventType:'verified',actorUserId:user.id},{transaction});
  const paidTotal=Number(alreadyPaid)+Number(payment.amount);
  if(paidTotal>=Number(order.grandTotal))await order.update({paymentStatus:'paid',paymentMethod:payment.method},{transaction});
  else await order.update({paymentStatus:'pending'},{transaction});
  return payment;
 });
}
async function list(restaurantId,query={}){
 const where={restaurantId};if(query.branchId)where.branchId=Number(query.branchId);if(query.status)where.status=query.status;
 return Payment.findAll({where,order:[['createdAt','DESC']],limit:Math.min(Math.max(Number(query.limit)||50,1),100)});
}
async function dailySummary(restaurantId,query={}){
 const start=query.date?new Date(query.date+'T00:00:00.000Z'):new Date(new Date().toISOString().slice(0,10)+'T00:00:00.000Z');
 if(Number.isNaN(start.getTime()))throw fail('Invalid date.');
 const end=new Date(start.getTime()+86400000);
 const where={restaurantId,status:'verified',verifiedAt:{[Op.gte]:start,[Op.lt]:end}};
 if(query.branchId)where.branchId=Number(query.branchId);
 const rows=await Payment.findAll({where,attributes:['method','amount']});
 const totals={cash:0,card:0,easypaisa:0,jazzcash:0,bank_transfer:0,cod:0};
 for(const row of rows)totals[row.method]+=Number(row.amount);
 return {date:start.toISOString().slice(0,10),currency:'PKR',verifiedPayments:rows.length,totals,total:Object.values(totals).reduce((a,b)=>a+b,0).toFixed(2)};
}
module.exports={record,verify,list,dailySummary};