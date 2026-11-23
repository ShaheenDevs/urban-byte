'use strict';
const crypto=require('node:crypto');
const {Order,OrderItem,OrderStatusHistory,Payment,KitchenTicket,KitchenTicketItem,Branch,Product,ProductVariant,BranchProductPrice,RestaurantSetting,sequelize}=require('../models');
const {transitions,validateTransition}=require('./order-lifecycle');
const inventoryService=require('./inventory-service');
const notifications=require('./notification-service');
async function notifySafely(restaurantId,keys,payload){try{await notifications.notifyPermissions(restaurantId,keys,payload);}catch(error){/* Notification delivery must never roll back a committed order. */}}
function error(message,status=400,code='VALIDATION_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
function numericId(value){const n=Number(value);if(!Number.isSafeInteger(n)||n<1)throw error('A valid positive ID is required.');return n;}
function amount(value,name){const n=Number(value);if(!Number.isFinite(n)||n<0||n>9999999999.99)throw error(name+' must be a non-negative amount.');return Math.round(n*100);}
function asMoney(paisa){return (paisa/100).toFixed(2);}
function canSeeAll(user){return user.permissions.includes('orders.view_all');}
async function getScopedOrder(restaurantId,orderId,user,transaction){const where={id:numericId(orderId),restaurantId};if(!canSeeAll(user))where.createdByUserId=numericId(user.id);const order=await Order.findOne({where,include:[{model:OrderItem,as:'items'},{model:OrderStatusHistory,as:'statusHistory'},{model:Payment,as:'payments'}],transaction});if(!order)throw error('Order not found.',404,'ORDER_NOT_FOUND');return order;}
async function createOrder(restaurantId,user,input,idempotencyKey,options={}){
 if(!input||!Array.isArray(input.items)||input.items.length<1||input.items.length>50)throw error('Provide between 1 and 50 order items.');
 const branchId=numericId(input.branchId);
 const settings = await RestaurantSetting.findOne({ where: { restaurantId } });
 const orderTypes = settings?.orderTypes || [{key:'dine_in',name:'Dine In'},{key:'takeaway',name:'Takeaway'},{key:'delivery',name:'Delivery'}];
 const selectedType = orderTypes.find((t) => t.key === input.orderType);
 if (!selectedType) throw error('This order type is not configured or is inactive.', 400, 'ORDER_TYPE_UNAVAILABLE');
 const isDineIn = input.orderType === 'dine_in';
 const isDelivery = input.orderType === 'delivery';
 if(isDineIn && (typeof input.tableLabel!=='string'||!input.tableLabel.trim()))throw error('A table must be selected for dine-in orders.');
 if(isDelivery && (typeof input.deliveryAddress!=='string'||!input.deliveryAddress.trim()))throw error('Delivery address is required.');
 const paymentMethod=input.paymentMethod??null;
 if(paymentMethod!==null&&!['cash','card','easypaisa','jazzcash','bank_transfer','cod'].includes(paymentMethod))throw error('Invalid payment method.');
 if(idempotencyKey!==undefined&&(typeof idempotencyKey!=='string'||idempotencyKey.length<8||idempotencyKey.length>100))throw error('Idempotency-Key must contain 8 to 100 characters.');
 const branch=await Branch.findOne({where:{id:branchId,restaurantId,isActive:true}});if(!branch)throw error('Branch not found for this restaurant.',404,'BRANCH_NOT_FOUND');
 if (isDineIn) {
  const table = (settings?.diningTables || []).find((t) => (t.id === String(input.tableLabel) || t.name === String(input.tableLabel)) && t.isActive !== false && (!t.branchId || Number(t.branchId) === branchId));
  if (!table) throw error('Selected dining table is not configured for this branch.', 400, 'TABLE_UNAVAILABLE');
  const occupied = await Order.findOne({where:{restaurantId,branchId,orderType:'dine_in',tableLabel:table.name,status:{[require('sequelize').Op.notIn]:['completed','cancelled']}},attributes:['id']});
  if (occupied) throw error('This table already has an active order.', 409, 'TABLE_OCCUPIED');
 }
 const prepared=[];let subtotalPaisa=0;
 for(const item of input.items){
  const variantId=numericId(item.variantId),quantity=Number(item.quantity);
  if(!Number.isFinite(quantity)||quantity<=0||quantity>999||Math.round(quantity*1000)!==quantity*1000)throw error('Each item quantity must be greater than zero with at most 3 decimal places.');
  const variant=await ProductVariant.findOne({where:{id:variantId,isActive:true},include:[{model:Product,as:'product',where:{restaurantId,isActive:true,isAvailable:true},required:true}]});
  if(!variant)throw error('An ordered product is unavailable.',409,'PRODUCT_UNAVAILABLE');
  const branchPrice=await BranchProductPrice.findOne({where:{branchId,variantId}});
  if(branchPrice&&!branchPrice.isAvailable)throw error('A product is not available at this branch.',409,'PRODUCT_UNAVAILABLE');
  const pricePaisa=amount(branchPrice?branchPrice.salePrice:variant.basePrice,'Product price');
  const linePaisa=Math.round(pricePaisa*quantity);subtotalPaisa+=linePaisa;
  if(!Number.isSafeInteger(subtotalPaisa)||subtotalPaisa>999999999999)throw error('Order total is too large.');
  prepared.push({productVariantId:variant.id,productName:variant.product.name,variantName:variant.name,skuSnapshot:variant.sku,quantity:quantity.toFixed(3),unitPrice:asMoney(pricePaisa),lineTotal:asMoney(linePaisa),notes:item.notes?String(item.notes).slice(0,500):null});
 }
 const discountPaisa = amount(input.discountAmount ?? 0, 'Discount');
 const maxDiscountPaisa = settings?.discountEnabled
   ? Math.floor(subtotalPaisa * Number(settings.maxDiscountPercent || 0) / 100)
   : 0;
 if (discountPaisa > 0 && (!settings?.discountEnabled || !user.permissions.some((p) => ['settings.manage', 'deals.manage'].includes(p)))) {
  throw error('You are not authorized to apply discounts.', 403, 'DISCOUNT_FORBIDDEN');
 }
 if (discountPaisa > maxDiscountPaisa || discountPaisa > subtotalPaisa) throw error('Discount exceeds the configured limit.', 400, 'DISCOUNT_LIMIT_EXCEEDED');
 const deliveryPaisa=0;
 const taxablePaisa=subtotalPaisa-discountPaisa;
 const taxRate=settings?.taxEnabled ? Number(settings.taxRate) : 0;
 const taxPaisa=taxRate > 0
   ? (settings.taxInclusive ? Math.round(taxablePaisa*taxRate/(100+taxRate)) : Math.round(taxablePaisa*taxRate/100))
   : 0;
 const grandPaisa=taxablePaisa + (settings?.taxEnabled && !settings.taxInclusive ? taxPaisa : 0) + deliveryPaisa;
 const orderNumber='UB-'+new Date().toISOString().slice(0,10).replace(/-/g,'')+'-'+crypto.randomBytes(3).toString('hex').toUpperCase();
 try{const created=await sequelize.transaction(async transaction=>{
  if(idempotencyKey){const existing=await Order.findOne({where:{restaurantId,idempotencyKey},include:[{model:OrderItem,as:'items'}],transaction,lock:transaction.LOCK.UPDATE});if(existing)return existing;}
  const order=await Order.create({restaurantId,branchId,orderNumber,idempotencyKey:idempotencyKey||null,createdByUserId:user.id,customerName:input.customerName?String(input.customerName).trim().slice(0,150):null,customerPhone:input.customerPhone?String(input.customerPhone).trim().slice(0,30):null,orderType:input.orderType,source:options.source==='ai'?'ai':'staff',tableLabel:isDineIn?((settings?.diningTables || []).find((t) => t.id === String(input.tableLabel) || t.name === String(input.tableLabel))?.name || input.tableLabel).trim().slice(0,40):null,deliveryAddress:input.orderType==='delivery'?input.deliveryAddress.trim():null,notes:input.notes?String(input.notes).slice(0,2000):null,status:'placed',paymentMethod,paymentStatus:'unpaid',subtotal:asMoney(subtotalPaisa),discountAmount:asMoney(discountPaisa),taxAmount:asMoney(taxPaisa),deliveryFee:asMoney(deliveryPaisa),grandTotal:asMoney(grandPaisa),placedAt:new Date()},{transaction});
  await OrderItem.bulkCreate(prepared.map(item=>({...item,orderId:order.id})),{transaction});
  await OrderStatusHistory.create({orderId:order.id,fromStatus:null,toStatus:'placed',changedByUserId:user.id,note:'Order created'},{transaction});
  return Order.findByPk(order.id,{include:[{model:OrderItem,as:'items'},{model:OrderStatusHistory,as:'statusHistory'}],transaction});
 });
 await notifySafely(restaurantId,['orders.view_all'],{type:'order.created',title:'New order received',body:'Order '+created.orderNumber+' has been placed.',data:{orderId:String(created.id),orderNumber:created.orderNumber,status:created.status}});
 try { const kitchenPrints = await require('./printing-service').enqueueKitchenForOrder(restaurantId,user,created.id); created.setDataValue('kitchenPrints', kitchenPrints.directPrints || []); } catch (printError) { created.setDataValue('kitchenPrintError', 'Kitchen print could not be prepared.'); }
 return created;}catch(e){if(e.name==='SequelizeUniqueConstraintError'&&idempotencyKey){const existing=await Order.findOne({where:{restaurantId,idempotencyKey},include:[{model:OrderItem,as:'items'},{model:Payment,as:'payments'}]});if(existing)return existing;}throw e;}
}
async function listOrders(restaurantId,user,filters={}){const where={restaurantId};if(!canSeeAll(user))where.createdByUserId=numericId(user.id);if(filters.branchId)where.branchId=numericId(filters.branchId);if(filters.status){if(!Object.hasOwn(transitions,filters.status))throw error('Invalid order status.');where.status=filters.status;}if(filters.statusGroup==='open')where.status={[require('sequelize').Op.in]:['placed','confirmed','preparing','ready','out_for_delivery']};if(filters.statusGroup==='completed')where.status='completed';if(filters.paymentStatus){if(!['unpaid','pending','paid','partially_paid','refunded'].includes(filters.paymentStatus))throw error('Invalid payment status.');where.paymentStatus=filters.paymentStatus;}if(filters.startDate||filters.endDate){const valid=(v)=>typeof v==='string'&&/^\\d{4}-\\d{2}-\\d{2}$/.test(v);if((filters.startDate&&!valid(filters.startDate))||(filters.endDate&&!valid(filters.endDate)))throw error('Dates must use YYYY-MM-DD format.');const from=filters.startDate||filters.endDate;const to=filters.endDate||filters.startDate;if(from>to)throw error('Start date cannot be after end date.');where.placedAt={[require('sequelize').Op.gte]:new Date(from+'T00:00:00+05:00'),[require('sequelize').Op.lt]:new Date(new Date(to+'T00:00:00+05:00').getTime()+86400000)};}if(filters.orderType){const settings=await RestaurantSetting.findOne({where:{restaurantId}});if(!(settings?.orderTypes||[{key:'dine_in'},{key:'takeaway'},{key:'delivery'}]).some((t)=>t.key===filters.orderType))throw error('Invalid order type.');where.orderType=filters.orderType;}const limit=Math.min(Math.max(Number(filters.limit)||25,1),100),offset=Math.max(Number(filters.offset)||0,0);const result=await Order.findAndCountAll({where,include:[{model:OrderItem,as:'items'},{model:Payment,as:'payments'}],order:[['createdAt','DESC']],limit,offset,distinct:true});return {items:result.rows,total:result.count,limit,offset};}
async function getOrder(restaurantId,orderId,user){return getScopedOrder(restaurantId,orderId,user);}
async function updateStatus(restaurantId,orderId,user,input){const result=await sequelize.transaction(async transaction=>{const next=input.status;if(!Object.hasOwn(transitions,next))throw error('Invalid target status.');const where={id:numericId(orderId),restaurantId};if(!canSeeAll(user))where.createdByUserId=numericId(user.id);const order=await Order.findOne({where,transaction,lock:transaction.LOCK.UPDATE});if(!order)throw error('Order not found.',404,'ORDER_NOT_FOUND');validateTransition(order.status,next);const previous=order.status,now=new Date(),changes={status:next};if(next==='completed')changes.completedAt=now;if(next==='cancelled'){if(order.paymentStatus==='paid')throw error('A paid order must be refunded through the payment workflow before cancellation.',409,'REFUND_REQUIRED');changes.cancelledAt=now;changes.cancelReason=input.reason?String(input.reason).slice(0,500):null;}await order.update(changes,{transaction});if(next==='completed')await inventoryService.deductOrderStock(order,transaction);await OrderStatusHistory.create({orderId:order.id,fromStatus:previous,toStatus:next,changedByUserId:user.id,note:input.note?String(input.note).slice(0,500):(changes.cancelReason||null)},{transaction});if(['confirmed','preparing','ready'].includes(next)){let ticket=await KitchenTicket.findOne({where:{orderId:order.id},transaction,lock:transaction.LOCK.UPDATE});if(!ticket){ticket=await KitchenTicket.create({restaurantId,branchId:order.branchId,orderId:order.id,ticketNumber:'KT-'+order.orderNumber,status:'pending'},{transaction});const orderItems=await OrderItem.findAll({where:{orderId:order.id},transaction});await KitchenTicketItem.bulkCreate(orderItems.map(i=>({ticketId:ticket.id,orderItemId:i.id,productName:i.productName,variantName:i.variantName,quantity:i.quantity,notes:i.notes,status:'pending'})),{transaction});}if(next==='preparing'||next==='ready'){await ticket.update({status:next},{transaction});await KitchenTicketItem.update({status:next},{where:{ticketId:ticket.id},transaction});}}if(next==='cancelled'){await KitchenTicket.update({status:'cancelled'},{where:{orderId:order.id},transaction});}return Order.findByPk(order.id,{include:[{model:OrderItem,as:'items'},{model:OrderStatusHistory,as:'statusHistory'}],transaction});});
 const targets=result.status==='confirmed'?['kitchen.orders.view']:result.status==='ready'?['orders.view_all']:['orders.view_all'];
 await notifySafely(restaurantId,targets,{type:'order.status',title:'Order '+result.status,body:'Order '+result.orderNumber+' is now '+result.status+'.',data:{orderId:String(result.id),orderNumber:result.orderNumber,status:result.status}});
 return result;}
module.exports={createOrder,listOrders,getOrder,updateStatus};
