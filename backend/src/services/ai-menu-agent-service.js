'use strict';
const {Op}=require('sequelize');
const {Product,ProductVariant,MenuCategory,BranchProductPrice,Deal,DealItem,DealPrice,AiMessage}=require('../models');
const whatsapp=require('./whatsapp-outbound-service');
function normalize(value){return String(value||'').toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9\s]/g,' ').replace(/\s+/g,' ').trim();}
function isMenuRequest(text){const q=normalize(text);return /\b(menu|price|prices|deal|deals|offer|offers|available|pizza|burger|shawarma|fries|pasta|mojito|rate|menu card)\b/.test(q)||/menu|rate|qeemat|keemat|deal|offer|pizza|burger|shawarma|fries|pasta|kya available|kia available/.test(q);}
function greeting(text){return /^(hi|hello|hey|salam|assalam|assalam o alaikum|aoa|aoa urban byte|salam urban byte)[!.\s]*$/i.test(String(text||'').trim());}
function pkr(value){return 'Rs. '+Number(value).toLocaleString('en-PK',{maximumFractionDigits:2});}
async function getProducts(restaurantId,branchId,query){
 const stop=new Set(['please','mujhe','mujhy','chahiye','chaiye','price','rate','menu','show','batao','btao','kya','kia','available','hai','hy','the','with','and','for','urban','byte','large','medium','regular','small','family','personal','big','jumbo','single','double','ka','ki','ke','mein','ma','mujhe','mujhy','chahye','chahiye']);
 const tokens=normalize(query).split(' ').filter(x=>x.length>2&&!stop.has(x)).slice(0,5);
 const where={restaurantId,isActive:true,isAvailable:true};
 if(tokens.length)where[Op.and]=tokens.map(token=>({name:{[Op.like]:'%'+token+'%'}}));
 const rows=await Product.findAll({where,include:[{model:MenuCategory,as:'category',where:{isActive:true},required:true,attributes:['name']},{model:ProductVariant,as:'variants',where:{isActive:true},required:true,attributes:['id','name','basePrice','isDefault'],include:branchId?[{model:BranchProductPrice,as:'branchPrices',where:{branchId},required:false,attributes:['salePrice','isAvailable']}]:[]}],order:[['name','ASC']],limit:8});
 return rows.map(product=>({name:product.name,category:product.category?.name,variants:product.variants.filter(v=>!v.branchPrices?.length||v.branchPrices.some(p=>p.isAvailable)).map(v=>({id:v.id,name:v.name,price:v.branchPrices?.[0]?.salePrice??v.basePrice,isDefault:v.isDefault}))})).filter(p=>p.variants.length);
}
async function getDeals(restaurantId,branchId){
 const now=new Date();const where={restaurantId,isActive:true,[Op.and]:[{[Op.or]:[{startsAt:null},{startsAt:{[Op.lte]:now}}]},{[Op.or]:[{endsAt:null},{endsAt:{[Op.gte]:now}}]}]};
 const include=[{model:DealItem,as:'items',include:[{model:require('../models').ProductVariant,as:'variant',include:[{model:require('../models').Product,as:'product',attributes:['name']}]}]}];
 if(branchId)include.push({model:DealPrice,as:'branchPrices',where:{branchId,isAvailable:true},required:false});
 const deals=await Deal.findAll({where,include,order:[['name','ASC']],limit:8});
 return deals.map(d=>({name:d.name,description:d.description,price:d.branchPrices?.[0]?.salePrice??null,items:d.items.map(i=>({name:i.variant?.product?.name,variant:i.variant?.name,quantity:i.quantity}))}));
}
function renderMenu(products,deals){
 const lines=['Urban Byte ka menu'];
 for(const p of products)lines.push(p.name+': '+p.variants.map(v=>v.name+' '+pkr(v.price)).join(' | '));
 if(deals.length){lines.push('','Available deals:');for(const d of deals)lines.push('- '+d.name+(d.price!==null?' — '+pkr(d.price):'')+(d.description?' ('+d.description+')':''));}
 lines.push('','Order ke liye item, size aur quantity bata dein.');
 return lines.join('\n').slice(0,3500);
}
async function respond(restaurantId,conversation,text){
 const branchId=conversation.branchId||undefined;const q=String(text||'').trim();let reply;
 if(greeting(q))reply='Assalam-o-Alaikum! Urban Byte mein khush aamdeed. Aap menu, pizza, burger ya available deals ke rates pooch sakte hain. Order ke liye item aur quantity bata dein.';
 else if(isMenuRequest(q)){const products=await getProducts(restaurantId,branchId,q);const deals=await getDeals(restaurantId,branchId);if(products.length||deals.length)reply=renderMenu(products.length?products:await getProducts(restaurantId,branchId,''),deals);else{const categories=await MenuCategory.findAll({where:{restaurantId,isActive:true},order:[['sortOrder','ASC']],limit:12});reply='Is naam ka item abhi menu mein nahi mila. Available categories: '+categories.map(c=>c.name).join(', ')+'. Aap kis item ka rate dekhna chahenge?';}}
 else reply='Ji zaroor! Aap Urban Byte ke menu ya deals ke rates pooch sakte hain. Order shuru karne ke liye item ka naam, size aur quantity bhejein.';
 if(conversation.channel==='whatsapp'&&conversation.customerPhone)await whatsapp.sendText(restaurantId,conversation.id,{text:reply,senderType:'assistant'});
 else await AiMessage.create({conversationId:conversation.id,senderType:'assistant',content:reply,metadata:{agent:'deterministic-menu-agent',version:1}});
 return reply;
}
module.exports={respond,getProducts,getDeals,isMenuRequest};