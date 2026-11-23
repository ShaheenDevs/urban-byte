'use strict';
const crypto=require('node:crypto');
const {calculateRecipeConsumption,calculateBalance}=require('./inventory-math');
const {InventoryItem,BranchStock,StockMovement,Branch,Supplier,Purchase,PurchaseItem,PurchasePayment,Recipe,RecipeItem,ProductVariant,Product,AuditLog,sequelize}=require('../models');

async function recordAudit(transaction, restaurantId, userId, branchId, entityType, entityId, action, beforeData, afterData, metadata = {}) {
 await AuditLog.create({
  restaurantId, branchId, actorUserId:userId, entityType, entityId:String(entityId), action,
  beforeData:beforeData||null, afterData:afterData||null, metadata,
 }, {transaction});
}

function fail(message,status=400,code='VALIDATION_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
function id(value){const n=Number(value);if(!Number.isSafeInteger(n)||n<1)throw fail('A valid positive ID is required.');return n;}
function quantity(value,name='Quantity'){const n=Number(value);if(!Number.isFinite(n)||n<=0||n>999999999||Math.round(n*1000)!==n*1000)throw fail(name+' must be positive with at most 3 decimal places.');return n;}
function nonNegativeQuantity(value,name='Quantity'){const n=Number(value);if(!Number.isFinite(n)||n<0||n>999999999||Math.round(n*1000)!==n*1000)throw fail(name+' must be non-negative with at most 3 decimal places.');return n;}
function money(value,name='Cost'){const n=Number(value);if(!Number.isFinite(n)||n<0||n>9999999999.99)throw fail(name+' must be a non-negative amount.');return Math.round(n*100)/100;}
function assertBranch(user,branchId){if(!user||(user.roles||[]).includes('admin'))return;const allowed=(user.branchIds||[]).map(Number);if(!allowed.includes(Number(branchId)))throw fail('You are not assigned to this branch.',403,'BRANCH_FORBIDDEN');}
function branchFilter(user,requested){if(!user||(user.roles||[]).includes('admin'))return requested?{branchId:id(requested)}:{};const allowed=(user.branchIds||[]).map(Number).filter(n=>Number.isSafeInteger(n)&&n>0);if(requested){assertBranch(user,id(requested));return {branchId:id(requested)};}return {branchId:{[require('sequelize').Op.in]:allowed.length?allowed:[-1]}};}
async function branchFor(restaurantId,branchId,transaction,user){assertBranch(user,branchId);const b=await Branch.findOne({where:{id:id(branchId),restaurantId,isActive:true},transaction,lock:transaction?.LOCK.UPDATE});if(!b)throw fail('Branch not found.',404,'BRANCH_NOT_FOUND');return b;}
async function createItem(restaurantId,input){if(!input||typeof input.name!=='string'||!input.name.trim())throw fail('Item name is required.');if(!['ingredient','finished_good','packaging','other'].includes(input.itemType))throw fail('Invalid itemType.');if(typeof input.unit!=='string'||!input.unit.trim())throw fail('Unit is required.');return InventoryItem.create({restaurantId,name:input.name.trim().slice(0,160),sku:input.sku?String(input.sku).trim().slice(0,80):null,itemType:input.itemType,baseUnit:input.unit.trim().slice(0,20),lowStockThreshold:nonNegativeQuantity(input.lowStockThreshold??0,'Low-stock threshold'),isActive:true});}
async function listBranches(restaurantId,user){return Branch.findAll({where:{restaurantId,isActive:true,...(user&&!((user.roles||[]).includes('admin'))?{id:{[require('sequelize').Op.in]:(user.branchIds||[]).map(Number).filter(n=>n>0).length?(user.branchIds||[]).map(Number).filter(n=>n>0):[-1]}}:{})},attributes:['id','name','code'],order:[['name','ASC']]});}
async function listItems(restaurantId){return InventoryItem.findAll({where:{restaurantId,isActive:true},order:[['name','ASC']]});}
async function listStock(restaurantId,branchId,user){await branchFor(restaurantId,branchId,undefined,user);const stocks=await BranchStock.findAll({where:{branchId:id(branchId)},order:[['id','ASC']]});const items=await InventoryItem.findAll({where:{restaurantId},order:[['name','ASC']]});const byId=new Map(items.map(x=>[String(x.id),x]));return stocks.map(s=>({stock:s,item:byId.get(String(s.inventoryItemId))||null,lowStock:Number(s.quantity)<=Number(s.reorderLevel)}));}
async function adjustStock(restaurantId,user,input){const branchId=id(input.branchId);assertBranch(user,branchId);const itemId=id(input.inventoryItemId),delta=Number(input.quantityChange);if(!Number.isFinite(delta)||delta===0||Math.abs(delta)>999999999||Math.round(delta*1000)!==delta*1000)throw fail('quantityChange must be non-zero with at most 3 decimal places.');const movementType=input.movementType||'adjustment';if(!['waste','adjustment','return'].includes(movementType))throw fail('Invalid adjustment movement type.');return sequelize.transaction(async t=>{await branchFor(restaurantId,branchId,t);const item=await InventoryItem.findOne({where:{id:itemId,restaurantId,isActive:true},transaction:t});if(!item)throw fail('Inventory item not found.',404,'ITEM_NOT_FOUND');let stock=await BranchStock.findOne({where:{branchId,inventoryItemId:itemId},transaction:t,lock:t.LOCK.UPDATE});if(!stock)stock=await BranchStock.create({branchId,inventoryItemId:itemId,quantity:0,reorderLevel:Number(item.lowStockThreshold||0)},{transaction:t});let after;try{after=calculateBalance(stock.quantity,delta);}catch(e){throw fail(e.message,409,e.code||'INVALID_STOCK');}await stock.update({quantity:after},{transaction:t});const movement=await StockMovement.create({restaurantId,branchId,inventoryItemId:itemId,movementType,quantityChange:delta,quantityAfter:after,referenceType:'manual_adjustment',note:input.note?String(input.note).slice(0,500):null,createdByUserId:user.id},{transaction:t});await recordAudit(t,restaurantId,user.id,branchId,'inventory_stock',itemId,'inventory.stock_adjusted',{quantity:Number(stock.quantity)-delta},{quantity:after,movementType,quantityChange:delta,note:input.note||null});return {stock,movement};});}
async function movements(restaurantId,user,filters={}){const where={restaurantId,...branchFilter(user,filters.branchId)};if(filters.inventoryItemId)where.inventoryItemId=id(filters.inventoryItemId);const limit=Math.min(Math.max(Number(filters.limit)||50,1),100);return StockMovement.findAll({where,order:[['createdAt','DESC']],limit});}

async function createSupplier(restaurantId,input){if(!input||typeof input.name!=='string'||!input.name.trim())throw fail('Supplier name is required.');const supplier=await Supplier.create({restaurantId,name:input.name.trim().slice(0,160),phone:input.phone?String(input.phone).trim().slice(0,30):null,notes:input.notes?String(input.notes).trim().slice(0,500):null,isActive:true});await AuditLog.create({restaurantId,actorUserId:input.createdByUserId||null,entityType:'supplier',entityId:String(supplier.id),action:'supplier.created',metadata:{name:supplier.name}});return supplier;}
async function listSuppliers(restaurantId){return Supplier.findAll({where:{restaurantId,isActive:true},order:[['name','ASC']]});}
async function setReorderLevel(restaurantId,user,input){const branchId=id(input.branchId);assertBranch(user,branchId);const itemId=id(input.inventoryItemId),level=Number(input.reorderLevel);if(!Number.isFinite(level)||level<0||level>999999999||Math.round(level*1000)!==level*1000)throw fail('reorderLevel must be non-negative with at most 3 decimal places.');return sequelize.transaction(async t=>{await branchFor(restaurantId,branchId,t);const item=await InventoryItem.findOne({where:{id:itemId,restaurantId,isActive:true},transaction:t});if(!item)throw fail('Inventory item not found.',404,'ITEM_NOT_FOUND');let stock=await BranchStock.findOne({where:{branchId,inventoryItemId:itemId},transaction:t,lock:t.LOCK.UPDATE});if(!stock)stock=await BranchStock.create({branchId,inventoryItemId:itemId,quantity:0,reorderLevel:level},{transaction:t});else await stock.update({reorderLevel:level},{transaction:t});return stock;});}
async function lowStock(restaurantId,branchId,user){const rows=await listStock(restaurantId,branchId,user);return rows.filter(row=>row.lowStock);}

async function setBranchAutoDeduct(restaurantId,user,branchId,enabled){assertBranch(user,branchId);if(typeof enabled!=='boolean')throw fail('enabled must be a boolean.');return sequelize.transaction(async t=>{const branch=await branchFor(restaurantId,branchId,t);if(enabled){const variants=await ProductVariant.findAll({where:{isActive:true},include:[{model:Product,as:'product',where:{restaurantId,isActive:true,isAvailable:true,productType:['prepared','retail']},required:true}],transaction:t});if(!variants.length)throw fail('No active prepared products were found. Configure the menu before enabling stock deduction.',409,'NO_PREPARED_PRODUCTS');const recipes=await Recipe.findAll({where:{restaurantId,isActive:true},include:[{model:RecipeItem,as:'items'}],transaction:t});const byVariant=new Map(recipes.map(r=>[String(r.productVariantId),r]));const missing=variants.filter(v=>!byVariant.has(String(v.id))||!byVariant.get(String(v.id)).items.length);if(missing.length)throw fail('Configure a complete recipe for every active prepared product before enabling auto deduction: '+missing.map(v=>v.name).join(', '),409,'RECIPES_INCOMPLETE');}await branch.update({inventoryAutoDeduct:enabled},{transaction:t});return branch;});}
async function createPurchase(restaurantId,user,input){if(!Array.isArray(input.items)||!input.items.length||input.items.length>100)throw fail('A purchase requires 1 to 100 items.');const branchId=id(input.branchId);assertBranch(user,branchId);await branchFor(restaurantId,branchId);if(input.supplierId){const supplier=await Supplier.findOne({where:{id:id(input.supplierId),restaurantId,isActive:true}});if(!supplier)throw fail('Supplier not found.',404,'SUPPLIER_NOT_FOUND');}const prepared=[];let total=0;for(const line of input.items){const inventoryItemId=id(line.inventoryItemId),qty=quantity(line.quantity),unitCost=money(line.unitCost);const item=await InventoryItem.findOne({where:{id:inventoryItemId,restaurantId,isActive:true}});if(!item)throw fail('Purchase contains an unknown inventory item.',404,'ITEM_NOT_FOUND');const lineTotal=Math.round(qty*unitCost*100)/100;total=Math.round((total+lineTotal)*100)/100;prepared.push({inventoryItemId,quantity:qty,unitCost:unitCost.toFixed(2),lineTotal:lineTotal.toFixed(2)});}return sequelize.transaction(async t=>{const purchase=await Purchase.create({restaurantId,branchId,supplierId:input.supplierId?id(input.supplierId):null,purchaseNumber:'PUR-'+Date.now()+'-'+crypto.randomBytes(2).toString('hex').toUpperCase(),status:'draft',totalCost:total.toFixed(2),createdByUserId:user.id},{transaction:t});await PurchaseItem.bulkCreate(prepared.map(x=>({...x,purchaseId:purchase.id})),{transaction:t});await recordAudit(t,restaurantId,user.id,branchId,'purchase',purchase.id,'purchase.created',null,{purchaseNumber:purchase.purchaseNumber,status:purchase.status,totalCost:purchase.totalCost,supplierId:purchase.supplierId,itemCount:prepared.length});return Purchase.findByPk(purchase.id,{include:[{model:PurchaseItem,as:'items'}],transaction:t});});}
async function receivePurchase(restaurantId,user,purchaseId){return sequelize.transaction(async t=>{const purchase=await Purchase.findOne({where:{id:id(purchaseId),restaurantId},include:[{model:PurchaseItem,as:'items'}],transaction:t,lock:t.LOCK.UPDATE});if(!purchase)throw fail('Purchase not found.',404,'PURCHASE_NOT_FOUND');if(purchase.status!=='draft')throw fail('Only draft purchases can be received.',409,'PURCHASE_NOT_RECEIVABLE');assertBranch(user,purchase.branchId);await branchFor(restaurantId,purchase.branchId,t);for(const line of purchase.items){let stock=await BranchStock.findOne({where:{branchId:purchase.branchId,inventoryItemId:line.inventoryItemId},transaction:t,lock:t.LOCK.UPDATE});if(!stock){const item=await InventoryItem.findOne({where:{id:line.inventoryItemId,restaurantId},transaction:t});stock=await BranchStock.create({branchId:purchase.branchId,inventoryItemId:line.inventoryItemId,quantity:0,reorderLevel:Number(item.lowStockThreshold||0)},{transaction:t});}const after=calculateBalance(stock.quantity,Number(line.quantity));await stock.update({quantity:after},{transaction:t});await StockMovement.create({restaurantId,branchId:purchase.branchId,inventoryItemId:line.inventoryItemId,movementType:'purchase',quantityChange:line.quantity,quantityAfter:after,unitCost:line.unitCost,referenceType:'purchase',referenceId:purchase.id,note:'Purchase received',createdByUserId:user.id},{transaction:t});}const before={status:purchase.status,receivedAt:purchase.receivedAt,totalCost:purchase.totalCost};await purchase.update({status:'received',receivedAt:new Date()},{transaction:t});await recordAudit(t,restaurantId,user.id,purchase.branchId,'purchase',purchase.id,'purchase.received',before,{status:purchase.status,receivedAt:purchase.receivedAt,totalCost:purchase.totalCost,itemCount:purchase.items.length});return purchase;});}
async function listPurchases(restaurantId,user){return Purchase.findAll({where:{restaurantId,...branchFilter(user)},include:[{model:PurchaseItem,as:'items'}],order:[['createdAt','DESC']],limit:100});}

async function purchaseAnalytics(restaurantId,user,query={}){
 const from=query.from||new Date().toISOString().slice(0,10),to=query.to||from;
 const valid=v=>/^\d{4}-\d{2}-\d{2}$/.test(v)&&!Number.isNaN(Date.parse(v+'T00:00:00Z'))&&new Date(v+'T00:00:00Z').toISOString().slice(0,10)===v;
 if(!valid(from)||!valid(to)||from>to)throw fail('Use valid from/to dates in YYYY-MM-DD format.');
 const start=new Date(new Date(from+'T00:00:00Z').getTime()-5*60*60*1000);
 const end=new Date(new Date(to+'T00:00:00Z').getTime()-5*60*60*1000+86400000);
 const where={restaurantId,status:'received',receivedAt:{[require('sequelize').Op.gte]:start,[require('sequelize').Op.lt]:end},...branchFilter(user,query.branchId)};
 const purchases=await Purchase.findAll({where,include:[{model:PurchaseItem,as:'items'}],order:[['receivedAt','ASC']],limit:5000});
 const ids=purchases.map(p=>p.id);
 const paymentRows=ids.length?await PurchasePayment.findAll({where:{restaurantId,purchaseId:{[require('sequelize').Op.in]:ids}},raw:true}):[];
 const paidByPurchase=new Map();
 for(const p of paymentRows)paidByPurchase.set(String(p.purchaseId),(paidByPurchase.get(String(p.purchaseId))||0)+Number(p.amount));
 const branchIds=[...new Set(purchases.map(p=>Number(p.branchId)))];
 const supplierIds=[...new Set(purchases.map(p=>Number(p.supplierId)).filter(n=>n>0))];
 const [branches,suppliers]=await Promise.all([
  branchIds.length?Branch.findAll({where:{restaurantId,id:branchIds},attributes:['id','name','code'],raw:true}):[],
  supplierIds.length?Supplier.findAll({where:{restaurantId,id:supplierIds},attributes:['id','name'],raw:true}):[],
 ]);
 const branchById=new Map(branches.map(x=>[Number(x.id),x]));
 const supplierById=new Map(suppliers.map(x=>[Number(x.id),x]));
 const branchMap=new Map(),supplierMap=new Map(),itemMap=new Map(),dailyMap=new Map(),branchItemMap=new Map();
 let purchaseTotal=0,paidTotal=0;
 for(const p of purchases){
  const total=Number(p.totalCost),paid=Math.min(total,paidByPurchase.get(String(p.id))||0),due=Math.max(0,total-paid);
  purchaseTotal+=total;paidTotal+=paid;
  const b=branchMap.get(Number(p.branchId))||{branchId:Number(p.branchId),branchName:branchById.get(Number(p.branchId))?.name||'Branch',purchaseCount:0,total:0,paid:0,outstanding:0};
  b.purchaseCount++;b.total+=total;b.paid+=paid;b.outstanding+=due;branchMap.set(Number(p.branchId),b);
  const sid=Number(p.supplierId)||0;
  const su=supplierMap.get(sid)||{supplierId:sid||null,supplierName:supplierById.get(sid)?.name||'Unassigned supplier',purchaseCount:0,total:0,paid:0,outstanding:0};
  su.purchaseCount++;su.total+=total;su.paid+=paid;su.outstanding+=due;supplierMap.set(sid,su);
  const day=new Date(new Date(p.receivedAt).getTime()+5*60*60*1000).toISOString().slice(0,10);
  const d=dailyMap.get(day)||{date:day,purchaseCount:0,total:0};d.purchaseCount++;d.total+=total;dailyMap.set(day,d);
  for(const line of p.items||[]){
   const key=String(line.inventoryItemId),it=itemMap.get(key)||{inventoryItemId:Number(line.inventoryItemId),quantity:0,totalCost:0,receivingLines:0};
   it.quantity+=Number(line.quantity);it.totalCost+=Number(line.lineTotal);it.receivingLines++;itemMap.set(key,it);
   const pairKey=String(p.branchId)+':'+key,pair=branchItemMap.get(pairKey)||{branchId:Number(p.branchId),inventoryItemId:Number(line.inventoryItemId),quantity:0,totalCost:0,receivingLines:0};pair.quantity+=Number(line.quantity);pair.totalCost+=Number(line.lineTotal);pair.receivingLines++;branchItemMap.set(pairKey,pair);
  }
 }
 const itemIds=[...itemMap.values()].map(x=>x.inventoryItemId);
 const inventoryItems=itemIds.length?await InventoryItem.findAll({where:{restaurantId,id:itemIds},attributes:['id','name','baseUnit'],raw:true}):[];
 const itemById=new Map(inventoryItems.map(x=>[Number(x.id),x]));
 const format=row=>({...row,total:Number(row.total.toFixed(2)),paid:Number(row.paid.toFixed(2)),outstanding:Number(row.outstanding.toFixed(2))});
 const branchRows=[...branchMap.values()].map(format).sort((a,b)=>b.total-a.total);
 const supplierRows=[...supplierMap.values()].map(format).sort((a,b)=>b.outstanding-a.outstanding);
 const itemRows=[...itemMap.values()].map(x=>({inventoryItemId:x.inventoryItemId,name:itemById.get(x.inventoryItemId)?.name||'Inventory item',unit:itemById.get(x.inventoryItemId)?.baseUnit||null,quantity:Number(x.quantity.toFixed(3)),totalCost:Number(x.totalCost.toFixed(2)),averageUnitCost:x.quantity?Number((x.totalCost/x.quantity).toFixed(2)):null,receivingLines:x.receivingLines})).sort((a,b)=>b.totalCost-a.totalCost);
 const branchItemRows=[...branchItemMap.values()].map(x=>({branchId:x.branchId,branchName:branchById.get(x.branchId)?.name||'Branch',inventoryItemId:x.inventoryItemId,itemName:itemById.get(x.inventoryItemId)?.name||'Inventory item',unit:itemById.get(x.inventoryItemId)?.baseUnit||null,quantity:Number(x.quantity.toFixed(3)),totalCost:Number(x.totalCost.toFixed(2)),averageUnitCost:x.quantity?Number((x.totalCost/x.quantity).toFixed(2)):null})).sort((a,b)=>a.itemName.localeCompare(b.itemName)||a.branchName.localeCompare(b.branchName));
 return {
  period:{from,to},timezone:'Asia/Karachi',currency:'PKR',
  summary:{purchaseCount:purchases.length,receivedPurchaseTotal:Number(purchaseTotal.toFixed(2)),paidForSelectedPurchases:Number(paidTotal.toFixed(2)),outstandingForSelectedPurchases:Number(Math.max(0,purchaseTotal-paidTotal).toFixed(2)),paymentRecords:paymentRows.length},
  byBranch:branchRows,bySupplier:supplierRows,byInventoryItem:itemRows,costByBranchAndItem:branchItemRows,
  daily:purchases.length?[...dailyMap.values()].sort((a,b)=>a.date.localeCompare(b.date)).map(x=>({...x,total:Number(x.total.toFixed(2))})):[],
  note:'Outstanding is calculated for purchases received in the selected period, using all payments recorded against those purchases up to now. Draft and cancelled purchases are excluded.'
 };
}

async function saveRecipe(restaurantId,input){const variantId=id(input.productVariantId),yieldQty=quantity(input.yieldQuantity||1,'Recipe yield');if(!Array.isArray(input.items)||!input.items.length||input.items.length>100)throw fail('A recipe requires 1 to 100 ingredients.');const variant=await ProductVariant.findOne({where:{id:variantId,isActive:true},include:[{model:Product,as:'product',where:{restaurantId},required:true}]});if(!variant)throw fail('Product variant not found for this restaurant.',404,'VARIANT_NOT_FOUND');const prepared=[],seen=new Set();for(const line of input.items){const inventoryItemId=id(line.inventoryItemId);if(seen.has(inventoryItemId))throw fail('Duplicate ingredient in recipe.');seen.add(inventoryItemId);const item=await InventoryItem.findOne({where:{id:inventoryItemId,restaurantId,isActive:true}});if(!item)throw fail('Recipe contains an unknown ingredient.',404,'ITEM_NOT_FOUND');prepared.push({inventoryItemId,quantity:quantity(line.quantity)});}return sequelize.transaction(async t=>{let recipe=await Recipe.findOne({where:{productVariantId:variantId,restaurantId},transaction:t,lock:t.LOCK.UPDATE});if(recipe){await recipe.update({yieldQuantity:yieldQty,isActive:true},{transaction:t});await RecipeItem.destroy({where:{recipeId:recipe.id},transaction:t});}else recipe=await Recipe.create({restaurantId,productVariantId:variantId,yieldQuantity:yieldQty,isActive:true},{transaction:t});await RecipeItem.bulkCreate(prepared.map(x=>({...x,recipeId:recipe.id})),{transaction:t});return Recipe.findByPk(recipe.id,{include:[{model:RecipeItem,as:'items'}],transaction:t});});}
async function listRecipes(restaurantId){return Recipe.findAll({where:{restaurantId,isActive:true},include:[{model:RecipeItem,as:'items'}],order:[['id','DESC']]});}
async function deductOrderStock(order,transaction){
 const branch=await Branch.findOne({where:{id:order.branchId,restaurantId:order.restaurantId},transaction,lock:transaction.LOCK.UPDATE});
 if(!branch)throw fail('Order branch not found.',404,'BRANCH_NOT_FOUND');
 if(!branch.inventoryAutoDeduct)return {deducted:false,reason:'branch_auto_deduction_disabled'};
 if(order.inventoryDeductedAt)return {deducted:false,reason:'already_deducted'};
 const lines=await require('../models').OrderItem.findAll({where:{orderId:order.id},transaction,lock:transaction.LOCK.UPDATE});
 const needed=new Map(),lineCosts=new Map();
 for(const line of lines){
  const recipe=await Recipe.findOne({where:{restaurantId:order.restaurantId,productVariantId:line.productVariantId,isActive:true},include:[{model:RecipeItem,as:'items'}],transaction});
  if(!recipe)throw fail('Missing active recipe for '+line.productName+'. Inventory was not deducted and order completion is blocked.',409,'RECIPE_MISSING');
  let lineCost=0,lineHasMissingCost=recipe.items.length===0;
  for(const ingredient of recipe.items){
   const amountNeeded=calculateRecipeConsumption(ingredient.quantity,line.quantity,recipe.yieldQuantity);
   const itemId=String(ingredient.inventoryItemId);
   needed.set(itemId,(needed.get(itemId)||0)+amountNeeded);
   const purchases=await StockMovement.findAll({where:{restaurantId:order.restaurantId,branchId:order.branchId,inventoryItemId:ingredient.inventoryItemId,movementType:'purchase'},attributes:['quantityChange','unitCost'],raw:true,transaction});
   const totalPurchaseQty=purchases.reduce((sum,m)=>sum+Math.max(0,Number(m.quantityChange)),0);
   const pricedPurchases=purchases.filter(m=>m.unitCost!==null&&m.unitCost!==undefined);
   const pricedQty=pricedPurchases.reduce((sum,m)=>sum+Math.max(0,Number(m.quantityChange)),0);
   const weightedCost=pricedQty>0?pricedPurchases.reduce((sum,m)=>sum+Math.max(0,Number(m.quantityChange))*Number(m.unitCost),0)/pricedQty:null;
   if(weightedCost===null||!Number.isFinite(weightedCost)||Math.abs(totalPurchaseQty-pricedQty)>0.0005){lineHasMissingCost=true;}else lineCost+=amountNeeded*weightedCost;
  }
  lineCosts.set(String(line.id),lineHasMissingCost?null:Math.round(lineCost*100)/100);
 }
 const ids=[...needed.keys()].sort((a,b)=>Number(a)-Number(b));
 for(const itemId of ids){
  const stock=await BranchStock.findOne({where:{branchId:order.branchId,inventoryItemId:Number(itemId)},transaction,lock:transaction.LOCK.UPDATE});
  const take=needed.get(itemId);
  if(!stock||Number(stock.quantity)<take)throw fail('Insufficient ingredient stock (item '+itemId+'). Order completion was blocked.',409,'INSUFFICIENT_STOCK');
  const after=calculateBalance(stock.quantity,-take);
  await stock.update({quantity:after},{transaction});
  await StockMovement.create({restaurantId:order.restaurantId,branchId:order.branchId,inventoryItemId:Number(itemId),movementType:'sale',quantityChange:-take,quantityAfter:after,referenceType:'order',referenceId:order.id,note:'Recipe consumption on order completion',createdByUserId:order.createdByUserId},{transaction});
 }
 for(const line of lines){
  const cost=lineCosts.get(String(line.id));
  await line.update({cogsTotal:cost===null?null:cost.toFixed(2),cogsStatus:cost===null?'missing_cost':'estimated'},{transaction});
 }
 await order.update({inventoryDeductedAt:new Date()},{transaction});
 return {deducted:true,ingredients:ids.length,cogsStatus:[...lineCosts.values()].some(v=>v===null)?'missing_cost':'estimated'};
}

async function recordPurchasePayment(restaurantId,user,purchaseId,input={}){const amount=money(input.amount,'Payment amount');if(amount<=0)throw fail('Payment amount must be greater than zero.');const method=input.method;if(!['cash','bank_transfer','easypaisa','jazzcash','card'].includes(method))throw fail('Unsupported supplier payment method.');return sequelize.transaction(async t=>{const purchase=await Purchase.findOne({where:{id:id(purchaseId),restaurantId},transaction:t,lock:t.LOCK.UPDATE});if(!purchase)throw fail('Purchase not found.',404,'PURCHASE_NOT_FOUND');assertBranch(user,purchase.branchId);if(purchase.status!=='received'||!purchase.supplierId)throw fail('Only received purchases linked to a supplier can be paid.',409,'PURCHASE_NOT_PAYABLE');const paid=Number(await PurchasePayment.sum('amount',{where:{restaurantId,purchaseId:purchase.id},transaction:t})||0);const due=Math.max(0,Number(purchase.totalCost)-paid);if(amount>due+0.0001)throw fail('Payment exceeds the outstanding purchase balance.',409,'PAYMENT_EXCEEDS_DUE');const payment=await PurchasePayment.create({restaurantId,purchaseId:purchase.id,supplierId:purchase.supplierId,amount:amount.toFixed(2),method,reference:input.reference?String(input.reference).trim().slice(0,120):null,notes:input.notes?String(input.notes).trim().slice(0,500):null,recordedByUserId:user.id},{transaction:t});await recordAudit(t,restaurantId,user.id,purchase.branchId,'purchase_payment',payment.id,'purchase.payment_recorded',null,{purchaseId:purchase.id,amount:payment.amount,method:payment.method,reference:payment.reference,dueAfter:Number((Number(purchase.totalCost)-paid-amount).toFixed(2))});return {payment,paidAmount:paid+amount,dueAmount:Math.max(0,Number(purchase.totalCost)-paid-amount)};});}
async function supplierLedger(restaurantId,user,supplierId){const supplier=await Supplier.findOne({where:{id:id(supplierId),restaurantId}});if(!supplier)throw fail('Supplier not found.',404,'SUPPLIER_NOT_FOUND');const purchases=await Purchase.findAll({where:{restaurantId,supplierId:supplier.id,status:'received',...branchFilter(user)},include:[{model:PurchaseItem,as:'items'}],order:[['receivedAt','DESC'],['id','DESC']]});const purchaseIds=purchases.map(p=>p.id);const payments= purchaseIds.length?await PurchasePayment.findAll({where:{restaurantId,supplierId:supplier.id,purchaseId:{[require('sequelize').Op.in]:purchaseIds}},order:[['createdAt','DESC']]}):[];const paidByPurchase=new Map();for(const p of payments)paidByPurchase.set(String(p.purchaseId),(paidByPurchase.get(String(p.purchaseId))||0)+Number(p.amount));const entries=purchases.map(p=>({type:'purchase',purchaseId:p.id,purchaseNumber:p.purchaseNumber,date:p.receivedAt,total:Number(p.totalCost),paid:Number((paidByPurchase.get(String(p.id))||0).toFixed(2)),due:Number(Math.max(0,Number(p.totalCost)-(paidByPurchase.get(String(p.id))||0)).toFixed(2)),items:p.items}));const purchaseTotal=entries.reduce((s,e)=>s+e.total,0),paidTotal=payments.reduce((s,p)=>s+Number(p.amount),0);return {supplier,purchaseTotal:Number(purchaseTotal.toFixed(2)),paidTotal:Number(paidTotal.toFixed(2)),outstanding:Number((purchaseTotal-paidTotal).toFixed(2)),purchases:entries,payments};}


async function transferStock(restaurantId,user,input){
 const fromId=id(input.fromBranchId),toId=id(input.toBranchId),itemId=id(input.inventoryItemId),qty=quantity(input.quantity);
 assertBranch(user,fromId);assertBranch(user,toId);
 if(fromId===toId)throw fail('Source and destination branches must be different.');
 return sequelize.transaction(async t=>{
  await branchFor(restaurantId,fromId,t);await branchFor(restaurantId,toId,t);
  const item=await InventoryItem.findOne({where:{id:itemId,restaurantId,isActive:true},transaction:t});
  if(!item)throw fail('Inventory item not found.',404,'ITEM_NOT_FOUND');
  const stocks=await BranchStock.findAll({where:{branchId:[fromId,toId],inventoryItemId:itemId},transaction:t,lock:t.LOCK.UPDATE});
  let source=stocks.find(s=>Number(s.branchId)===fromId),dest=stocks.find(s=>Number(s.branchId)===toId);
  if(!source||Number(source.quantity)<qty)throw fail('Insufficient source branch stock.',409,'INSUFFICIENT_STOCK');
  if(!dest)dest=await BranchStock.create({branchId:toId,inventoryItemId:itemId,quantity:0,reorderLevel:Number(item.lowStockThreshold||0)},{transaction:t});
  const sourceAfter=Number((Number(source.quantity)-qty).toFixed(3)),destAfter=Number((Number(dest.quantity)+qty).toFixed(3));
  await source.update({quantity:sourceAfter},{transaction:t});await dest.update({quantity:destAfter},{transaction:t});
  const reference='TRANSFER-'+Date.now()+'-'+crypto.randomBytes(2).toString('hex').toUpperCase();
  await recordAudit(t,restaurantId,user.id,fromId,'inventory_transfer',reference,'inventory.stock_transferred',null,{inventoryItemId:itemId,quantity:qty,fromBranchId:fromId,fromQuantity:sourceAfter,toBranchId:toId,toQuantity:destAfter});
  await StockMovement.bulkCreate([
   {restaurantId,branchId:fromId,inventoryItemId:itemId,movementType:'adjustment',quantityChange:-qty,quantityAfter:sourceAfter,referenceType:'stock_transfer',referenceId:null,note:reference+' to branch '+toId,createdByUserId:user.id},
   {restaurantId,branchId:toId,inventoryItemId:itemId,movementType:'adjustment',quantityChange:qty,quantityAfter:destAfter,referenceType:'stock_transfer',referenceId:null,note:reference+' from branch '+fromId,createdByUserId:user.id}
  ],{transaction:t});
  return {reference,inventoryItemId:itemId,quantity:qty,fromBranchId:fromId,fromQuantity:sourceAfter,toBranchId:toId,toQuantity:destAfter};
 });
}
async function returnPurchaseStock(restaurantId,user,purchaseId,input){
 const purchaseItemId=id(input.purchaseItemId),qty=quantity(input.quantity);
 return sequelize.transaction(async t=>{
  const purchase=await Purchase.findOne({where:{id:id(purchaseId),restaurantId,status:'received'},include:[{model:PurchaseItem,as:'items'}],transaction:t,lock:t.LOCK.UPDATE});
  if(!purchase)throw fail('Received purchase not found.',404,'PURCHASE_NOT_FOUND');
  assertBranch(user,purchase.branchId);
  const line=purchase.items.find(x=>Number(x.id)===purchaseItemId);
  if(!line)throw fail('Purchase line not found.',404,'PURCHASE_LINE_NOT_FOUND');
  const previous=await StockMovement.sum('quantityChange',{where:{restaurantId,branchId:purchase.branchId,inventoryItemId:line.inventoryItemId,movementType:'return',referenceType:'purchase_return',referenceId:purchase.id},transaction:t});
  const alreadyReturned=Math.abs(Math.min(0,Number(previous||0)));
  if(qty>Number(line.quantity)-alreadyReturned+0.0001)throw fail('Return quantity exceeds received quantity remaining.',409,'RETURN_EXCEEDS_RECEIVED');
  const stock=await BranchStock.findOne({where:{branchId:purchase.branchId,inventoryItemId:line.inventoryItemId},transaction:t,lock:t.LOCK.UPDATE});
  if(!stock||Number(stock.quantity)<qty)throw fail('Insufficient current stock to return this quantity.',409,'INSUFFICIENT_STOCK');
  const after=Number((Number(stock.quantity)-qty).toFixed(3));
  await stock.update({quantity:after},{transaction:t});
  const movement=await StockMovement.create({restaurantId,branchId:purchase.branchId,inventoryItemId:line.inventoryItemId,movementType:'return',quantityChange:-qty,quantityAfter:after,unitCost:line.unitCost,referenceType:'purchase_return',referenceId:purchase.id,note:input.note?String(input.note).slice(0,500):'Returned to supplier',createdByUserId:user.id},{transaction:t});
  return {purchaseId:purchase.id,purchaseItemId:line.id,returnedQuantity:alreadyReturned+qty,remainingReturnable:Number(line.quantity)-alreadyReturned-qty,stock,movement};
 });
}
async function inventoryValuation(restaurantId,user,branchId){
 const where={restaurantId};if(branchId){assertBranch(user,branchId);await branchFor(restaurantId,branchId);}else if(user&&!((user.roles||[]).includes('admin'))){const allowed=(user.branchIds||[]).map(Number).filter(n=>n>0);if(!allowed.length)allowed.push(-1);}
 const items=await InventoryItem.findAll({where,isActive:true,order:[['name','ASC']]});
 const rows=[];
 for(const item of items){
  const stockWhere={inventoryItemId:item.id,...(branchId?{branchId:id(branchId)}:branchFilter(user).branchId?{branchId:branchFilter(user).branchId}:{})};
  const stocks=await BranchStock.findAll({where:stockWhere});
  const quantityTotal=stocks.reduce((s,x)=>s+Number(x.quantity),0);
  const movementWhere={restaurantId,inventoryItemId:item.id,movementType:'purchase',...(branchId?{branchId:id(branchId)}:branchFilter(user))};
  const purchases=await StockMovement.findAll({where:movementWhere,attributes:['quantityChange','unitCost'],raw:true});
  const priced=purchases.filter(x=>x.unitCost!==null&&x.unitCost!==undefined&&Number(x.quantityChange)>0);
  const pricedQty=priced.reduce((s,x)=>s+Number(x.quantityChange),0);
  const avg=pricedQty?priced.reduce((s,x)=>s+Number(x.quantityChange)*Number(x.unitCost),0)/pricedQty:null;
  rows.push({inventoryItemId:item.id,name:item.name,unit:item.baseUnit,quantity:Number(quantityTotal.toFixed(3)),averageUnitCost:avg===null?null:Number(avg.toFixed(2)),valuation:avg===null?null:Number((quantityTotal*avg).toFixed(2)),costStatus:avg===null?'missing_cost':'estimated'});
 }
 const total=rows.every(x=>x.valuation!==null)?Number(rows.reduce((s,x)=>s+x.valuation,0).toFixed(2)):null;
 return {items:rows,totalValuation:total,costStatus:total===null?'incomplete':'estimated',note:'Estimated weighted average based on recorded purchase movements; historical layers and returns are not a full perpetual FIFO ledger.'};
}

module.exports={purchaseAnalytics,transferStock,returnPurchaseStock,inventoryValuation,recordPurchasePayment,supplierLedger,createItem,listBranches,listItems,listStock,adjustStock,movements,createSupplier,listSuppliers,setReorderLevel,lowStock,setBranchAutoDeduct,createPurchase,receivePurchase,listPurchases,saveRecipe,listRecipes,deductOrderStock};