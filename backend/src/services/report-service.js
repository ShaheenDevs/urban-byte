'use strict';
const {Op}=require('sequelize');
const {Order,OrderItem,Payment,sequelize}=require('../models');
function invalid(message){const e=new Error(message);e.statusCode=400;e.code='INVALID_REPORT_FILTER';return e;}
function range(query={}){
 const from=query.from||query.date||new Date().toISOString().slice(0,10);
 const to=query.to||query.date||from;
 const valid=v=>/^\d{4}-\d{2}-\d{2}$/.test(v)&&!Number.isNaN(Date.parse(v+'T00:00:00Z'));
 if(!valid(from)||!valid(to)||from>to)throw invalid('Use a valid YYYY-MM-DD date range.');
 const start=new Date(from+'T00:00:00.000Z');const end=new Date(to+'T00:00:00.000Z');end.setUTCDate(end.getUTCDate()+1);
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
module.exports={overview,range};