'use strict';
const {Op}=require('sequelize');
const {Order,OrderItem,Payment,Expense,Purchase,PurchasePayment,Branch,sequelize}=require('../models');
function invalid(message){const e=new Error(message);e.statusCode=400;e.code='INVALID_REPORT_FILTER';return e;}
function range(query={}){
 const from=query.from||query.date||new Date().toISOString().slice(0,10);
 const to=query.to||query.date||from;
 const valid=v=>/^\d{4}-\d{2}-\d{2}$/.test(v)&&!Number.isNaN(Date.parse(v+'T00:00:00Z'));
 if(!valid(from)||!valid(to)||from>to)throw invalid('Use a valid YYYY-MM-DD date range.');
 const start=new Date(new Date(from+'T00:00:00.000Z').getTime()-5*60*60*1000);const end=new Date(new Date(to+'T00:00:00.000Z').getTime()-5*60*60*1000+24*60*60*1000);
 return {from,to,start,end};
}
async function overview(restaurantId,query={}){
 const {from,to,start,end}=range(query);const branchId=query.branchId?Number(query.branchId):null;
 if(branchId!==null&&(!Number.isSafeInteger(branchId)||branchId<1))throw invalid('Invalid branchId.');
 const scope={restaurantId,placedAt:{[Op.gte]:start,[Op.lt]:end},status:{[Op.ne]:'cancelled'}};if(branchId)scope.branchId=branchId;
 const orders=await Order.findAll({where:scope,attributes:['id','grandTotal','paymentStatus','orderType','status'],raw:true});
 const paymentWhere={restaurantId,status:'verified',verifiedAt:{[Op.gte]:start,[Op.lt]:end}};if(branchId)paymentWhere.branchId=branchId;
 const payments=await Payment.findAll({where:paymentWhere,attributes:['method','amount'],raw:true});
 const methods={cash:0,card:0,easypaisa:0,jazzcash:0,bank_transfer:0,cod:0};
 for(const p of payments)methods[p.method]=(methods[p.method]||0)+Number(p.amount);
 const typeCounts={dine_in:0,takeaway:0,delivery:0};
 for(const o of orders)typeCounts[o.orderType]=(typeCounts[o.orderType]||0)+1;
 const orderIds=orders.map(o=>o.id);
 let topProducts=[];
 if(orderIds.length){
  topProducts=await OrderItem.findAll({
   attributes:['productName',[sequelize.fn('SUM',sequelize.col('quantity')),'quantity'],[sequelize.fn('SUM',sequelize.col('line_total')),'revenue']],
   where:{orderId:{[Op.in]:orderIds}},group:['productName'],order:[[sequelize.literal('quantity'),'DESC']],limit:10,raw:true
  });
 }
 const gross=orders.reduce((s,o)=>s+Number(o.grandTotal),0);
 const paidOrderValue=orders.filter(o=>o.paymentStatus==='paid').reduce((s,o)=>s+Number(o.grandTotal),0);
 const expenses=0;
 return {period:{from,to},timezone:'Asia/Karachi',currency:'PKR',orders:{count:orders.length,grossSales:gross.toFixed(2),paidOrderValue:paidOrderValue.toFixed(2),averageOrderValue:orders.length?(gross/orders.length).toFixed(2):'0.00',byType:typeCounts},verifiedPayments:{count:payments.length,total:payments.reduce((s,p)=>s+Number(p.amount),0).toFixed(2),byMethod:Object.fromEntries(Object.entries(methods).map(([k,v])=>[k,v.toFixed(2)]))},bestSellingProducts:topProducts.map(p=>({name:p.productName,quantity:Number(p.quantity),revenue:Number(p.revenue).toFixed(2)})),expenses:{tracked:false,total:expenses.toFixed(2)}};
}

async function financial(restaurantId,query={}){
 const {from,to,start,end}=range(query);
 const branchId=query.branchId?Number(query.branchId):null;
 if(branchId!==null&&(!Number.isSafeInteger(branchId)||branchId<1))throw invalid('Invalid branchId.');
 if(branchId){const branch=await Branch.findOne({where:{id:branchId,restaurantId},attributes:['id']});if(!branch){const e=invalid('Branch not found for this restaurant.');e.statusCode=404;throw e;}}
 const base={restaurantId,...(branchId?{branchId}:{})};
 const [payments,expenses,purchases,branchPurchases]=await Promise.all([
  Payment.findAll({where:{...base,status:'verified',verifiedAt:{[Op.gte]:start,[Op.lt]:end}},attributes:['method','amount'],raw:true}),
  Expense.findAll({where:{...base,status:'approved',expenseDate:{[Op.gte]:from,[Op.lte]:to}},attributes:['paymentMethod','amount'],raw:true}),
  Purchase.findAll({where:{...base,status:'received',receivedAt:{[Op.gte]:start,[Op.lt]:end}},attributes:['id','supplierId','totalCost'],raw:true}),
  Purchase.findAll({where:base,attributes:['id'],raw:true})
 ]);
 const branchPurchaseIds=branchPurchases.map(p=>p.id);
 const supplierPayments=branchPurchaseIds.length?await PurchasePayment.findAll({where:{restaurantId,purchaseId:{[Op.in]:branchPurchaseIds},createdAt:{[Op.gte]:start,[Op.lt]:end}},attributes:['method','amount','purchaseId'],raw:true}):[];
 const sum=(rows,key)=>rows.reduce((n,x)=>n+Number(x[key]||0),0);
 const byMethod=(rows,key)=>Object.fromEntries([...new Set(rows.map(x=>x[key]))].map(m=>[m,rows.filter(x=>x[key]===m).reduce((n,x)=>n+Number(x.amount),0).toFixed(2)]));
 const purchaseIds=purchases.map(p=>p.id);
 const allPayments=purchaseIds.length?await PurchasePayment.findAll({where:{restaurantId,purchaseId:{[Op.in]:purchaseIds}},attributes:['purchaseId','amount'],raw:true}):[];
 const paidByPurchase=new Map();allPayments.forEach(p=>paidByPurchase.set(String(p.purchaseId),(paidByPurchase.get(String(p.purchaseId))||0)+Number(p.amount)));
 const receivedPurchaseCost=sum(purchases,'totalCost');
 const supplierPaidForReceived=purchases.reduce((n,p)=>n+Math.min(Number(p.totalCost),paidByPurchase.get(String(p.id))||0),0);
 const supplierDue=Math.max(0,receivedPurchaseCost-supplierPaidForReceived);
 const collected=sum(payments,'amount');
 const approvedExpenseTotal=sum(expenses,'amount');
 const cashIn=payments.filter(p=>p.method==='cash').reduce((n,p)=>n+Number(p.amount),0);
 const cashExpense=expenses.filter(e=>e.paymentMethod==='cash').reduce((n,e)=>n+Number(e.amount),0);
 const cashSupplierPayments=supplierPayments.filter(p=>p.method==='cash').reduce((n,p)=>n+Number(p.amount),0);
 return {period:{from,to},timezone:'Asia/Karachi',currency:'PKR',
  collections:{total:collected.toFixed(2),count:payments.length,byMethod:byMethod(payments,'method')},
  approvedExpenses:{total:approvedExpenseTotal.toFixed(2),count:expenses.length,byMethod:byMethod(expenses,'paymentMethod')},
  purchases:{receivedTotal:receivedPurchaseCost.toFixed(2),receivedCount:purchases.length,supplierPaidForReceived:Number(supplierPaidForReceived).toFixed(2),supplierOutstanding:Number(supplierDue).toFixed(2)},
  supplierPayments:{total:sum(supplierPayments,'amount').toFixed(2),count:supplierPayments.length},
  cashFlow:{cashCollections:cashIn.toFixed(2),cashExpenses:cashExpense.toFixed(2),cashSupplierPayments:cashSupplierPayments.toFixed(2),netCashMovement:(cashIn-cashExpense-cashSupplierPayments).toFixed(2)},
  accountingNotes:{profitAvailable:false,reason:'Purchase receipts are inventory acquisitions, not necessarily cost of goods sold. Accurate gross/net profit requires stock consumption or recipe-based COGS valuation. Do not subtract full purchases from revenue as profit.'}
 };
}
\nmodule.exports={overview,financial,range};