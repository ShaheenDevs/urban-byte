'use strict';
const service=require('../services/inventory-service'),{success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;e.code='RESTAURANT_NOT_ASSIGNED';throw e;}return n;}
const wrap=(fn,message,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req,restaurant(req))).then(data=>success(res,data,message,status)).catch(next);
module.exports={
 createItem:wrap((r,id)=>service.createItem(id,r.body||{}),'Inventory item created.',201),
 listItems:wrap((r,id)=>service.listItems(id),'Inventory items loaded.'),
 stock:wrap((r,id)=>service.listStock(id,r.query.branchId),'Branch stock loaded.'),
 adjust:wrap((r,id)=>service.adjustStock(id,r.user,r.body||{}),'Stock adjusted.'),
 movements:wrap((r,id)=>service.movements(id,r.query),'Stock movements loaded.'),
 createPurchase:wrap((r,id)=>service.createPurchase(id,r.user,r.body||{}),'Purchase draft created.',201),
 listPurchases:wrap((r,id)=>service.listPurchases(id),'Purchases loaded.'),
 receivePurchase:wrap((r,id)=>service.receivePurchase(id,r.user,r.params.purchaseId),'Purchase received and stock updated.'),
 saveRecipe:wrap((r,id)=>service.saveRecipe(id,r.body||{}),'Recipe saved.'),
 listRecipes:wrap((r,id)=>service.listRecipes(id),'Recipes loaded.'),
 createSupplier:wrap((r,id)=>service.createSupplier(id,r.body||{}),'Supplier created.',201),
 listSuppliers:wrap((r,id)=>service.listSuppliers(id),'Suppliers loaded.'),
 setReorderLevel:wrap((r,id)=>service.setReorderLevel(id,r.body||{}),'Reorder threshold saved.'),
 lowStock:wrap((r,id)=>service.lowStock(id,r.query.branchId),'Low-stock items loaded.')
};