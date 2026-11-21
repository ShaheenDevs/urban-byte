'use strict';
const {Op}=require('sequelize');
const {Product,ProductVariant,MenuCategory,BranchProductPrice,Deal,DealItem,DealPrice,AiMessage}=require('../models');
const whatsapp=require('./whatsapp-outbound-service');
const aiOrders=require('./ai-agent-service');
const {normalize,words,parseQuantity,variantSize,isExplicitConfirmation}=require('./ai-order-parser');
function pkr(v){return 'Rs. '+Number(v).toLocaleString('en-PK',{maximumFractionDigits:2});}
function isGreeting(t){return /^(hi|hello|hey|salam|assalam|assalam o alaikum|aoa)[!.\s]*$/i.test(String(t||'').trim());}
function isConfirm(t){return isExplicitConfirmation(t);}
function isCart(t){return /\b(cart|summary|total|checkout|my order|mera order|order details)\b/.test(normalize(t))||/cart|total|order dikhao|order batao|hisab|khulasa/.test(normalize(t));}

async function getProducts(restaurantId,branchId,query){
 const tokens=words(query);const where={restaurantId,isActive:true,isAvailable:true};
 if(tokens.length)where[Op.and]=tokens.map(token=>({name:{[Op.like]:'%'+token+'%'}}));
 const rows=await Product.findAll({where,include:[{model:MenuCategory,as:'category',where:{isActive:true},required:true,attributes:['name']},{model:ProductVariant,as:'variants',where:{isActive:true},required:true,attributes:['id','name','basePrice','isDefault'],include:branchId?[{model:BranchProductPrice,as:'branchPrices',where:{branchId},required:false,attributes:['salePrice','isAvailable']}]:[]}],order:[['name','ASC']],limit:30});
 return rows.map(p=>({id:p.id,name:p.name,category:p.category?.name,variants:p.variants.filter(v=>!v.branchPrices?.length||v.branchPrices.some(x=>x.isAvailable)).map(v=>({id:v.id,name:v.name,price:Number(v.branchPrices?.find(x=>x.isAvailable)?.salePrice??v.basePrice),isDefault:v.isDefault}))})).filter(p=>p.variants.length);
}
async function getDeals(restaurantId,branchId){const now=new Date();const where={restaurantId,isActive:true,[Op.and]:[{[Op.or]:[{startsAt:null},{startsAt:{[Op.lte]:now}}]},{[Op.or]:[{endsAt:null},{endsAt:{[Op.gte]:now}}]}]};const include=[{model:DealItem,as:'items',include:[{model:ProductVariant,as:'variant',include:[{model:Product,as:'product',attributes:['name']}]}]}];if(branchId)include.push({model:DealPrice,as:'branchPrices',where:{branchId,isAvailable:true},required:false});const rows=await Deal.findAll({where,include,order:[['name','ASC']],limit:8});return rows.map(d=>({name:d.name,description:d.description,price:d.branchPrices?.[0]?.salePrice??null,items:d.items.map(i=>({name:i.variant?.product?.name,variant:i.variant?.name,quantity:i.quantity}))}));}
function cartSummary(cart){if(!cart.items?.length)return 'Aapka cart abhi empty hai. Kya add karna pasand karein?';const lines=['*Urban Byte — Order Summary*'];let total=0;for(const item of cart.items){const line=item.unitPrice*item.quantity;total+=line;lines.push(item.quantity+' × '+item.productName+' ('+item.variantName+') — '+pkr(line));}lines.push('','Subtotal: '+pkr(total));if(cart.orderType)lines.push('Order type: '+cart.orderType.replace('_',' '));if(cart.deliveryAddress)lines.push('Address: '+cart.deliveryAddress);if(cart.tableLabel)lines.push('Table: '+cart.tableLabel);lines.push('','Order confirm karne ke liye *CONFIRM* bhejein, ya items change karne ke liye batayein.');return lines.join('\n');}
async function sendReply(restaurantId,conversation,reply){if(conversation.channel==='whatsapp'&&conversation.customerPhone)return whatsapp.sendText(restaurantId,conversation.id,{text:reply,senderType:'assistant'});return AiMessage.create({conversationId:conversation.id,senderType:'assistant',content:reply,metadata:{agent:'urban-byte-order-agent',version:2}});}
async function respond(restaurantId,conversation,text){
 const q=String(text||'').trim();const context={...(conversation.context||{})};const cart={items:Array.isArray(context.cart?.items)?context.cart.items:[],orderType:context.cart?.orderType||null,deliveryAddress:context.cart?.deliveryAddress||null,tableLabel:context.cart?.tableLabel||null};
 let reply;
 if(isGreeting(q)){reply='Assalam-o-Alaikum! Urban Byte mein khush aamdeed. Aap pizza, burger ya deals ka menu pooch sakte hain. Order ke liye item aur quantity likhein.';}
 else if(/^(clear cart|empty cart|cart clear|order cancel|cancel cart)$/i.test(normalize(q))){cart.items=[];context.cart=cart;await conversation.update({context});reply='Aapka cart clear kar diya hai. Naya order add kar sakte hain.';}
 else if(isCart(q)){reply=cartSummary(cart);}
 else if(/^(delivery|home delivery|deliver)$/i.test(normalize(q))||/home delivery|delivery chahiye|ghar deliver/.test(normalize(q))){cart.orderType='delivery';context.cart=cart;await conversation.update({context});reply='Delivery ke liye apna complete address aur area bhej dein.';}
 else if(/^(takeaway|take away|pickup|pick up)$/i.test(normalize(q))){cart.orderType='takeaway';context.cart=cart;await conversation.update({context});reply='Theek hai, takeaway select kar liya. Aur koi item add karna hai ya cart summary dekhein?';}
 else if(/^(dine in|dine-in|restaurant mein|table)$/i.test(normalize(q))){cart.orderType='dine_in';context.cart=cart;await conversation.update({context});reply='Dine-in select kar liya. Apna table number/label bhej dein.';}
 else if(cart.orderType==='delivery'&&!cart.deliveryAddress&&q.length>8&&!isConfirm(q)&&!isCart(q)){cart.deliveryAddress=q.slice(0,1000);context.cart=cart;await conversation.update({context});reply='Delivery address save kar liya. '+cartSummary(cart);}
 else if(cart.orderType==='dine_in'&&!cart.tableLabel&&q.length<50&&!isConfirm(q)){cart.tableLabel=q;context.cart=cart;await conversation.update({context});reply='Table '+q+' save kar liya. '+cartSummary(cart);}
 else if(isConfirm(q)){
  if(!cart.items.length)reply='Aapka cart empty hai. Pehle menu se items add karein.';
  else if(!conversation.branchId)reply='Order branch configured nahi hai. Staff se branch select karwayein.';
  else if(!cart.orderType)reply='Order type select karein: Delivery, Takeaway ya Dine-in.';
  else if(cart.orderType==='delivery'&&!cart.deliveryAddress)reply='Please delivery address share karein.';
  else if(cart.orderType==='dine_in'&&!cart.tableLabel)reply='Please table number share karein.';
  else{const result=await aiOrders.submitOrderDraft(restaurantId,conversation.id,{branchId:conversation.branchId,orderType:cart.orderType,deliveryAddress:cart.deliveryAddress,tableLabel:cart.tableLabel,customerConfirmed:true,items:cart.items.map(x=>({variantId:x.variantId,quantity:x.quantity,notes:x.notes}))});context.cart={items:[],orderType:null,deliveryAddress:null,tableLabel:null};await conversation.update({context});reply=result.decision==='auto_approved'?'Shukriya! Aapka order confirm ho gaya hai. Order #'+result.order.orderNumber+' — Total '+pkr(result.order.grandTotal)+'. Payment abhi pending hai.':'Aapka order staff approval ke liye bhej diya gaya hai. Approval ke baad aapko update mil jayegi.';}
 }
 else if(/^(remove|delete|hatao|nikalo)\b/.test(normalize(q))){const tokens=words(q);const before=cart.items.length;cart.items=cart.items.filter(x=>!tokens.some(t=>normalize(x.productName).includes(t)));context.cart=cart;await conversation.update({context});reply=before===cart.items.length?'Cart mein matching item nahi mila.':'Item cart se remove kar diya. '+cartSummary(cart);}
 else{
  const products=await getProducts(restaurantId,conversation.branchId, q);
  const all=products.length?products:await getProducts(restaurantId,conversation.branchId,'');
  const tokens=words(q);
  const matches=all.filter(p=>tokens.length===0||tokens.some(t=>normalize(p.name+' '+p.category).includes(t)));
  if(matches.length===1){const p=matches[0];const v=variantSize(q,p.variants);const qty=parseQuantity(q);const existing=cart.items.find(x=>x.variantId===v.id);if(existing)existing.quantity=Math.min(10,existing.quantity+qty);else cart.items.push({variantId:v.id,productName:p.name,variantName:v.name,unitPrice:v.price,quantity:qty});context.cart=cart;await conversation.update({context});reply=qty+' × '+p.name+' ('+v.name+') cart mein add kar diya. '+cartSummary(cart);}
  else if(matches.length>1){reply='Ye items available hain:\n'+matches.slice(0,8).map(p=>'- '+p.name+' — '+p.variants.map(v=>v.name+' '+pkr(v.price)).join(' / ')).join('\n')+'\nKonsa item add karna hai?';}
  else if(/menu|price|rate|deal|offer|pizza|burger|shawarma|fries|pasta|mojito|qeemat|keemat/i.test(q)){const deals=await getDeals(restaurantId,conversation.branchId);reply=all.length?all.slice(0,10).map(p=>p.name+': '+p.variants.map(v=>v.name+' '+pkr(v.price)).join(' | ')).join('\n')+(deals.length?'\n\nDeals:\n'+deals.map(d=>'- '+d.name+(d.price!==null?' '+pkr(d.price):'')).join('\n'):''):'Abhi menu items available nahi hain.';}
  else reply='Aap item ka naam batayein, jaise "1 large pizza" ya "2 zinger burger". Cart dekhne ke liye "cart" likhein.';
 }
 await sendReply(restaurantId,conversation,reply);return reply;
}
module.exports={respond,getProducts,getDeals};