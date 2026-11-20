'use strict';
module.exports = {
 async up(q,S) {
  const D=S.DataTypes;
  await q.createTable('orders',{
   id:{type:D.BIGINT.UNSIGNED,autoIncrement:true,primaryKey:true},
   restaurant_id:{type:D.BIGINT.UNSIGNED,allowNull:false,references:{model:'restaurants',key:'id'},onUpdate:'CASCADE',onDelete:'RESTRICT'},
   branch_id:{type:D.BIGINT.UNSIGNED,allowNull:false,references:{model:'branches',key:'id'},onUpdate:'CASCADE',onDelete:'RESTRICT'},
   order_number:{type:D.STRING(40),allowNull:false},
   idempotency_key:{type:D.STRING(100),allowNull:true},
   created_by_user_id:{type:D.BIGINT.UNSIGNED,allowNull:true,references:{model:'users',key:'id'},onUpdate:'CASCADE',onDelete:'SET NULL'},
   customer_name:{type:D.STRING(150),allowNull:true},customer_phone:{type:D.STRING(30),allowNull:true},
   order_type:{type:D.ENUM('dine_in','takeaway','delivery'),allowNull:false},
   source:{type:D.ENUM('staff','phone','whatsapp','ai','online'),allowNull:false,defaultValue:'staff'},
   table_label:{type:D.STRING(40),allowNull:true},delivery_address:{type:D.TEXT,allowNull:true},
   notes:{type:D.TEXT,allowNull:true},
   status:{type:D.ENUM('placed','confirmed','preparing','ready','out_for_delivery','completed','cancelled'),allowNull:false,defaultValue:'placed'},
   payment_method:{type:D.ENUM('cash','card','easypaisa','jazzcash','bank_transfer','cod'),allowNull:true},
   payment_status:{type:D.ENUM('unpaid','pending','paid','refunded'),allowNull:false,defaultValue:'unpaid'},
   subtotal:{type:D.DECIMAL(12,2),allowNull:false},discount_amount:{type:D.DECIMAL(12,2),allowNull:false,defaultValue:0},
   tax_amount:{type:D.DECIMAL(12,2),allowNull:false,defaultValue:0},delivery_fee:{type:D.DECIMAL(12,2),allowNull:false,defaultValue:0},
   grand_total:{type:D.DECIMAL(12,2),allowNull:false},
   placed_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')},
   completed_at:{type:D.DATE,allowNull:true},cancelled_at:{type:D.DATE,allowNull:true},cancel_reason:{type:D.STRING(500),allowNull:true},
   created_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')},updated_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')}
  });
  await q.addConstraint('orders',{fields:['restaurant_id','order_number'],type:'unique',name:'uq_orders_restaurant_number'});
  await q.addConstraint('orders',{fields:['restaurant_id','idempotency_key'],type:'unique',name:'uq_orders_restaurant_idempotency'});
  await q.addIndex('orders',['restaurant_id','branch_id','status','created_at'],{name:'idx_orders_branch_status_created'});
  await q.addIndex('orders',['created_by_user_id','created_at'],{name:'idx_orders_creator_created'});
  await q.createTable('order_items',{
   id:{type:D.BIGINT.UNSIGNED,autoIncrement:true,primaryKey:true},
   order_id:{type:D.BIGINT.UNSIGNED,allowNull:false,references:{model:'orders',key:'id'},onUpdate:'CASCADE',onDelete:'CASCADE'},
   product_variant_id:{type:D.BIGINT.UNSIGNED,allowNull:true,references:{model:'product_variants',key:'id'},onUpdate:'CASCADE',onDelete:'SET NULL'},
   product_name:{type:D.STRING(160),allowNull:false},variant_name:{type:D.STRING(100),allowNull:false},
   sku_snapshot:{type:D.STRING(80),allowNull:true},quantity:{type:D.DECIMAL(10,3),allowNull:false},
   unit_price:{type:D.DECIMAL(12,2),allowNull:false},line_total:{type:D.DECIMAL(12,2),allowNull:false},
   notes:{type:D.STRING(500),allowNull:true},
   created_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')},updated_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')}
  });
  await q.addIndex('order_items',['order_id'],{name:'idx_order_items_order'});
  await q.createTable('order_status_history',{
   id:{type:D.BIGINT.UNSIGNED,autoIncrement:true,primaryKey:true},
   order_id:{type:D.BIGINT.UNSIGNED,allowNull:false,references:{model:'orders',key:'id'},onUpdate:'CASCADE',onDelete:'CASCADE'},
   from_status:{type:D.STRING(40),allowNull:true},to_status:{type:D.STRING(40),allowNull:false},
   changed_by_user_id:{type:D.BIGINT.UNSIGNED,allowNull:true,references:{model:'users',key:'id'},onUpdate:'CASCADE',onDelete:'SET NULL'},
   note:{type:D.STRING(500),allowNull:true},
   created_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')},updated_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')}
  });
  await q.addIndex('order_status_history',['order_id','created_at'],{name:'idx_order_history_order_created'});
 },
 async down(q){for(const t of ['order_status_history','order_items','orders'])await q.dropTable(t);}
};