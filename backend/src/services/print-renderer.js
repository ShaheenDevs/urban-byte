'use strict';
function line(width=32){return '-'.repeat(width);}
function renderOrder(order,kind='receipt',paperWidth='80mm',settings={}){
 const width=paperWidth==='58mm'?32:48;
 const center=value=>String(value||'').slice(0,width).padStart(Math.floor((width+String(value||'').length)/2)).slice(0,width);
 const rows=(order.items||[]).map(item=>{
  const name=(item.productName+' '+item.variantName).trim().slice(0,width);
  return name+'\n'+String(item.quantity)+' x Rs '+Number(item.unitPrice).toFixed(2)+' = Rs '+Number(item.lineTotal).toFixed(2);
 });
 const heading=kind==='kitchen_ticket'?'KITCHEN ORDER':(settings.receiptHeader||'URBAN BYTE');
 const details=[center(heading),line(width),'Order: '+order.orderNumber,'Type: '+String(order.orderType||'').toUpperCase(),'Time: '+new Date(order.placedAt).toLocaleString('en-PK',{timeZone:'Asia/Karachi'}),line(width)];
 if(kind==='kitchen_ticket'){
  details.push('*** PREPARATION TICKET ***');
  if(order.tableLabel)details.push('Table: '+order.tableLabel);
  if(order.customerName)details.push('Customer: '+order.customerName);
  details.push(...rows);
  if(order.notes)details.push('Notes: '+order.notes);
 }else{
  if(order.customerName)details.push('Customer: '+order.customerName);
  if(order.customerPhone)details.push('Phone: '+order.customerPhone);
  details.push(...rows,line(width),'Subtotal: Rs '+Number(order.subtotal).toFixed(2),'Discount: Rs '+Number(order.discountAmount).toFixed(2),'Tax: Rs '+Number(order.taxAmount).toFixed(2),'Delivery: Rs '+Number(order.deliveryFee).toFixed(2),'TOTAL: Rs '+Number(order.grandTotal).toFixed(2),'Payment: '+String(order.paymentStatus).toUpperCase());
  if(order.deliveryAddress)details.push('Address: '+order.deliveryAddress);
  details.push(line(width),settings.receiptFooter||'Thank you for choosing Urban Byte!');
 }
 return details.join('\n');
}
module.exports={renderOrder};