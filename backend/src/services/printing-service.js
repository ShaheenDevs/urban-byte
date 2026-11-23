'use strict';
const {Op}=require('sequelize');
const {PrintJob,PrinterDevice,Order,OrderItem,Branch,RestaurantSetting,sequelize}=require('../models');
const {renderOrder}=require('./print-renderer');
function fail(message,status=400,code='PRINT_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
async function registerPrinter(restaurantId,input={}){
 const branch=await Branch.findOne({where:{id:Number(input.branchId),restaurantId,isActive:true}});
 if(!branch)throw fail('Branch not found.',404,'BRANCH_NOT_FOUND');
 if(!['network','usb','bluetooth','windows_bridge'].includes(input.connectionType))throw fail('Unsupported printer connection type.');
 if(!['58mm','80mm'].includes(input.paperWidth||'80mm'))throw fail('Paper width must be 58mm or 80mm.');
 return PrinterDevice.create({restaurantId,branchId:branch.id,name:String(input.name||'').trim().slice(0,120),connectionType:input.connectionType,paperWidth:input.paperWidth||'80mm',address:input.address?String(input.address).trim().slice(0,255):null,deviceIdentifier:input.deviceIdentifier?String(input.deviceIdentifier).trim().slice(0,255):null,purpose:input.purpose||'both'});
}
async function updatePrinter(restaurantId,printerId,input={}){
 const printer=await PrinterDevice.findOne({where:{id:Number(printerId),restaurantId,isActive:true}});
 if(!printer)throw fail('Printer not found.',404,'PRINTER_NOT_FOUND');
 const updates={};
 if(input.branchId!==undefined){const branch=await Branch.findOne({where:{id:Number(input.branchId),restaurantId,isActive:true}});if(!branch)throw fail('Branch not found.',404,'BRANCH_NOT_FOUND');updates.branchId=branch.id;}
 if(input.name!==undefined){const name=String(input.name).trim();if(!name)throw fail('Printer name is required.');updates.name=name.slice(0,120);}
 if(input.connectionType!==undefined){if(!['network','usb','bluetooth','windows_bridge'].includes(input.connectionType))throw fail('Unsupported printer connection type.');updates.connectionType=input.connectionType;}
 if(input.paperWidth!==undefined){if(!['58mm','80mm'].includes(input.paperWidth))throw fail('Paper width must be 58mm or 80mm.');updates.paperWidth=input.paperWidth;}
 if(input.purpose!==undefined){if(!['receipt','kitchen','both'].includes(input.purpose))throw fail('Invalid printer purpose.');updates.purpose=input.purpose;}
 if(input.address!==undefined)updates.address=input.address?String(input.address).trim().slice(0,255):null;
 if(input.deviceIdentifier!==undefined)updates.deviceIdentifier=input.deviceIdentifier?String(input.deviceIdentifier).trim().slice(0,255):null;
 await printer.update(updates);
 return printer;
}
async function deletePrinter(restaurantId,printerId){
 const printer=await PrinterDevice.findOne({where:{id:Number(printerId),restaurantId,isActive:true}});
 if(!printer)throw fail('Printer not found.',404,'PRINTER_NOT_FOUND');
 await printer.update({isActive:false});
 return {id:printer.id,deleted:true};
}
async function listPrinters(restaurantId,branchId){return PrinterDevice.findAll({where:{restaurantId,...(branchId?{branchId:Number(branchId)}:{}),isActive:true},order:[['createdAt','DESC']]});}
async function enqueue(restaurantId,user,orderId,jobType,input={}){
 if(!['receipt','kitchen_ticket'].includes(jobType))throw fail('Invalid print job type.');
 const order=await Order.findOne({where:{id:Number(orderId),restaurantId},include:[{model:OrderItem,as:'items'}]});
 if(!order)throw fail('Order not found.',404,'ORDER_NOT_FOUND');
 let printer=null;
 if(input.printerId){printer=await PrinterDevice.findOne({where:{id:Number(input.printerId),restaurantId,branchId:order.branchId,isActive:true}});if(!printer)throw fail('Printer not found for this branch.',404,'PRINTER_NOT_FOUND');}
 const paperWidth=printer?.paperWidth||input.paperWidth||'80mm';
 const plain=order.get({plain:true});
 const settings=await RestaurantSetting.findOne({where:{restaurantId}});
 const payload={orderId:order.id,orderNumber:order.orderNumber,jobType,paperWidth,items:plain.items,totals:{subtotal:plain.subtotal,discount:plain.discountAmount,tax:plain.taxAmount,delivery:plain.deliveryFee,total:plain.grandTotal}};
 return PrintJob.create({restaurantId,branchId:order.branchId,printerId:printer?.id||null,orderId:order.id,jobType,status:'queued',payload,renderedText:renderOrder(plain,jobType,paperWidth,settings?.get({plain:true})||{}),requestedByUserId:user.id});
}
async function enqueueTestPrint(restaurantId,user,printerId){
 const printer=await PrinterDevice.findOne({where:{id:Number(printerId),restaurantId,isActive:true}});
 if(!printer)throw fail('Printer not found.',404,'PRINTER_NOT_FOUND');
 const width=printer.paperWidth==='58mm'?32:48;
 const now=new Date().toLocaleString('en-PK',{timeZone:'Asia/Karachi'});
 const renderedText=['URBAN BYTE','PRINTER CONNECTION TEST','-'.repeat(width),'Connection: '+printer.connectionType.toUpperCase(),'Printer: '+printer.name,'Paper: '+printer.paperWidth,'Time: '+now,'-'.repeat(width),'If you can read this,','the local print bridge is working.','',''].join('\n');
 return PrintJob.create({restaurantId,branchId:printer.branchId,printerId:printer.id,orderId:null,jobType:'receipt',status:'queued',payload:{test:true,printerId:printer.id},renderedText,requestedByUserId:user.id});
}
async function listJobs(restaurantId,query={}){const where={restaurantId};if(query.branchId)where.branchId=Number(query.branchId);if(query.status)where.status=query.status;return PrintJob.findAll({where,order:[['createdAt','DESC']],limit:Math.min(Math.max(Number(query.limit)||50,1),100)});}
async function claimNext(restaurantId,branchId,printerId){
 return sequelize.transaction(async transaction=>{
  const where={restaurantId,branchId:Number(branchId),status:'queued',[Op.or]:[{printerId:null},{printerId:Number(printerId)}]};
  const job=await PrintJob.findOne({where,order:[['createdAt','ASC']],transaction,lock:transaction.LOCK.UPDATE,skipLocked:true});
  if(!job)return null;
  await job.update({status:'printing',attempts:job.attempts+1,lastError:null},{transaction});
  return job;
 });
}
async function updateStatus(restaurantId,jobId,input={}){
 const status=input.status;if(!['printed','failed'].includes(status))throw fail('Status must be printed or failed.');
 const job=await PrintJob.findOne({where:{id:Number(jobId),restaurantId}});
 if(!job)throw fail('Print job not found.',404,'PRINT_JOB_NOT_FOUND');
 if(job.status!=='printing')throw fail('Only a claimed print job can be completed.',409);
 await job.update({status,printedAt:status==='printed'?new Date():null,lastError:status==='failed'?String(input.error||'Printer bridge reported a failure.').slice(0,500):null});
 return job;
}
async function retry(restaurantId,jobId){
 const job=await PrintJob.findOne({where:{id:Number(jobId),restaurantId}});
 if(!job)throw fail('Print job not found.',404,'PRINT_JOB_NOT_FOUND');
 if(job.status!=='failed')throw fail('Only failed print jobs can be retried.',409);
 await job.update({status:'queued',lastError:null,printedAt:null});
 return job;
}
module.exports={registerPrinter,updatePrinter,deletePrinter,listPrinters,enqueue,enqueueTestPrint,listJobs,claimNext,updateStatus,retry};