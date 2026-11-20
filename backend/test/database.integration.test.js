'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const enabled=process.env.RUN_DB_INTEGRATION==='1';
test('MySQL migrations, seeded RBAC and Sequelize models are usable',{skip:!enabled},async()=>{
 const models=require('../src/models');
 const {sequelize,Role,Permission}=models;
 try{
  await sequelize.authenticate();
  const tables=(await sequelize.getQueryInterface().showAllTables()).map(String);
  for(const table of ['restaurants','branches','users','roles','permissions','user_roles','role_permissions','user_permissions','refresh_tokens','menu_categories','products','product_variants','branch_product_prices','deals','deal_items','deal_prices','orders','order_items','order_status_history','kitchen_tickets','kitchen_ticket_items','inventory_items','branch_stock','recipes','recipe_items','suppliers','purchases','purchase_items','stock_movements','SequelizeMeta']){
   assert.ok(tables.includes(table),`Expected migrated table: ${table}`);
  }
  assert.equal(await Role.count(),5,'system roles should be seeded');
  assert.ok(await Permission.count()>=30,'system permissions should be seeded');
  assert.ok(models.KitchenTicket && models.KitchenTicketItem && models.Order,'Sequelize should load order and kitchen models');
  assert.ok(models.InventoryItem && models.BranchStock && models.StockMovement && models.Recipe && models.Purchase && models.PurchaseItem,'Sequelize should load inventory and purchase models');
  const orderColumns=await sequelize.getQueryInterface().describeTable('orders');
  assert.ok(orderColumns.grand_total,'orders.grand_total should exist');
  assert.ok(orderColumns.idempotency_key,'orders.idempotency_key should exist');
  assert.ok(orderColumns.inventory_deducted_at,'orders.inventory_deducted_at should exist');
  const branchColumns=await sequelize.getQueryInterface().describeTable('branches');
  assert.ok(branchColumns.inventory_auto_deduct,'branches.inventory_auto_deduct should exist');
  const itemColumns=await sequelize.getQueryInterface().describeTable('inventory_items');
  assert.ok(itemColumns.base_unit && itemColumns.low_stock_threshold,'inventory item units and thresholds should exist');
 }finally{await sequelize.close();}
});
