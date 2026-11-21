'use strict';
module.exports={
 async up(q,S){
  await q.addColumn('order_items','cogs_total',{type:S.DECIMAL(12,2),allowNull:true,after:'line_total'});
  await q.addColumn('order_items','cogs_status',{type:S.ENUM('pending','estimated','missing_cost'),allowNull:false,defaultValue:'pending',after:'cogs_total'});
  await q.addIndex('order_items',['cogs_status'],{name:'idx_order_items_cogs_status'});
 },
 async down(q){await q.removeIndex('order_items','idx_order_items_cogs_status');await q.removeColumn('order_items','cogs_status');await q.removeColumn('order_items','cogs_total');}
};