'use strict';
const {Op}=require('sequelize');
const {CashShift,CashShiftEntry,Payment,sequelize}=require('../models');
function fail(message,status=400,code='CASH_SHIFT_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
function amount(value){const n=Number(value);if(!Number.isFinite(n)||n<0||n>9999999999.99)throw fail('Amount must be a valid non-negative value.');return n.toFixed(2);}
async function open(restaurantId,user,input={}){
 const branchId=Number(input.branchId);if(!Number.isSafeInteger(branchId)||branchId<1)throw fail('A valid branchId is required.');
 const openingCash=amount(input.openingCash);
 return sequelize.transaction(async transaction=>{
  const existing=await CashShift.findOne({where:{restaurantId,branchId,status:'open'},transaction,lock:transaction.LOCK.UPDATE});
  if(existing)throw fail('This branch already has an open cash shift.',409,'SHIFT_ALREADY_OPEN');
  return CashShift.create({restaurantId,branchId,openedByUserId:user.id,openingCash,status:'open',openedAt:new Date()},{transaction});
 });
}
async function addEntry(restaurantId,user,shiftId,input={}){
 const value=Number(input.amount);if(!Number.isFinite(value)||value<=0)throw fail('Entry amount must be greater than zero.');
 const type=input.entryType;if(!['cash_in','cash_out','expense'].includes(type))throw fail('Unsupported cash entry type.');
 return sequelize.transaction(async transaction=>{
  const shift=await CashShift.findOne({where:{id:Number(shiftId),restaurantId,status:'open'},transaction,lock:transaction.LOCK.UPDATE});
  if(!shift)throw fail('Open cash shift not found.',404,'SHIFT_NOT_FOUND');
  return CashShiftEntry.create({shiftId:shift.id,entryType:type,amount:amount(value),description:String(input.description||'').trim().slice(0,250)||'Cash movement',reference:input.reference?String(input.reference).trim().slice(0,100):null,recordedByUserId:user.id},{transaction});
 });
}
async function totals(shift,transaction){
 const cashPayments=await Payment.sum('amount',{where:{restaurantId:shift.restaurantId,branchId:shift.branchId,method:'cash',status:'verified',verifiedAt:{[Op.gte]:shift.openedAt,[Op.lte]:shift.closedAt||new Date()}},transaction})||0;
 const entries=await CashShiftEntry.findAll({where:{shiftId:shift.id},transaction});
 let cashIn=0,cashOut=0,expenses=0;
 for(const e of entries){const n=Number(e.amount);if(e.entryType==='cash_in')cashIn+=n;else if(e.entryType==='cash_out')cashOut+=n;else expenses+=n;}
 const expected=Number(shift.openingCash)+Number(cashPayments)+cashIn-cashOut-expenses;
 return {openingCash:Number(shift.openingCash),verifiedCashPayments:Number(cashPayments),cashIn,cashOut,expenses,expectedCash:Number(expected.toFixed(2))};
}
async function close(restaurantId,user,shiftId,input={}){
 const actual=Number(input.actualCash);if(!Number.isFinite(actual)||actual<0)throw fail('Actual cash must be zero or greater.');
 return sequelize.transaction(async transaction=>{
  const shift=await CashShift.findOne({where:{id:Number(shiftId),restaurantId,status:'open'},transaction,lock:transaction.LOCK.UPDATE});
  if(!shift)throw fail('Open cash shift not found.',404,'SHIFT_NOT_FOUND');
  shift.closedAt=new Date();
  const summary=await totals(shift,transaction);
  shift.expectedCash=summary.expectedCash.toFixed(2);shift.actualCash=amount(actual);
  shift.cashVariance=(actual-summary.expectedCash).toFixed(2);
  shift.closedByUserId=user.id;shift.status='closed';shift.closingNotes=input.notes?String(input.notes).trim().slice(0,500):null;
  await shift.save({transaction});
  return {shift,summary,actualCash:actual,cashVariance:Number(shift.cashVariance)};
 });
}
async function current(restaurantId,query={}){
 const where={restaurantId,status:'open'};if(query.branchId)where.branchId=Number(query.branchId);
 return CashShift.findAll({where,order:[['openedAt','DESC']],limit:50});
}
async function report(restaurantId,shiftId){
 const shift=await CashShift.findOne({where:{id:Number(shiftId),restaurantId}});if(!shift)throw fail('Cash shift not found.',404);
 const summary=await totals(shift);const entries=await CashShiftEntry.findAll({where:{shiftId:shift.id},order:[['createdAt','ASC']]});
 return {shift,summary,entries};
}
module.exports={open,addEntry,close,current,report};