'use strict';
const service=require('../services/inventory-service'),{success}=require('../utils/api-response');
function restaurant(req){const n=Number(req.auth?.restaurantId);if(!Number.isSafeInteger(n)||n<1){const e=new Error('Staff account is not assigned to a restaurant.');e.statusCode=403;e.code='RESTAURANT_NOT_ASSIGNED';throw e;}return n;}
const wrap=(fn,message,status=200)=>(req,res,next)=>Promise.resolve().then(()=>fn(req,restaurant(req))).then(data=>success(res,data,message,status)).catch(next);

async function supplierLedgerCsv(req,res,next){try{
 const data=await service.supplierLedger(restaurant(req),req.user,req.params.supplierId);
 const supplier=data.supplier;
 const rows=[
  {section:'summary',name:'Purchase total',amount:data.purchaseTotal},
  {section:'summary',name:'Paid total',amount:data.paidTotal},
  {section:'summary',name:'Outstanding',amount:data.outstanding},
  ...(data.purchases||[]).map(p=>({section:'purchase',name:p.purchaseNumber,date:p.date,total:p.total,paid:p.paid,due:p.due})),
  ...(data.payments||[]).map(p=>({section:'payment',name:p.method,date:p.createdAt,amount:p.amount,reference:p.reference}))
 ];
 const csv=require('../utils/report-export').toCsv(['section','name','date','total','paid','due','amount','reference'],rows);
 res.setHeader('Content-Type','text/csv; charset=utf-8');
 res.setHeader('Content-Disposition','attachment; filename="urban-byte-supplier-'+supplier.id+'-ledger.csv"');
 res.setHeader('Cache-Control','no-store');return res.status(200).send(csv);
}catch(e){next(e);}}
async function supplierLedgerPdf(req,res,next){try{
 const data=await service.supplierLedger(restaurant(req),req.params.supplierId);
 const lines=[
  'Supplier: '+data.supplier.name,
  'Purchase total: PKR '+data.purchaseTotal,
  'Paid total: PKR '+data.paidTotal,
  'Outstanding: PKR '+data.outstanding,
  'Purchases:',
  ...(data.purchases||[]).map(p=>p.purchaseNumber+' | '+p.date+' | Total '+p.total+' | Paid '+p.paid+' | Due '+p.due),
  'Payments:',
  ...(data.payments||[]).map(p=>p.createdAt+' | '+p.method+' | PKR '+p.amount+' | '+(p.reference||''))
 ];
 const pdf=require('../utils/report-export').createPdf('Supplier Ledger',lines);
 res.setHeader('Content-Type','application/pdf');
 res.setHeader('Content-Disposition','attachment; filename="urban-byte-supplier-'+data.supplier.id+'-ledger.pdf"');
 res.setHeader('Cache-Control','no-store');return res.status(200).send(pdf);
}catch(e){next(e);}}

module.exports={
 transfer:wrap((r,id)=>service.transferStock(id,r.user||{id:r.auth.sub},r.body||{}),'Stock transferred.'),
 returnPurchase:wrap((r,id)=>service.returnPurchaseStock(id,r.user||{id:r.auth.sub},r.params.purchaseId,r.body||{}),'Purchase stock returned.'),
 valuation:wrap((r,id)=>service.inventoryValuation(id,r.user,r.query.branchId),'Inventory valuation loaded.'),
 purchaseAnalytics:wrap((r,id)=>service.purchaseAnalytics(id,r.user,r.query),'Purchase analytics loaded.'),
 createItem:wrap((r,id)=>service.createItem(id,r.body||{}),'Inventory item created.',201),
 listItems:wrap((r,id)=>service.listItems(id),'Inventory items loaded.'),
 branches:wrap((r,id)=>service.listBranches(id,r.user),'Branches loaded.'),
 stock:wrap((r,id)=>service.listStock(id,r.query.branchId,r.user),'Branch stock loaded.'),
 adjust:wrap((r,id)=>service.adjustStock(id,r.user||{id:r.auth.sub},r.body||{}),'Stock adjusted.'),
 movements:wrap((r,id)=>service.movements(id,r.user,r.query),'Stock movements loaded.'),
 createPurchase:wrap((r,id)=>service.createPurchase(id,r.user||{id:r.auth.sub},r.body||{}),'Purchase draft created.',201),
 listPurchases:wrap((r,id)=>service.listPurchases(id,r.user),'Purchases loaded.'),
 receivePurchase:wrap((r,id)=>service.receivePurchase(id,r.user||{id:r.auth.sub},r.params.purchaseId),'Purchase received and stock updated.'),
 saveRecipe:wrap((r,id)=>service.saveRecipe(id,r.body||{}),'Recipe saved.'),
 listRecipes:wrap((r,id)=>service.listRecipes(id),'Recipes loaded.'),
 recordPurchasePayment:wrap((r,id)=>service.recordPurchasePayment(id,r.user||{id:r.auth.sub},r.params.purchaseId,r.body||{}),'Supplier payment recorded.',201),
 supplierLedger:wrap((r,id)=>service.supplierLedger(id,r.user,r.params.supplierId),'Supplier ledger loaded.'),
 supplierLedgerCsv,
 supplierLedgerPdf,
 createSupplier:wrap((r,id)=>service.createSupplier(id,r.body||{}),'Supplier created.',201),
 listSuppliers:wrap((r,id)=>service.listSuppliers(id),'Suppliers loaded.'),
 setReorderLevel:wrap((r,id)=>service.setReorderLevel(id,r.user,r.body||{}),'Reorder threshold saved.'),
 lowStock:wrap((r,id)=>service.lowStock(id,r.query.branchId,r.user),'Low-stock items loaded.'),
 setAutoDeduct:wrap((r,id)=>service.setBranchAutoDeduct(id,r.user,r.params.branchId,r.body?.enabled),'Branch auto deduction setting updated.')
};